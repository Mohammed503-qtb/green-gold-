// GET /api/admin/reports — تقارير المبيعات والمخزون (OWNER/MANAGER)
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { fail, ok, PAID_ORDER_STATUSES, requireStaff } from "@/lib/server";

export async function GET(req: NextRequest) {
  try {
    await requireStaff(req, "viewReports");

    const daysAgo14 = new Date();
    daysAgo14.setHours(0, 0, 0, 0);
    daysAgo14.setDate(daysAgo14.getDate() - 13);

    const [payments, orders, batches, customers, deliveries] = await Promise.all([
      db.payment.findMany({
        where: { status: "PAID", verifiedAt: { gte: daysAgo14 } },
        select: { amount: true, verifiedAt: true },
      }),
      db.order.findMany({
        where: { createdAt: { gte: daysAgo14 } },
        select: { createdAt: true },
      }),
      db.productBatch.findMany({
        include: {
          product: { select: { name: true } },
          reviews: { select: { rating: true } },
          orderItems: { select: { qty: true, lineTotal: true, order: { select: { status: true } } } },
        },
      }),
      db.customer.findMany({ include: { orders: { select: { status: true } } } }),
      db.deliveryOrder.findMany({
        where: { status: "DELIVERED", deliveredAt: { not: null } },
        include: { order: { select: { createdAt: true } } },
      }),
    ]);

    // مبيعات 14 يومًا
    const salesByDay: { date: string; total: number; orders: number }[] = [];
    for (let i = 0; i < 14; i++) {
      const d = new Date(daysAgo14);
      d.setDate(d.getDate() + i);
      const key = d.toISOString().slice(0, 10);
      const total = payments
        .filter((p) => p.verifiedAt?.toISOString().slice(0, 10) === key)
        .reduce((s, p) => s + p.amount, 0);
      const count = orders.filter((o) => o.createdAt.toISOString().slice(0, 10) === key).length;
      salesByDay.push({ date: key, total, orders: count });
    }

    // أفضل الدفعات
    const paidSet = PAID_ORDER_STATUSES as string[];
    const topBatches = batches
      .map((b) => {
        const soldItems = b.orderItems.filter((i) => paidSet.includes(i.order.status));
        const ratings = b.reviews.map((r) => r.rating);
        return {
          batchCode: b.batchCode,
          productName: b.product.name,
          soldQty: b.soldQty,
          revenue: soldItems.reduce((s, i) => s + i.lineTotal, 0),
          avgRating: ratings.length
            ? Math.round((ratings.reduce((s, r) => s + r, 0) / ratings.length) * 10) / 10
            : null,
        };
      })
      .sort((a, b) => b.revenue - a.revenue || b.soldQty - a.soldQty)
      .slice(0, 5);

    // توزيع التصنيفات
    const gradeMap = new Map<string, number>();
    for (const b of batches) gradeMap.set(b.grade, (gradeMap.get(b.grade) ?? 0) + 1);
    const gradeDistribution = [...gradeMap.entries()].map(([grade, count]) => ({ grade, count }));

    // العملاء
    let repeatCustomers = 0;
    for (const c of customers) {
      const paidCount = c.orders.filter((o) => paidSet.includes(o.status)).length;
      if (paidCount >= 2) repeatCustomers++;
    }

    // متوسط زمن التسليم (من إنشاء الطلب حتى التسليم)
    const deliveryMinutes = deliveries
      .map((d) => (d.deliveredAt!.getTime() - d.order.createdAt.getTime()) / 60000)
      .filter((m) => m >= 0);
    const avgDeliveryMinutes = deliveryMinutes.length
      ? Math.round(deliveryMinutes.reduce((s, m) => s + m, 0) / deliveryMinutes.length)
      : null;

    return ok({
      salesByDay,
      topBatches,
      gradeDistribution,
      repeatCustomers,
      totalCustomers: customers.length,
      avgDeliveryMinutes,
    });
  } catch (e) {
    return fail(e);
  }
}
