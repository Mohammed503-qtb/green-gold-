// GET /api/orders/[code]?phone=xxx — تتبع طلب (403 إذا الهاتف لا يطابق)
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, ORDER_INCLUDE, fail, ok, orderToDTO } from "@/lib/server";

export async function GET(req: NextRequest, { params }: { params: Promise<{ code: string }> }) {
  try {
    const { code } = await params;
    const phone = (req.nextUrl.searchParams.get("phone") ?? "").trim();
    const order = await db.order.findUnique({
      where: { orderCode: code },
      include: ORDER_INCLUDE,
    });
    if (!order) throw new ApiError("الطلب غير موجود", 404);
    if (!phone || order.phone !== phone)
      throw new ApiError("رقم الهاتف لا يطابق هذا الطلب", 403);
    return ok({ order: await orderToDTO(order) });
  } catch (e) {
    return fail(e);
  }
}
