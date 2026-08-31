// GET /api/admin/orders/[id] — تفاصيل طلب للإدارة
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, fail, ok, orderToDTO, ORDER_INCLUDE, requireStaff } from "@/lib/server";

export async function GET(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    await requireStaff(req);
    const { id } = await params;
    const order = await db.order.findUnique({ where: { id }, include: ORDER_INCLUDE });
    if (!order) throw new ApiError("الطلب غير موجود", 404);
    return ok({ order: await orderToDTO(order) });
  } catch (e) {
    return fail(e);
  }
}
