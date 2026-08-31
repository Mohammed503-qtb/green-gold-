"use client";

// ============================================================
// GREEN GOLD | تفاصيل الدفعة — Dialog كبير: معرض صور + جودة + تقييمات
// ============================================================
import { useCallback, useEffect, useState } from "react";
import { ExternalLink, Minus, Play, Plus, ShoppingBag } from "lucide-react";

import { fetchBatch, type BatchDetailDTO } from "@/components/shop/api";
import { capturedLabel } from "@/components/shop/utils";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import { ToastAction } from "@/components/ui/toast";
import { toast } from "@/hooks/use-toast";
import { useCartStore } from "@/lib/cart-store";
import {
  GRADE_EMOJI,
  GRADE_STYLE,
  GRADES,
  LOW_STOCK_THRESHOLD,
  formatYER,
  timeAgoAr,
} from "@/lib/contracts";
import { cn } from "@/lib/utils";

export interface BatchDetailsProps {
  open: boolean;
  batchId: string | null;
  onOpenChange: (open: boolean) => void;
  onViewCart: () => void;
}

const QUALITY_ROWS: { key: keyof NonNullable<BatchDetailDTO["quality"]>; label: string }[] = [
  { key: "freshness", label: "نضارة" },
  { key: "density", label: "كثافة" },
  { key: "fullness", label: "امتلاء" },
  { key: "appearance", label: "مظهر" },
];

export function BatchDetailsDialog({ open, batchId, onOpenChange, onViewCart }: BatchDetailsProps) {
  const [detail, setDetail] = useState<BatchDetailDTO | null>(null);
  const [loading, setLoading] = useState(true);
  const [qty, setQty] = useState(1);
  const [activeImg, setActiveImg] = useState(0);

  const add = useCartStore((s) => s.add);

  // جلب التفاصيل عند التركيب (الأب يعيد التركيب بمفتاح جديد عند كل فتح)
  useEffect(() => {
    if (!batchId) return;
    let cancelled = false;
    fetchBatch(batchId).then((d) => {
      if (!cancelled) {
        setDetail(d);
        setLoading(false);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [batchId]);

  const images = detail?.images?.length ? detail.images : detail?.mainImage ? [detail.mainImage] : [];

  const handleAdd = useCallback(() => {
    if (!detail) return;
    add(detail.id, qty, {
      name: detail.productName,
      grade: detail.grade,
      price: detail.price,
      image: detail.mainImage,
      batchCode: detail.batchCode,
      availableQty: detail.availableQty,
    });
    toast({
      title: "أُضيفت إلى السلة 🛒",
      description: `قات ${detail.productName} × ${qty}`,
      action: (
        <ToastAction
          altText="عرض السلة"
          onClick={() => {
            onOpenChange(false);
            onViewCart();
          }}
        >
          عرض السلة
        </ToastAction>
      ),
    });
  }, [detail, qty, add, onOpenChange, onViewCart]);

  const available = detail ? detail.availableQty > 0 : false;
  const low = detail ? detail.availableQty > 0 && detail.availableQty <= LOW_STOCK_THRESHOLD : false;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] gap-0 overflow-hidden rounded-2xl p-0 sm:max-w-3xl">
        <DialogHeader className="sr-only">
          <DialogTitle>{detail ? `دفعة قات ${detail.productName}` : "تفاصيل الدفعة"}</DialogTitle>
          <DialogDescription>تفاصيل الدفعة والجودة والتقييمات</DialogDescription>
        </DialogHeader>

        <div className="max-h-[calc(92vh-4rem)] overflow-y-auto">
          {loading && (
            <div className="grid gap-0 md:grid-cols-2">
              <div className="space-y-3 p-4 sm:p-5">
                <Skeleton className="aspect-[4/3] w-full rounded-xl" />
                <div className="flex gap-2">
                  {Array.from({ length: 3 }).map((_, i) => (
                    <Skeleton key={i} className="size-16 rounded-lg" />
                  ))}
                </div>
              </div>
              <div className="space-y-3 p-4 sm:p-5">
                <Skeleton className="h-6 w-24" />
                <Skeleton className="h-7 w-2/3" />
                <Skeleton className="h-4 w-1/2" />
                <Skeleton className="h-20 w-full rounded-xl" />
                <Skeleton className="h-12 w-full rounded-xl" />
              </div>
            </div>
          )}

          {!loading && !detail && (
            <div className="p-10 text-center text-sm text-muted-foreground">
              تعذر تحميل تفاصيل الدفعة — أغلق وحاول مرة أخرى 🌿
            </div>
          )}

          {!loading && detail && (
            <>
              <div className="grid md:grid-cols-2">
                {/* المعرض */}
                <div className="space-y-3 p-4 sm:p-5">
                  <div className="relative aspect-[4/3] w-full overflow-hidden rounded-xl border bg-muted">
                    {images[activeImg] ? (
                      <img
                        src={images[activeImg]}
                        alt={`قات ${detail.productName} — صورة ${activeImg + 1}`}
                        loading="lazy"
                        className="absolute inset-0 size-full object-cover"
                      />
                    ) : (
                      <span className="absolute inset-0 grid place-items-center text-6xl opacity-40" aria-hidden>
                        🌿
                      </span>
                    )}
                  </div>

                  {images.length > 1 && (
                    <div className="flex gap-2 overflow-x-auto pb-1" role="tablist" aria-label="صور الدفعة">
                      {images.map((img, i) => (
                        <button
                          key={`${img}-${i}`}
                          type="button"
                          onClick={() => setActiveImg(i)}
                          role="tab"
                          aria-selected={activeImg === i}
                          aria-label={`الصورة ${i + 1}`}
                          className={cn(
                            "size-16 shrink-0 overflow-hidden rounded-lg border-2 transition-all outline-none focus-visible:ring-2 focus-visible:ring-ring",
                            activeImg === i
                              ? "border-primary ring-2 ring-primary/30"
                              : "border-transparent opacity-70 hover:opacity-100"
                          )}
                        >
                          <img src={img} alt="" loading="lazy" className="size-full object-cover" />
                        </button>
                      ))}
                    </div>
                  )}

                  {detail.video && (
                    <Button asChild variant="secondary" className="h-11 w-full rounded-xl font-bold">
                      <a href={detail.video} target="_blank" rel="noopener noreferrer">
                        <Play className="size-4" aria-hidden />
                        مشاهدة فيديو الدفعة
                        <ExternalLink className="size-3.5" aria-hidden />
                      </a>
                    </Button>
                  )}
                </div>

                {/* المعلومات */}
                <div className="space-y-4 border-t p-4 sm:p-5 md:border-s md:border-t-0">
                  <div className="space-y-2">
                    <div className="flex flex-wrap items-center gap-2">
                      <span
                        className={`inline-flex items-center gap-1 rounded-full border px-2.5 py-1 text-xs font-bold ${GRADE_STYLE[detail.grade]}`}
                      >
                        {GRADE_EMOJI[detail.grade]} {GRADES[detail.grade]}
                      </span>
                      <Badge variant="outline" className="font-medium">
                        {detail.batchCode}
                      </Badge>
                    </div>
                    <h3 className="text-xl font-black">قات {detail.productName}</h3>
                    <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-muted-foreground">
                      <span>📸 {capturedLabel(detail.capturedAt)}</span>
                      {detail.productOrigin && <span>📍 المنشأ: {detail.productOrigin}</span>}
                    </div>
                    {detail.description && (
                      <p className="pt-1 text-sm leading-relaxed text-muted-foreground whitespace-pre-line">
                        {detail.description}
                      </p>
                    )}
                  </div>

                  {/* الجودة: 4 أشرطة */}
                  <div className="space-y-3 rounded-xl border bg-muted/40 p-3.5">
                    <h4 className="text-sm font-bold">📊 جودة الدفعة</h4>
                    {detail.quality ? (
                      <div className="grid grid-cols-1 gap-x-5 gap-y-2.5 sm:grid-cols-2">
                        {QUALITY_ROWS.map(({ key, label }) => (
                          <div key={key}>
                            <div className="mb-1 flex items-center justify-between text-xs">
                              <span className="font-semibold">{label}</span>
                              <span className="font-black text-primary">
                                {detail.quality![key]}/10
                              </span>
                            </div>
                            <Progress value={detail.quality![key] * 10} className="h-1.5" />
                          </div>
                        ))}
                      </div>
                    ) : (
                      <p className="text-xs text-muted-foreground">لم تُسجَّل مقاييس جودة لهذه الدفعة.</p>
                    )}
                  </div>

                  {/* التوفر والسعر */}
                  <div className="flex items-end justify-between gap-3">
                    <div className="flex flex-col">
                      <span className="text-2xl font-black text-primary">{formatYER(detail.price)}</span>
                      <span className="text-[11px] text-muted-foreground">للحزمة الواحدة</span>
                    </div>
                    <span
                      className={cn(
                        "flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-bold",
                        !available
                          ? "bg-stone-100 text-stone-600 dark:bg-stone-800 dark:text-stone-300"
                          : low
                            ? "bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300"
                            : "bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300"
                      )}
                    >
                      <span
                        className={`pulse-dot inline-block size-2 rounded-full ${available ? (low ? "bg-amber-500" : "bg-emerald-500") : "bg-stone-400"}`}
                        aria-hidden
                      />
                      {!available ? "نفدت الكمية" : low ? `آخر ${detail.availableQty} حُزمة ⚡` : `متوفر ${detail.availableQty} حزمة`}
                    </span>
                  </div>

                  {/* العدّاد + الإضافة */}
                  <div className="flex items-center gap-3 pt-1">
                    <div className="flex items-center gap-1 rounded-xl border p-1" role="group" aria-label="عدد الحزم">
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="size-11 rounded-lg"
                        onClick={() => setQty((q) => Math.max(1, q - 1))}
                        disabled={qty <= 1}
                        aria-label="تقليل الكمية"
                      >
                        <Minus className="size-4" aria-hidden />
                      </Button>
                      <span className="w-12 text-center text-lg font-black" aria-live="polite">
                        {qty}
                      </span>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="size-11 rounded-lg"
                        onClick={() => setQty((q) => Math.min(detail.availableQty, q + 1))}
                        disabled={qty >= detail.availableQty}
                        aria-label="زيادة الكمية"
                      >
                        <Plus className="size-4" aria-hidden />
                      </Button>
                    </div>

                    <Button
                      onClick={handleAdd}
                      disabled={!available}
                      className="h-12 flex-1 rounded-xl text-base font-black"
                    >
                      <ShoppingBag className="size-4" aria-hidden />
                      {available ? `أضف للسلة — ${formatYER(detail.price * qty)}` : "نفدت الكمية"}
                    </Button>
                  </div>
                </div>
              </div>

              {/* التقييمات */}
              <div className="border-t p-4 sm:p-5">
                <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
                  <h4 className="text-sm font-bold">⭐ تقييمات الدفعة</h4>
                  {detail.reviewsCount > 0 && detail.avgRating != null && (
                    <span className="flex items-center gap-1.5 text-sm">
                      <span className="font-black text-amber-500">{detail.avgRating.toFixed(1)}</span>
                      <span className="text-amber-500">★★★★★</span>
                      <span className="text-xs text-muted-foreground">({detail.reviewsCount} تقييم)</span>
                    </span>
                  )}
                </div>

                {detail.reviews.length === 0 ? (
                  <p className="rounded-xl border border-dashed p-4 text-center text-xs text-muted-foreground">
                    لا تقييمات بعد — سيظهر تقييم العملاء هنا بعد الاستلام 🌿
                  </p>
                ) : (
                  <ul className="max-h-72 space-y-1 overflow-y-auto pe-1">
                    {detail.reviews.map((r, i) => (
                      <li key={i} className="rounded-xl border bg-card p-3">
                        <div className="flex items-start justify-between gap-2">
                          <div className="flex items-center gap-2">
                            <span className="text-xl leading-none" aria-hidden>
                              {r.smiley === "LOVE" ? "😍" : r.smiley === "GOOD" ? "🙂" : r.smiley === "OK" ? "😐" : "☹️"}
                            </span>
                            <div>
                              <p className="text-sm font-bold">{r.customerName ?? "عميل"}</p>
                              <p className="text-[11px] text-muted-foreground">{timeAgoAr(r.createdAt)}</p>
                            </div>
                          </div>
                          <span className="text-xs font-bold text-amber-500">
                            {"★".repeat(r.rating)}
                            <span className="text-muted-foreground/30">{"★".repeat(5 - r.rating)}</span>
                          </span>
                        </div>
                        {r.comment && (
                          <p className="mt-2 text-xs leading-relaxed text-muted-foreground">{r.comment}</p>
                        )}
                        {r.matchedPhotos != null && (
                          <span
                            className={cn(
                              "mt-2 inline-block rounded-full px-2 py-0.5 text-[11px] font-bold",
                              r.matchedPhotos
                                ? "bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300"
                                : "bg-stone-100 text-stone-600 dark:bg-stone-800 dark:text-stone-300"
                            )}
                          >
                            {r.matchedPhotos ? "✅ مطابق للصور" : "📷 غير مطابق للصور"}
                          </span>
                        )}
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
