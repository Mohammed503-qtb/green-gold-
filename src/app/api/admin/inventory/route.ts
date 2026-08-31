// GET /api/admin/inventory — حركات المخزون + الدفعات منخفضة المخزون
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import {
  BATCH_INCLUDE,
  batchToCardDTO,
  computeAvailable,
  fail,
  ok,
  requireStaff,
} from "@/lib/server";
import { LOW_STOCK_THRESHOLD } from "@/lib/contracts";

export async function GET(req: NextRequest) {
  try {
    await requireStaff(req);
    const [movements, batches] = await Promise.all([
      db.inventoryMovement.findMany({
        orderBy: { createdAt: "desc" },
        take: 100,
        include: { batch: { include: { product: true } } },
      }),
      db.productBatch.findMany({ include: BATCH_INCLUDE }),
    ]);
    const lowStock = batches
      .filter((b) => b.status !== "CLOSED" && b.status !== "HIDDEN")
      .filter((b) => {
        const av = computeAvailable(b);
        return av > 0 && av <= LOW_STOCK_THRESHOLD;
      })
      .map(batchToCardDTO);
    return ok({
      movements: movements.map((m) => ({
        id: m.id,
        batchId: m.batchId,
        batchCode: m.batch.batchCode,
        productName: m.batch.product.name,
        qty: m.qty,
        type: m.type,
        orderId: m.orderId,
        note: m.note,
        actor: m.actor,
        createdAt: m.createdAt.toISOString(),
      })),
      lowStock,
    });
  } catch (e) {
    return fail(e);
  }
}
