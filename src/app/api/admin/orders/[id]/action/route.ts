// POST /api/admin/orders/[id]/action — انتقالات حالة الطلب (State Machine صارم)
// action ∈ start_preparing | ready | out_for_delivery | cancel | refund
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import {
  ApiError,
  fail,
  generateOtp,
  logAudit,
  notify,
  ok,
  orderToDTO,
  ORDER_INCLUDE,
  requireStaff,
  type StaffIdentity,
} from "@/lib/server";

const CANCELABLE = ["PENDING_PAYMENT", "PAYMENT_SUBMITTED", "PAYMENT_REJECTED"];
const REFUNDABLE = [
  "CONFIRMED",
  "PREPARING",
  "READY_FOR_DELIVERY",
  "OUT_FOR_DELIVERY",
  "DELIVERED",
  "FAILED_DELIVERY",
];

export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params;
    const body = (await req.json().catch(() => null)) as { action?: string; note?: string } | null;
    const action = body?.action ?? "";
    const note = body?.note?.trim() || null;
    if (!action) throw new ApiError("نوع الإجراء مطلوب", 400);

    // الاسترجاع عملية مالية — OWNER/MANAGER فقط
    const staff: StaffIdentity = await requireStaff(req, action === "refund" ? "verifyPayment" : "advanceOrder");

    const order = await db.order.findUnique({
      where: { id },
      include: { items: true, payments: true, delivery: true },
    });
    if (!order) throw new ApiError("الطلب غير موجود", 404);
    const payment = order.payments[order.payments.length - 1] ?? null;

    let otpOut: string | null = null;

    const transition = async (
      tx: Parameters<Parameters<typeof db.$transaction>[0]>[0],
      toStatus: string,
      extraNote?: string
    ) => {
      await tx.order.update({ where: { id: order.id }, data: { status: toStatus } });
      await tx.orderStatusHistory.create({
        data: {
          orderId: order.id,
          fromStatus: order.status,
          toStatus,
          actor: staff.name,
          note: extraNote ?? note,
        },
      });
    };

    switch (action) {
      case "start_preparing": {
        if (order.status !== "CONFIRMED")
          throw new ApiError("بدء التجهيز يتطلب طلبًا مؤكدًا (تم تأكيد الدفع)", 409);
        await db.$transaction((tx) => transition(tx, "PREPARING"));
        break;
      }
      case "ready": {
        if (order.status !== "PREPARING")
          throw new ApiError("الجاهزية تتطلب الطلب في حالة التجهيز", 409);
        await db.$transaction((tx) => transition(tx, "READY_FOR_DELIVERY"));
        break;
      }
      case "out_for_delivery": {
        if (order.status !== "READY_FOR_DELIVERY")
          throw new ApiError("الخروج للتوصيل يتطلب طلبًا جاهزًا للتوصيل", 409);
        const otp = generateOtp();
        otpOut = otp;
        await db.$transaction(async (tx) => {
          const existing = await tx.deliveryOrder.findUnique({ where: { orderId: order.id } });
          if (existing) {
            await tx.deliveryOrder.update({
              where: { id: existing.id },
              data: {
                status: "OUT_FOR_DELIVERY",
                otp,
                driverName: existing.driverName ?? staff.name,
                assignedAt: existing.assignedAt ?? new Date(),
              },
            });
          } else {
            // WAITING → ASSIGNED → OUT_FOR_DELIVERY في مسار واحد
            await tx.deliveryOrder.create({
              data: {
                orderId: order.id,
                status: "OUT_FOR_DELIVERY",
                driverName: staff.name,
                otp,
                assignedAt: new Date(),
              },
            });
          }
          await transition(tx, "OUT_FOR_DELIVERY");
          await tx.notification.create({
            data: {
              audience: "CUSTOMER",
              title: "طلبك في الطريق 🚚",
              body: `خرج الطلب ${order.orderCode} للتوصيل. رمز التسليم: ${otp} — سلّمه للسائق عند الاستلام.`,
              orderCode: order.orderCode,
            },
          });
        });
        break;
      }
      case "cancel": {
        if (!CANCELABLE.includes(order.status))
          throw new ApiError("لا يمكن إلغاء طلب تم تأكيده — استخدم الاسترجاع", 409);
        await db.$transaction(async (tx) => {
          // تحرير الحجز إن كان نشطًا
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
                data: {
                  reservedQty: { decrement: item.qty },
                  cancelledQty: { increment: item.qty },
                },
              });
              await tx.inventoryMovement.create({
                data: {
                  batchId: item.batchId,
                  qty: -item.qty,
                  type: "CANCEL",
                  orderId: order.id,
                  note: `إلغاء الطلب ${order.orderCode}`,
                  actor: staff.name,
                },
              });
            }
          }
          if (payment && payment.status === "PENDING_VERIFICATION") {
            await tx.payment.update({
              where: { id: payment.id },
              data: { status: "REJECTED", rejectReason: "أُلغي الطلب" },
            });
          }
          await transition(tx, "CANCELLED", note ?? "إلغاء بواسطة الإدارة");
          await tx.notification.create({
            data: {
              audience: "CUSTOMER",
              title: "تم إلغاء طلبك",
              body: `أُلغي الطلب ${order.orderCode}. ${note ?? ""}`.trim(),
              orderCode: order.orderCode,
            },
          });
        });
        break;
      }
      case "refund": {
        if (!REFUNDABLE.includes(order.status))
          throw new ApiError("الاسترجاع متاح للطلبات المدفوعة فقط", 409);
        if (!payment || payment.status !== "PAID")
          throw new ApiError("لا يوجد دفع مؤكد لاسترجاعه", 409);
        await db.$transaction(async (tx) => {
          await tx.payment.update({
            where: { id: payment.id },
            data: { status: "REFUNDED" },
          });
          await transition(tx, "REFUNDED", note ?? "استرجاع المبلغ");
          await tx.notification.create({
            data: {
              audience: "CUSTOMER",
              title: "تم استرجاع مبلغ طلبك",
              body: `تم اعتماد استرجاع مبلغ الطلب ${order.orderCode} (${payment.amount} ريال). ${note ?? ""}`.trim(),
              orderCode: order.orderCode,
            },
          });
        });
        break;
      }
      default:
        throw new ApiError("إجراء غير معروف", 400);
    }

    await logAudit(staff, `ORDER_${action.toUpperCase()}`, "ORDER", order.id, {
      status: order.status,
    }, { status: action });

    const fresh = await db.order.findUnique({ where: { id: order.id }, include: ORDER_INCLUDE });
    return ok({ order: await orderToDTO(fresh!), ...(otpOut ? { otp: otpOut } : {}) });
  } catch (e) {
    return fail(e);
  }
}
