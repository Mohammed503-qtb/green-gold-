// POST /api/orders — إنشاء طلب (transaction كامل + حجز مخزون 30 دقيقة)
// GET  /api/orders?phone=xxx — طلبات العميل
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import {
  ApiError,
  ORDER_INCLUDE,
  computeAvailable,
  fail,
  generateOrderCode,
  notify,
  ok,
  orderToDTO,
  ordersToDTOs,
  releaseExpiredReservations,
} from "@/lib/server";
import { RESERVATION_MINUTES } from "@/lib/contracts";

interface CartItemInput {
  batchId: string;
  qty: number;
}

interface OrderInput {
  customer?: { name?: string; phone?: string };
  address?: { zoneId?: string; addressText?: string; notes?: string; label?: string };
  items?: CartItemInput[];
  note?: string;
}

export async function GET(req: NextRequest) {
  try {
    const phone = (req.nextUrl.searchParams.get("phone") ?? "").trim();
    if (!phone) throw new ApiError("رقم الهاتف مطلوب لعرض الطلبات", 400);
    const orders = await db.order.findMany({
      where: { phone },
      include: ORDER_INCLUDE,
      orderBy: { createdAt: "desc" },
    });
    return ok({ orders: await ordersToDTOs(orders) });
  } catch (e) {
    return fail(e);
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json().catch(() => null)) as OrderInput | null;
    if (!body) throw new ApiError("بيانات الطلب غير صحيحة", 400);

    const name = body.customer?.name?.trim() ?? "";
    const phone = body.customer?.phone?.trim() ?? "";
    const zoneId = body.address?.zoneId?.trim() ?? "";
    const addressText = body.address?.addressText?.trim() ?? "";
    const addressNotes = body.address?.notes?.trim() || null;
    const addressLabel = body.address?.label?.trim() || "المنزل";
    const note = body.note?.trim() || null;

    if (!name) throw new ApiError("الاسم مطلوب", 400);
    if (!/^[0-9+\s-]{9,15}$/.test(phone)) throw new ApiError("رقم هاتف غير صالح", 400);
    if (!addressText) throw new ApiError("عنوان التوصيل مطلوب", 400);

    const items = (body.items ?? []).filter((i) => i && i.batchId && Number(i.qty) >= 1);
    if (items.length === 0) throw new ApiError("السلة فارغة", 400);
    for (const i of items) {
      if (!Number.isInteger(Number(i.qty)) || Number(i.qty) < 1 || Number(i.qty) > 50) {
        throw new ApiError("كمية غير صحيحة في السلة", 400);
      }
    }

    // تحرير الحجوزات المنتهية قبل التحقق من التوفر
    await releaseExpiredReservations();

    const orderDTO = await db.$transaction(async (tx) => {
      const zone = await tx.deliveryZone.findFirst({ where: { id: zoneId, active: true } });
      if (!zone) throw new ApiError("منطقة التوصيل غير متوفرة", 400);

      // التحقق من كل دفعة + إعادة حساب الأسعار من الخادم (منع التلاعب)
      type Line = {
        batchId: string;
        qty: number;
        unitPrice: number;
        productName: string;
        batchCode: string;
        grade: string;
        mainImage: string | null;
      };
      const lines: Line[] = [];
      for (const item of items) {
        const batch = await tx.productBatch.findUnique({
          where: { id: item.batchId },
          include: { product: true, media: { orderBy: { sort: "asc" } } },
        });
        if (!batch) throw new ApiError("إحدى الدفعات لم تعد متاحة", 404);
        if (batch.status !== "ACTIVE")
          throw new ApiError(`الدفعة ${batch.batchCode} لم تعد متاحة للطلب`, 409);
        const available = computeAvailable(batch);
        if (available < item.qty) {
          throw new ApiError(
            available <= 0
              ? `الدفعة ${batch.batchCode} نفدت أثناء إتمام طلبك`
              : `المتاح من الدفعة ${batch.batchCode} هو ${available} حزمة فقط`,
            409
          );
        }
        const main = batch.media.find((m) => m.isMain) ?? batch.media[0] ?? null;
        lines.push({
          batchId: batch.id,
          qty: Number(item.qty),
          unitPrice: batch.price, // السعر من الخادم دائمًا
          productName: batch.product.name,
          batchCode: batch.batchCode,
          grade: batch.grade,
          mainImage: main?.url ?? null,
        });
      }

      const itemsTotal = lines.reduce((s, l) => s + l.unitPrice * l.qty, 0);
      const deliveryFee = zone.fee;
      const total = itemsTotal + deliveryFee;

      // upsert العميل بالهاتف
      const customer = await tx.customer.upsert({
        where: { phone },
        update: { name },
        create: { phone, name },
      });
      await tx.address.create({
        data: {
          customerId: customer.id,
          label: addressLabel,
          zoneId: zone.id,
          addressText,
          notes: addressNotes,
        },
      });

      const orderCode = await generateOrderCode(tx);
      const order = await tx.order.create({
        data: {
          orderCode,
          customerId: customer.id,
          status: "PENDING_PAYMENT",
          itemsTotal,
          deliveryFee,
          discount: 0,
          total,
          zoneId: zone.id,
          addressText,
          customerName: name,
          phone,
          note,
        },
      });

      let firstBatchId = "";
      let totalQty = 0;
      for (const l of lines) {
        await tx.orderItem.create({
          data: {
            orderId: order.id,
            batchId: l.batchId,
            productName: l.productName,
            batchCode: l.batchCode,
            grade: l.grade,
            unitPrice: l.unitPrice,
            qty: l.qty,
            lineTotal: l.unitPrice * l.qty,
            mainImage: l.mainImage,
          },
        });
        await tx.productBatch.update({
          where: { id: l.batchId },
          data: { reservedQty: { increment: l.qty } },
        });
        await tx.inventoryMovement.create({
          data: {
            batchId: l.batchId,
            qty: -l.qty,
            type: "RESERVE",
            orderId: order.id,
            note: `حجز للطلب ${orderCode}`,
            actor: "CUSTOMER",
          },
        });
        if (!firstBatchId) firstBatchId = l.batchId;
        totalQty += l.qty;
      }

      // حجز واحد لكل طلب (علامة انتهاء الصلاحية) — المحاسبة لكل دفعة من items
      const expiresAt = new Date(Date.now() + RESERVATION_MINUTES * 60 * 1000);
      await tx.inventoryReservation.create({
        data: {
          batchId: firstBatchId,
          orderId: order.id,
          qty: totalQty,
          status: "ACTIVE",
          expiresAt,
        },
      });

      await tx.payment.create({
        data: {
          orderId: order.id,
          methodSnapshot: "{}",
          amount: total,
          status: "UNPAID",
        },
      });

      await tx.orderStatusHistory.create({
        data: {
          orderId: order.id,
          fromStatus: null,
          toStatus: "PENDING_PAYMENT",
          actor: "CUSTOMER",
          note: "تم إنشاء الطلب",
        },
      });

      await tx.notification.create({
        data: {
          audience: "ADMIN",
          title: "طلب جديد",
          body: `طلب جديد ${orderCode} من ${name} بقيمة ${total} ريال — بانتظار الدفع.`,
          orderCode,
        },
      });

      return order.id;
    });

    const fresh = await db.order.findUnique({ where: { id: orderDTO }, include: ORDER_INCLUDE });
    return ok({ order: await orderToDTO(fresh!) }, 201);
  } catch (e) {
    return fail(e);
  }
}
