// GET /api/admin/orders?status=&q= — قائمة طلبات الإدارة مع بحث
import { NextRequest } from "next/server";
import { Prisma } from "@prisma/client";
import { db } from "@/lib/db";
import { fail, ok, ordersToDTOs, ORDER_INCLUDE, requireStaff } from "@/lib/server";

export async function GET(req: NextRequest) {
  try {
    await requireStaff(req);
    const sp = req.nextUrl.searchParams;
    const status = sp.get("status") ?? "";
    const q = (sp.get("q") ?? "").trim();

    const where: Prisma.OrderWhereInput = {};
    if (status) where.status = status;
    if (q) {
      where.OR = [
        { orderCode: { contains: q } },
        { customerName: { contains: q } },
        { phone: { contains: q } },
        { payments: { some: { transactionRef: { contains: q } } } },
      ];
    }

    const orders = await db.order.findMany({
      where,
      include: ORDER_INCLUDE,
      orderBy: { createdAt: "desc" },
      take: 200,
    });
    return ok({ orders: await ordersToDTOs(orders) });
  } catch (e) {
    return fail(e);
  }
}
