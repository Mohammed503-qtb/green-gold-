// POST /api/reviews — تقييم طلب تم تسليمه (مرة واحدة)
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, fail, notify, ok } from "@/lib/server";
import { SMILEYS } from "@/lib/contracts";

interface ReviewInput {
  orderCode?: string;
  phone?: string;
  rating?: number;
  smiley?: string;
  matchedPhotos?: boolean;
  comment?: string;
}

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json().catch(() => null)) as ReviewInput | null;
    if (!body) throw new ApiError("بيانات التقييم غير صحيحة", 400);

    const orderCode = (body.orderCode ?? "").trim();
    const phone = (body.phone ?? "").trim();
    const rating = Number(body.rating);
    const smiley = (body.smiley ?? "").trim();

    if (!orderCode || !phone) throw new ApiError("رقم الطلب والهاتف مطلوبان", 400);
    if (!Number.isInteger(rating) || rating < 1 || rating > 5)
      throw new ApiError("التقييم يجب أن يكون من 1 إلى 5", 400);
    if (!Object.keys(SMILEYS).includes(smiley))
      throw new ApiError("وجه التقييم غير صحيح", 400);

    const order = await db.order.findUnique({
      where: { orderCode },
      include: { items: true },
    });
    if (!order) throw new ApiError("الطلب غير موجود", 404);
    if (order.phone !== phone) throw new ApiError("رقم الهاتف لا يطابق هذا الطلب", 403);
    if (order.status !== "DELIVERED")
      throw new ApiError("يمكن التقييم بعد تسليم الطلب فقط", 403);

    const existing = await db.review.findUnique({ where: { orderId: order.id } });
    if (existing) throw new ApiError("تم تقييم هذا الطلب مسبقًا", 409);

    const firstItem = order.items[0];
    if (!firstItem) throw new ApiError("الطلب لا يحتوي أصنافًا", 400);

    await db.review.create({
      data: {
        orderId: order.id,
        customerId: order.customerId,
        batchId: firstItem.batchId,
        rating,
        smiley,
        matchedPhotos: body.matchedPhotos ?? null,
        comment: body.comment?.trim() || null,
      },
    });
    await notify(
      "ADMIN",
      "تقييم جديد",
      `قيّم ${order.customerName} الطلب ${order.orderCode} بـ ${rating}/5.`,
      order.orderCode
    );
    return ok({ ok: true });
  } catch (e) {
    return fail(e);
  }
}
