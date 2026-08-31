// GET /api/admin/dashboard — لوحة الإدارة الحية
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import {
  BATCH_INCLUDE,
  batchToCardDTO,
  computeAvailable,
  fail,
  ok,
  ordersToDTOs,
  ORDER_INCLUDE,
  requireStaff,
} from "@/lib/server";
import { LOW_STOCK_THRESHOLD } from "@/lib/contracts";

export async function GET(req: NextRequest) {
  try {
    await requireStaff(req);

    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);

    const [paidToday, ordersToday, pendingVerify, outForDelivery, batches, recentOrders, pendingPayments] =
      await Promise.all([
        db.payment.findMany({
          where: { status: "PAID", verifiedAt: { gte: startOfDay } },
          select: { amount: true },
        }),
        db.order.count({ where: { createdAt: { gte: startOfDay } } }),
        db.payment.count({ where: { status: "PENDING_VERIFICATION" } }),
        db.order.count({ where: { status: "OUT_FOR_DELIVERY" } }),
        db.productBatch.findMany({ include: BATCH_INCLUDE }),
        db.order.findMany({
          orderBy: { createdAt: "desc" },
          take: 8,
          include: ORDER_INCLUDE,
        }),
        db.payment.findMany({
          where: { status: "PENDING_VERIFICATION" },
          orderBy: { submittedAt: "asc" },
          include: { order: true },
        }),
      ]);

    const activeBatches = batches.filter((b) => b.status === "ACTIVE");
    const lowStock = activeBatches.filter(
      (b) => computeAvailable(b) <= LOW_STOCK_THRESHOLD && computeAvailable(b) > 0
    );
    const soldOut = batches.filter(
      (b) => b.status === "SOLD_OUT" || (b.status === "ACTIVE" && computeAvailable(b) <= 0)
    );

    return ok({
      today: {
        sales: paidToday.reduce((s, p) => s + p.amount, 0),
        orders: ordersToday,
        paidCount: paidToday.length,
        pendingVerify,
        outForDelivery,
      },
      inventory: {
        activeBatches: activeBatches.length,
        lowStock: lowStock.length,
        soldOut: soldOut.length,
      },
      recentOrders: await ordersToDTOs(recentOrders),
      pendingPayments: pendingPayments.map((p) => ({
        paymentId: p.id,
        orderCode: p.order.orderCode,
        customerName: p.order.customerName,
        amount: p.amount,
        submittedAt: p.submittedAt?.toISOString() ?? null,
        proofUrl: p.proofUrl,
        transactionRef: p.transactionRef,
      })),
      lowStockBatches: lowStock.slice(0, 6).map(batchToCardDTO),
    });
  } catch (e) {
    return fail(e);
  }
}
