// GET /api/admin/customers/[id] — ملف العميل: طلباته + مشترياته + تقييماته
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, fail, ok, ordersToDTOs, ORDER_INCLUDE, requireStaff } from "@/lib/server";
import { PAID_ORDER_STATUSES } from "@/lib/server";

export async function GET(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    await requireStaff(req);
    const { id } = await params;
    const customer = await db.customer.findUnique({
      where: { id },
      include: {
        orders: { include: ORDER_INCLUDE, orderBy: { createdAt: "desc" } },
        reviews: {
          include: { batch: { include: { product: true } } },
          orderBy: { createdAt: "desc" },
        },
        addresses: { include: { zone: true } },
      },
    });
    if (!customer) throw new ApiError("العميل غير موجود", 404);
    const paid = customer.orders.filter((o) =>
      (PAID_ORDER_STATUSES as string[]).includes(o.status)
    );
    return ok({
      customer: {
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        createdAt: customer.createdAt.toISOString(),
        totalSpent: paid.reduce((s, o) => s + o.total, 0),
        ordersCount: customer.orders.length,
        paidCount: paid.length,
        addresses: customer.addresses.map((a) => ({
          label: a.label,
          addressText: a.addressText,
          zoneName: a.zone.name,
          notes: a.notes,
        })),
        reviews: customer.reviews.map((r) => ({
          rating: r.rating,
          smiley: r.smiley,
          matchedPhotos: r.matchedPhotos,
          comment: r.comment,
          productName: r.batch.product.name,
          createdAt: r.createdAt.toISOString(),
        })),
        orders: await ordersToDTOs(customer.orders),
      },
    });
  } catch (e) {
    return fail(e);
  }
}
