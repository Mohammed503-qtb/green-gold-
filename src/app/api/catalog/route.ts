// GET /api/catalog?grade=&search=&sort=newest|popular|price_asc|price_desc
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import {
  BATCH_INCLUDE,
  batchToCardDTO,
  computeAvailable,
  fail,
  ok,
  releaseExpiredReservations,
  syncBatchStockState,
} from "@/lib/server";

export async function GET(req: NextRequest) {
  try {
    const sp = req.nextUrl.searchParams;
    const grade = sp.get("grade") ?? "";
    const search = (sp.get("search") ?? "").trim();
    const sort = sp.get("sort") ?? "newest";

    // تحرير الحجوزات المنتهية أولًا (lazy expiry)
    await releaseExpiredReservations();

    const batches = await db.productBatch.findMany({
      where: { status: "ACTIVE" },
      include: BATCH_INCLUDE,
    });

    // SOLD_OUT تلقائي لأي دفعة وصل متاحها إلى صفر
    for (const b of batches) {
      if (computeAvailable(b) <= 0) {
        await db.$transaction(async (tx) => {
          await syncBatchStockState(tx, b.id, { wasAvailable: 1, actor: "SYSTEM" });
        });
      }
    }

    let cards = batches.map(batchToCardDTO).filter((b) => b.availableQty > 0);

    if (grade) cards = cards.filter((b) => b.grade === grade);
    if (search) {
      const q = search.toLowerCase();
      cards = cards.filter(
        (b) => b.productName.toLowerCase().includes(q) || b.batchCode.toLowerCase().includes(q)
      );
    }

    switch (sort) {
      case "popular":
        cards.sort(
          (a, b) => b.soldCount - a.soldCount || +new Date(b.capturedAt) - +new Date(a.capturedAt)
        );
        break;
      case "price_asc":
        cards.sort((a, b) => a.price - b.price);
        break;
      case "price_desc":
        cards.sort((a, b) => b.price - a.price);
        break;
      case "newest":
      default:
        cards.sort((a, b) => +new Date(b.capturedAt) - +new Date(a.capturedAt));
        break;
    }

    return ok({ batches: cards });
  } catch (e) {
    return fail(e);
  }
}
