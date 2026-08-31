// GET /api/batches/[id] — تفاصيل دفعة + تقييماتها (للعميل)
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import {
  ApiError,
  BATCH_INCLUDE,
  batchToCardDTO,
  fail,
  ok,
  releaseExpiredReservations,
} from "@/lib/server";

export async function GET(_req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params;
    await releaseExpiredReservations();

    const batch = await db.productBatch.findFirst({
      where: { id, status: { not: "HIDDEN" } },
      include: {
        ...BATCH_INCLUDE,
        reviews: {
          orderBy: { createdAt: "desc" },
          include: { customer: { select: { name: true } } },
        },
      },
    });
    if (!batch) throw new ApiError("الدفعة غير موجودة أو غير متاحة", 404);

    const card = batchToCardDTO(batch);
    return ok({
      batch: {
        ...card,
        description: batch.description,
        productOrigin: batch.product.origin,
        reviews: batch.reviews.map((r) => ({
          rating: r.rating,
          smiley: r.smiley,
          matchedPhotos: r.matchedPhotos,
          comment: r.comment,
          createdAt: r.createdAt.toISOString(),
          customerName: r.customer.name,
        })),
      },
    });
  } catch (e) {
    return fail(e);
  }
}
