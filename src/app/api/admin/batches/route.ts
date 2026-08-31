// GET  /api/admin/batches — كل الدفعات بكل الحالات
// POST /api/admin/batches — إنشاء دفعة (توليد batchCode + صورة أساسية إجبارية)
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import {
  ApiError,
  BATCH_INCLUDE,
  batchToCardDTO,
  fail,
  generateBatchCode,
  logAudit,
  notify,
  ok,
  requireStaff,
  type StaffIdentity,
} from "@/lib/server";
import { GRADES } from "@/lib/contracts";

export async function GET(req: NextRequest) {
  try {
    await requireStaff(req);
    const batches = await db.productBatch.findMany({
      include: BATCH_INCLUDE,
      orderBy: { createdAt: "desc" },
    });
    return ok({ batches: batches.map(batchToCardDTO) });
  } catch (e) {
    return fail(e);
  }
}

interface BatchInput {
  productId?: string;
  productName?: string;
  grade?: string;
  price?: number;
  totalQty?: number;
  description?: string;
  images?: { url?: string; isMain?: boolean }[];
  video?: string;
  quality?: { freshness?: number; density?: number; fullness?: number; appearance?: number };
  capturedAt?: string;
}

export async function POST(req: NextRequest) {
  try {
    const staff: StaffIdentity = await requireStaff(req, "manageBatches");
    const body = (await req.json().catch(() => null)) as BatchInput | null;
    if (!body) throw new ApiError("بيانات الدفعة غير صحيحة", 400);

    const grade = String(body.grade ?? "");
    if (!Object.keys(GRADES).includes(grade)) throw new ApiError("التصنيف غير صحيح", 400);
    const price = Math.round(Number(body.price));
    if (!Number.isFinite(price) || price < 100) throw new ApiError("أدخل سعرًا صحيحًا (100 ريال فأكثر)", 400);
    const totalQty = Math.round(Number(body.totalQty));
    if (!Number.isInteger(totalQty) || totalQty < 1) throw new ApiError("الكمية يجب أن تكون 1 فأكثر", 400);

    // صورة أساسية واحدة على الأقل — وإلا 400
    const images = (body.images ?? []).map((im, i) => ({
      url: (im.url ?? "").trim(),
      isMain: !!im.isMain,
      sort: i,
    }));
    const validImages = images.filter((im) => im.url.length > 5);
    if (validImages.length === 0)
      throw new ApiError("أضف صورة واحدة على الأقل قبل نشر الدفعة — التصوير الحقيقي أساس الثقة", 400);
    if (!validImages.some((im) => im.isMain)) validImages[0].isMain = true;
    const mainCount = validImages.filter((im) => im.isMain).length;
    if (mainCount > 1)
      for (let i = 1; i < validImages.length; i++) validImages[i].isMain = false;

    const capturedAt = body.capturedAt ? new Date(body.capturedAt) : new Date();
    if (isNaN(capturedAt.getTime())) throw new ApiError("وقت التصوير غير صحيح", 400);

    // المنتج: موجود بالـ id أو بالاسم (يُنشأ تلقائيًا إذا اسم جديد فقط)
    let productId = body.productId?.trim() ?? "";
    let productName = body.productName?.trim() ?? "";
    if (productId) {
      const p = await db.product.findUnique({ where: { id: productId } });
      if (!p) throw new ApiError("المنتج غير موجود", 404);
      productName = p.name;
    } else if (productName) {
      const existing = await db.product.findFirst({ where: { name: productName } });
      productId = existing
        ? existing.id
        : (await db.product.create({ data: { name: productName } })).id;
    } else {
      throw new ApiError("حدد منتجًا موجودًا أو أدخل اسم منتج جديد", 400);
    }

    const video = body.video?.trim() || null;
    const q = body.quality;
    const qualityValid =
      q &&
      [q.freshness, q.density, q.fullness, q.appearance].every(
        (v) => Number.isInteger(Number(v)) && Number(v) >= 1 && Number(v) <= 10
      );

    const batch = await db.$transaction(async (tx) => {
      const batchCode = await generateBatchCode(tx, productName, capturedAt);
      const created = await tx.productBatch.create({
        data: {
          batchCode,
          productId,
          grade,
          price,
          totalQty,
          status: "ACTIVE",
          capturedAt,
          description: body.description?.trim() || null,
        },
      });
      await tx.batchMedia.createMany({
        data: validImages.map((im) => ({
          batchId: created.id,
          url: im.url,
          type: "IMAGE",
          isMain: im.isMain,
          sort: im.sort,
        })),
      });
      if (video) {
        await tx.batchMedia.create({
          data: { batchId: created.id, url: video, type: "VIDEO", isMain: false, sort: 99 },
        });
      }
      if (qualityValid && q) {
        await tx.batchQuality.create({
          data: {
            batchId: created.id,
            freshness: Math.round(Number(q.freshness)),
            density: Math.round(Number(q.density)),
            fullness: Math.round(Number(q.fullness)),
            appearance: Math.round(Number(q.appearance)),
          },
        });
      }
      await tx.inventoryMovement.create({
        data: {
          batchId: created.id,
          qty: totalQty,
          type: "ADD",
          note: `إضافة دفعة جديدة ${batchCode}`,
          actor: staff.name,
        },
      });
      return created;
    });

    await logAudit(staff, "BATCH_CREATED", "BATCH", batch.id, null, {
      batchCode: batch.batchCode,
      productName,
      grade,
      price,
      totalQty,
    });
    await notify("ADMIN", "دفعة جديدة 🌿", `نُشرت الدفعة ${batch.batchCode} (${productName} — ${GRADES[grade as keyof typeof GRADES]}) بكمية ${totalQty} حزمة.`);

    const fresh = await db.productBatch.findUnique({ where: { id: batch.id }, include: BATCH_INCLUDE });
    return ok({ batch: batchToCardDTO(fresh!) }, 201);
  } catch (e) {
    return fail(e);
  }
}
