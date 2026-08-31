"use client";

// ============================================================
// GREEN GOLD | بطاقة دفعة القات — الصورة بطل 🔥
// ============================================================
import { Play, ShoppingBag } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  GRADE_EMOJI,
  GRADE_STYLE,
  GRADES,
  LOW_STOCK_THRESHOLD,
  formatYER,
  type BatchCardDTO,
} from "@/lib/contracts";
import { capturedLabel } from "@/components/shop/utils";

export interface BatchCardProps {
  batch: BatchCardDTO;
  onOpen: (batchId: string) => void;
}

export function BatchCard({ batch, onOpen }: BatchCardProps) {
  const { availableQty, soldCount, grade } = batch;
  const low = availableQty > 0 && availableQty <= LOW_STOCK_THRESHOLD;
  const soldRatio =
    availableQty + soldCount > 0 ? soldCount / (availableQty + soldCount) : 0;

  return (
    <article className="group relative flex flex-col overflow-hidden rounded-2xl border bg-card text-card-foreground shadow-sm transition-all duration-300 hover:-translate-y-1 hover:shadow-xl">
      {/* الصورة + معلومات الدفعة (قابلة للنقر) */}
      <button
        type="button"
        onClick={() => onOpen(batch.id)}
        className="w-full flex-1 cursor-pointer text-start outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 rounded-t-2xl"
        aria-label={`تفاصيل دفعة قات ${batch.productName}`}
      >
        <span className="relative block aspect-[4/3] w-full overflow-hidden bg-muted">
          {batch.mainImage ? (
            <img
              src={batch.mainImage}
              alt={`قات ${batch.productName} — دفعة ${batch.batchCode}`}
              loading="lazy"
              decoding="async"
              className="absolute inset-0 size-full object-cover transition-transform duration-500 group-hover:scale-105"
            />
          ) : (
            <span className="absolute inset-0 grid place-items-center text-5xl opacity-40" aria-hidden>
              🌿
            </span>
          )}

          {/* تظليل علوي للشارات */}
          <span className="absolute inset-x-0 top-0 h-16 bg-gradient-to-b from-black/45 to-transparent" aria-hidden />

          {/* شارة التصنيف */}
          <span
            className={`absolute start-2 top-2 inline-flex items-center gap-1 rounded-full border px-2.5 py-1 text-xs font-bold shadow-sm backdrop-blur-sm ${GRADE_STYLE[grade]}`}
          >
            {GRADE_EMOJI[grade]} {GRADES[grade]}
          </span>

          {/* شارة فيديو */}
          {batch.video && (
            <span className="absolute end-2 top-2 inline-flex items-center gap-1 rounded-full bg-black/55 px-2 py-1 text-[11px] font-semibold text-white backdrop-blur-sm">
              <Play className="size-3" aria-hidden />
              فيديو
            </span>
          )}

          {/* عدّاد المتبقي أسفل الصورة */}
          <span className="absolute bottom-2 start-2 inline-flex items-center gap-1.5 rounded-full bg-black/55 px-2.5 py-1 text-[11px] font-bold text-white backdrop-blur-sm">
            {availableQty > 0 ? (
              <>
                <span
                  className={`pulse-dot inline-block size-2 rounded-full ${low ? "bg-amber-400" : "bg-emerald-400"}`}
                  aria-hidden
                />
                {low ? `آخر ${availableQty} حُزمة` : `متوفر ${availableQty} حزمة`}
              </>
            ) : (
              "نفدت الكمية"
            )}
          </span>
        </span>

        {/* المعلومات */}
        <span className="block space-y-2 p-4 pb-2">
          <span className="flex items-start justify-between gap-2">
            <span className="text-base font-extrabold leading-snug">قات {batch.productName}</span>
            {batch.reviewsCount > 0 && batch.avgRating != null && (
              <Badge variant="secondary" className="shrink-0 gap-1 bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300">
                ⭐ {batch.avgRating.toFixed(1)}
              </Badge>
            )}
          </span>

          <span className="block text-[11px] font-medium text-muted-foreground">
            {batch.batchCode}
          </span>

          <span className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-muted-foreground">
            <span>📸 {capturedLabel(batch.capturedAt)}</span>
            {soldCount > 0 && (
              <span className="rounded-full bg-orange-100 px-2 py-0.5 font-bold text-orange-700 dark:bg-orange-950 dark:text-orange-300">
                🔥 بيع {soldCount}
              </span>
            )}
          </span>

          {/* شريط ما تم بيعه */}
          <span className="block">
            <span className="block h-1.5 w-full overflow-hidden rounded-full bg-muted">
              <span
                className="block h-full rounded-full bg-gradient-to-l from-primary to-emerald-500 transition-all"
                style={{ width: `${Math.round(soldRatio * 100)}%` }}
                aria-hidden
              />
            </span>
          </span>
        </span>
      </button>

      {/* السعر + زر الطلب */}
      <div className="flex items-center justify-between gap-3 p-4 pt-2">
        <div className="flex flex-col">
          <span className="text-lg font-black text-primary">{formatYER(batch.price)}</span>
          <span className="text-[11px] text-muted-foreground">للحزمة الواحدة</span>
        </div>
        <Button
          onClick={() => onOpen(batch.id)}
          disabled={availableQty <= 0}
          className="h-11 gap-1.5 rounded-xl px-5 font-bold"
        >
          <ShoppingBag className="size-4" aria-hidden />
          {availableQty > 0 ? "أطلب الآن" : "نفدت"}
        </Button>
      </div>
    </article>
  );
}
