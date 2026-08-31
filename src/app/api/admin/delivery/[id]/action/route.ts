// POST /api/admin/delivery/[id]/action — تقدم مهمة التوصيل
// action ∈ assign | picked_up | out | delivered | failed
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import {
  ApiError,
  fail,
  logAudit,
  ok,
  orderToDTO,
  ORDER_INCLUDE,
  requireStaff,
  type StaffIdentity,
} from "@/lib/server";

export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params;
    const body = (await req.json().catch(() => null)) as {
      action?: string;
      driverName?: string;
      failReason?: string;
      otp?: string;
      note?: string;
    } | null;
    const action = body?.action ?? "";
    if (!action) throw new ApiError("نوع الإجراء مطلوب", 400);

    const staff: StaffIdentity = await requireStaff(req, "manageDelivery");
    const delivery = await db.deliveryOrder.findUnique({ where: { id }, include: { order: true } });
    if (!delivery) throw new ApiError("مهمة التوصيل غير موجودة", 404);
    const order = delivery.order;

    const setOrderStatus = async (
      tx: Parameters<Parameters<typeof db.$transaction>[0]>[0],
      toStatus: string,
      note?: string
    ) => {
      await tx.order.update({ where: { id: order.id }, data: { status: toStatus } });
      await tx.orderStatusHistory.create({
        data: {
          orderId: order.id,
          fromStatus: order.status,
          toStatus,
          actor: staff.name,
          note: note ?? null,
        },
      });
    };

    switch (action) {
      case "assign": {
        const driverName = body?.driverName?.trim();
        if (!driverName) throw new ApiError("اسم السائق مطلوب", 400);
        if (!["WAITING", "ASSIGNED"].includes(delivery.status))
          throw new ApiError("التعيين متاح قبل بدء التوصيل فقط", 409);
        await db.deliveryOrder.update({
          where: { id },
          data: { driverName, status: "ASSIGNED", assignedAt: delivery.assignedAt ?? new Date() },
        });
        break;
      }
      case "picked_up": {
        if (delivery.status !== "ASSIGNED")
          throw new ApiError("الاستلام من المحل يتطلب مهمة معيّنة لسائق", 409);
        await db.deliveryOrder.update({ where: { id }, data: { status: "PICKED_UP" } });
        break;
      }
      case "out": {
        if (!["ASSIGNED", "PICKED_UP"].includes(delivery.status))
          throw new ApiError("الخروج للتوصيل يتطلب مهمة معيّنة", 409);
        await db.$transaction(async (tx) => {
          await tx.deliveryOrder.update({ where: { id }, data: { status: "OUT_FOR_DELIVERY" } });
          if (order.status === "READY_FOR_DELIVERY" || order.status === "CONFIRMED" || order.status === "PREPARING") {
            await setOrderStatus(tx, "OUT_FOR_DELIVERY", "خرج مع السائق للتوصيل");
            await tx.notification.create({
              data: {
                audience: "CUSTOMER",
                title: "طلبك في الطريق 🚚",
                body: `خرج الطلب ${order.orderCode} للتوصيل مع ${delivery.driverName ?? "السائق"}. رمز التسليم: ${delivery.otp ?? "—"}`,
                orderCode: order.orderCode,
              },
            });
          }
        });
        break;
      }
      case "delivered": {
        if (delivery.status !== "OUT_FOR_DELIVERY")
          throw new ApiError("التسليم يتطلب مهمة خرجت للتوصيل", 409);
        const otp = (body?.otp ?? "").trim();
        if (!otp) throw new ApiError("رمز التسليم (OTP) مطلوب لإتمام التسليم", 400);
        if (!delivery.otp || otp !== delivery.otp)
          throw new ApiError("رمز التسليم غير صحيح", 401);
        await db.$transaction(async (tx) => {
          await tx.deliveryOrder.update({
            where: { id },
            data: { status: "DELIVERED", deliveredAt: new Date(), otpVerifiedAt: new Date() },
          });
          await setOrderStatus(tx, "DELIVERED", "تم التسليم وتحقق الرمز");
          await tx.notification.create({
            data: {
              audience: "CUSTOMER",
              title: "تم تسليم طلبك 🎉",
              body: `تم تسليم الطلب ${order.orderCode} بنجاح. نتشرف بتقييمك لتجربتك مع ذهب أخضر 🌿`,
              orderCode: order.orderCode,
            },
          });
        });
        break;
      }
      case "failed": {
        if (!["OUT_FOR_DELIVERY", "PICKED_UP", "ASSIGNED"].includes(delivery.status))
          throw new ApiError("تعذر التسليم متاح لمهام جارية فقط", 409);
        const failReason = body?.failReason?.trim() ?? body?.note?.trim();
        if (!failReason) throw new ApiError("سبب تعذر التسليم مطلوب", 400);
        await db.$transaction(async (tx) => {
          await tx.deliveryOrder.update({
            where: { id },
            data: { status: "FAILED", failReason },
          });
          await setOrderStatus(tx, "FAILED_DELIVERY", failReason);
          await tx.notification.create({
            data: {
              audience: "ADMIN",
              title: "تعذر التوصيل",
              body: `تعذر تسليم الطلب ${order.orderCode}. السبب: ${failReason}`,
              orderCode: order.orderCode,
            },
          });
        });
        break;
      }
      default:
        throw new ApiError("إجراء غير معروف", 400);
    }

    await logAudit(staff, `DELIVERY_${action.toUpperCase()}`, "DELIVERY", delivery.id, {
      status: delivery.status,
    }, { action });

    const fresh = await db.order.findUnique({ where: { id: order.id }, include: ORDER_INCLUDE });
    return ok({ order: await orderToDTO(fresh!) });
  } catch (e) {
    return fail(e);
  }
}
