// GET /api/admin/customers?q= — قائمة العملاء مع إحصاءاتهم
import { NextRequest } from "next/server";
import { Prisma } from "@prisma/client";
import { db } from "@/lib/db";
import { fail, ok, PAID_ORDER_STATUSES, requireStaff } from "@/lib/server";

export async function GET(req: NextRequest) {
  try {
    await requireStaff(req);
    const q = (req.nextUrl.searchParams.get("q") ?? "").trim();
    const where: Prisma.CustomerWhereInput = q
      ? { OR: [{ name: { contains: q } }, { phone: { contains: q } }] }
      : {};
    const customers = await db.customer.findMany({
      where,
      include: { orders: { select: { status: true, total: true } } },
      orderBy: { createdAt: "desc" },
      take: 200,
    });
    return ok({
      customers: customers.map((c) => {
        const paidOrders = c.orders.filter((o) =>
          (PAID_ORDER_STATUSES as string[]).includes(o.status)
        );
        return {
          id: c.id,
          name: c.name,
          phone: c.phone,
          ordersCount: c.orders.length,
          paidCount: paidOrders.length,
          totalSpent: paidOrders.reduce((s, o) => s + o.total, 0),
          createdAt: c.createdAt.toISOString(),
        };
      }),
    });
  } catch (e) {
    return fail(e);
  }
}
