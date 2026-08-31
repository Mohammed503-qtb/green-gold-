// POST /api/admin/delivery/verify-otp — التحقق من رمز التسليم وإتمام التسليم
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, fail, notify, ok, orderToDTO, ORDER_INCLUDE, requireStaff } from "@/lib/server";

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json().catch(() => null)) as {
      deliveryOrderId?: string;
      otp?: string;
    } | null;
    const deliveryOrderId = body?.deliveryOrderId?.trim() ?? "";
    const otp = (body?.otp ?? "").trim();
    if (!deliveryOrderId || !otp) throw new ApiError("معرف المهمة والرمز مطلوبان", 400);

    const staff = await requireStaff(req, "manageDelivery");
    const delivery = await db.deliveryOrder.findUnique({
      where: { id: deliveryOrderId },
      include: { order: true },
    });
    if (!delivery) throw new ApiError("مهمة التوصيل غير موجودة", 404);
    if (delivery.status === "DELIVERED") throw new ApiError("تم تسليم هذه المهمة مسبقًا", 409);
    if (!["OUT_FOR_DELIVERY", "PICKED_UP"].includes(delivery.status))
      throw new ApiError("المهمة ليست في مرحلة تسليم", 409);
    if (!delivery.otp || otp !== delivery.otp)
      throw new ApiError("رمز التسليم غير صحيح", 401);

    const order = delivery.order;
    await db.$transaction(async (tx) => {
      await tx.deliveryOrder.update({
        where: { id: delivery.id },
        data: { status: "DELIVERED", deliveredAt: new Date(), otpVerifiedAt: new Date() },
      });
      await tx.order.update({ where: { id: order.id }, data: { status: "DELIVERED" } });
      await tx.orderStatusHistory.create({
        data: {
          orderId: order.id,
          fromStatus: order.status,
          toStatus: "DELIVERED",
          actor: staff.name,
          note: "تم التسليم والتحقق من الرمز",
        },
      });
    });
    await notify(
      "CUSTOMER",
      "تم تسليم طلبك 🎉",
      `تم تسليم الطلب ${order.orderCode} بنجاح. نتشرف بتقييمك لتجربتك مع ذهب أخضر 🌿`,
      order.orderCode
    );

    const fresh = await db.order.findUnique({ where: { id: order.id }, include: ORDER_INCLUDE });
    return ok({ ok: true, order: await orderToDTO(fresh!) });
  } catch (e) {
    return fail(e);
  }
}
