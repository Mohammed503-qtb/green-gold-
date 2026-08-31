// GET /api/admin/delivery?status= — مهام التوصيل مع بيانات العميل
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { fail, ok, requireStaff } from "@/lib/server";

export async function GET(req: NextRequest) {
  try {
    await requireStaff(req, "manageDelivery");
    const status = req.nextUrl.searchParams.get("status") ?? "";
    const deliveries = await db.deliveryOrder.findMany({
      where: status ? { status } : {},
      include: { order: { include: { zone: true, items: true, payments: { orderBy: { createdAt: "desc" }, take: 1 } } } },
      orderBy: { createdAt: "desc" },
      take: 100,
    });
    return ok({
      deliveries: deliveries.map((d) => ({
        id: d.id,
        status: d.status,
        driverName: d.driverName,
        otp: d.otp,
        assignedAt: d.assignedAt?.toISOString() ?? null,
        deliveredAt: d.deliveredAt?.toISOString() ?? null,
        failReason: d.failReason,
        createdAt: d.createdAt.toISOString(),
        paymentStatus: d.order.payments[0]?.status ?? null,
        paymentMethod: d.order.payments[0]
          ? (() => {
              try {
                const snap = JSON.parse(d.order.payments[0].methodSnapshot || "{}");
                return snap.name ?? null;
              } catch {
                return null;
              }
            })()
          : null,
        order: {
          id: d.order.id,
          orderCode: d.order.orderCode,
          status: d.order.status,
          customerName: d.order.customerName,
          phone: d.order.phone,
          addressText: d.order.addressText,
          zoneName: d.order.zone?.name ?? null,
          total: d.order.total,
          note: d.order.note,
          items: d.order.items.map((it) => ({
            productName: it.productName,
            batchCode: it.batchCode,
            qty: it.qty,
          })),
        },
      })),
    });
  } catch (e) {
    return fail(e);
  }
}
