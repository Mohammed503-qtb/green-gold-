// POST /api/admin/payments/[id]/verify — القلب المالي: تأكيد/رفض الدفع
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import {
  ApiError,
  computeAvailable,
  fail,
  logAudit,
  ok,
  orderToDTO,
  ORDER_INCLUDE,
  requireStaff,
  syncBatchStockState,
  type StaffIdentity,
} from "@/lib/server";

export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params;
    const body = (await req.json().catch(() => null)) as
      | { approved?: boolean; reason?: string }
      | null;
    if (!body || typeof body.approved !== "boolean")
      throw new ApiError("حدد قرار التحقق (قبول/رفض)", 400);

    const staff: StaffIdentity = await requireStaff(req, "verifyPayment");

    const payment = await db.payment.findUnique({
      where: { id },
      include: { order: { include: { items: true } } },
    });
    if (!payment) throw new ApiError("سجل الدفع غير موجود", 404);
    if (payment.status !== "PENDING_VERIFICATION")
      throw new ApiError("هذا الدفع ليس بانتظار التحقق", 409);

    const order = payment.order;
    const reason = body.reason?.trim() ?? "";

    if (body.approved) {
      await db.$transaction(async (tx) => {
        await tx.payment.update({
          where: { id: payment.id },
          data: {
            status: "PAID",
            verifiedAt: new Date(),
            verifiedBy: staff.name,
            rejectReason: null,
          },
        });

        // استهلاك الحجز وتحويله مبيعات فعلية
        const reservation = await tx.inventoryReservation.findUnique({
          where: { orderId: order.id },
        });
        if (reservation && reservation.status === "CONSUMED")
          throw new ApiError("تم استهلاك حجز هذا الطلب مسبقًا", 409);

        for (const item of order.items) {
          const batch = await tx.productBatch.findUnique({ where: { id: item.batchId } });
          if (!batch) throw new ApiError(`الدفعة ${item.batchCode} غير موجودة`, 404);
          const wasAvailable = computeAvailable(batch);
          const held = reservation?.status === "ACTIVE"; // الحجز ما زال يحمي الكمية
          if (!held && wasAvailable < item.qty) {
            throw new ApiError(
              `نفدت الكمية أثناء التحقق من الدفع — الدفعة ${item.batchCode} (المتاح ${wasAvailable})`,
              409
            );
          }
          await tx.productBatch.update({
            where: { id: item.batchId },
            data: {
              ...(held ? { reservedQty: { decrement: item.qty } } : {}),
              soldQty: { increment: item.qty },
            },
          });
          await tx.inventoryMovement.create({
            data: {
              batchId: item.batchId,
              qty: item.qty,
              type: "SOLD",
              orderId: order.id,
              note: `بيع مؤكد للطلب ${order.orderCode}`,
              actor: staff.name,
            },
          });
          // SOLD_OUT تلقائي + إشعار عند النفاد
          await syncBatchStockState(tx, item.batchId, { wasAvailable, actor: staff.name });
        }

        if (reservation) {
          await tx.inventoryReservation.update({
            where: { id: reservation.id },
            data: { status: "CONSUMED" },
          });
        }

        await tx.order.update({ where: { id: order.id }, data: { status: "CONFIRMED" } });
        await tx.orderStatusHistory.create({
          data: {
            orderId: order.id,
            fromStatus: order.status,
            toStatus: "CONFIRMED",
            actor: staff.name,
            note: "تم التحقق من الدفع وتأكيد الطلب",
          },
        });
        await tx.notification.create({
          data: {
            audience: "CUSTOMER",
            title: "تم تأكيد الدفع ✅",
            body: `تم تأكيد دفع الطلب ${order.orderCode} وسيبدأ التجهيز قريبًا. شكرًا لثقتك بذهب أخضر 🌿`,
            orderCode: order.orderCode,
          },
        });
      });
      await logAudit(staff, "PAYMENT_VERIFIED", "PAYMENT", payment.id, { status: payment.status }, { status: "PAID", amount: payment.amount });
    } else {
      if (!reason) throw new ApiError("سبب الرفض إجباري", 400);
      await db.$transaction(async (tx) => {
        await tx.payment.update({
          where: { id: payment.id },
          data: { status: "REJECTED", rejectReason: reason },
        });
        const reservation = await tx.inventoryReservation.findUnique({
          where: { orderId: order.id },
        });
        if (reservation && reservation.status === "ACTIVE") {
          await tx.inventoryReservation.update({
            where: { id: reservation.id },
            data: { status: "RELEASED" },
          });
          for (const item of order.items) {
            await tx.productBatch.update({
              where: { id: item.batchId },
              data: { reservedQty: { decrement: item.qty } },
            });
            await tx.inventoryMovement.create({
              data: {
                batchId: item.batchId,
                qty: -item.qty,
                type: "RELEASE",
                orderId: order.id,
                note: `رفض الدفع للطلب ${order.orderCode}`,
                actor: staff.name,
              },
            });
          }
        }
        await tx.order.update({ where: { id: order.id }, data: { status: "PAYMENT_REJECTED" } });
        await tx.orderStatusHistory.create({
          data: {
            orderId: order.id,
            fromStatus: order.status,
            toStatus: "PAYMENT_REJECTED",
            actor: staff.name,
            note: `رفض الدفع: ${reason}`,
          },
        });
        await tx.notification.create({
          data: {
            audience: "CUSTOMER",
            title: "لم يتم التحقق من الدفع",
            body: `رُفض إثبات دفع الطلب ${order.orderCode}. السبب: ${reason}. يمكنك إنشاء طلب جديد أو التواصل معنا.`,
            orderCode: order.orderCode,
          },
        });
      });
      await logAudit(staff, "PAYMENT_REJECTED", "PAYMENT", payment.id, { status: payment.status }, { status: "REJECTED", reason });
    }

    const fresh = await db.order.findUnique({ where: { id: order.id }, include: ORDER_INCLUDE });
    return ok({ order: await orderToDTO(fresh!) });
  } catch (e) {
    return fail(e);
  }
}
