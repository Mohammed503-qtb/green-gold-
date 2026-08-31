// PATCH /api/admin/batches/[id] — تعديل سعر/حالة/كمية/وصف دفعة
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import {
  ApiError,
  BATCH_INCLUDE,
  batchToCardDTO,
  computeAvailable,
  fail,
  logAudit,
  ok,
  requireStaff,
  type StaffIdentity,
} from "@/lib/server";

export async function PATCH(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params;
    const body = (await req.json().catch(() => null)) as {
      price?: number;
      status?: string;
      addQty?: number;
      description?: string;
    } | null;
    if (!body) throw new ApiError("بيانات التعديل غير صحيحة", 400);

    const batch = await db.productBatch.findUnique({ where: { id } });
    if (!batch) throw new ApiError("الدفعة غير موجودة", 404);

    const wantsPrice = body.price !== undefined;
    // تغيير السعر صلاحية خاصة (OWNER/MANAGER)
    const staff: StaffIdentity = await requireStaff(req, wantsPrice ? "changePrice" : "manageBatches");

    const before = {
      price: batch.price,
      status: batch.status,
      totalQty: batch.totalQty,
      description: batch.description,
    };
    const after = { ...before };

    if (wantsPrice) {
      const price = Math.round(Number(body.price));
      if (!Number.isFinite(price) || price < 100) throw new ApiError("أدخل سعرًا صحيحًا (100 ريال فأكثر)", 400);
      after.price = price;
    }
    if (body.status !== undefined) {
      const status = String(body.status);
      if (!["HIDDEN", "ACTIVE", "CLOSED"].includes(status))
        throw new ApiError("حالة غير صحيحة", 400);
      if (status === "ACTIVE" && computeAvailable({ ...batch, ...after, totalQty: after.totalQty }) <= 0)
        throw new ApiError("لا يمكن تنشيط دفعة بلا كمية متاحة — أضف كمية أولًا", 400);
      after.status = status;
    }
    if (body.addQty !== undefined) {
      const addQty = Math.round(Number(body.addQty));
      if (!Number.isInteger(addQty) || addQty < 1) throw new ApiError("الكمية المضافة يجب أن تكون 1 فأكثر", 400);
      after.totalQty = before.totalQty + addQty;
    }
    if (body.description !== undefined) {
      after.description = body.description?.trim() || null;
    }

    const updated = await db.$transaction(async (tx) => {
      // إعادة التنشيط تلقائيًا عند إضافة كمية لدفعة نافدة
      let finalStatus = after.status;
      if (
        body.addQty !== undefined &&
        batch.status === "SOLD_OUT" &&
        computeAvailable({ ...batch, totalQty: after.totalQty }) > 0
      ) {
        finalStatus = "ACTIVE";
      }
      const row = await tx.productBatch.update({
        where: { id },
        data: {
          ...(wantsPrice ? { price: after.price } : {}),
          ...(finalStatus !== before.status || body.status !== undefined ? { status: finalStatus } : {}),
          ...(body.addQty !== undefined ? { totalQty: after.totalQty } : {}),
          ...(body.description !== undefined ? { description: after.description } : {}),
        },
        include: BATCH_INCLUDE,
      });
      if (body.addQty !== undefined) {
        await tx.inventoryMovement.create({
          data: {
            batchId: id,
            qty: Math.round(Number(body.addQty)),
            type: "ADD",
            note: `إضافة كمية بواسطة ${staff.name}`,
            actor: staff.name,
          },
        });
      }
      return row;
    });

    await logAudit(
      staff,
      wantsPrice ? "PRICE_CHANGED" : "BATCH_UPDATED",
      "BATCH",
      batch.id,
      before,
      { ...after, ...(updated.status !== after.status ? { status: updated.status } : {}) }
    );

    return ok({ batch: batchToCardDTO(updated) });
  } catch (e) {
    return fail(e);
  }
}
