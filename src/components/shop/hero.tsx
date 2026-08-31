"use client";

// ============================================================
// GREEN GOLD | البطل: تدرج أخضر داكن + شريط الحالة
// ============================================================
import { Package, RefreshCw } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { timeAgoAr } from "@/lib/contracts";

export interface HeroProps {
  availableCount: number;
  lastUpdated: Date | null;
  loading: boolean;
  onOrders: () => void;
}

export function Hero({ availableCount, lastUpdated, loading, onOrders }: HeroProps) {
  return (
    <section className="mx-auto w-full max-w-7xl px-4 pt-6 sm:px-6" aria-label="متعرف على المتجر">
      <div
        className="relative overflow-hidden rounded-3xl p-6 text-white shadow-lg sm:p-10"
        style={{
          backgroundImage:
            "radial-gradient(120% 150% at 85% 0%, oklch(0.55 0.13 150) 0%, oklch(0.42 0.12 152) 45%, oklch(0.29 0.08 155) 100%)",
        }}
      >
        {/* زخرفة */}
        <div className="pointer-events-none absolute -left-10 -bottom-20 select-none text-[11rem] opacity-[0.08]" aria-hidden>
          🌿
        </div>
        <div className="pointer-events-none absolute -top-24 -right-16 size-64 rounded-full bg-gold/20 blur-3xl" aria-hidden />

        <div className="relative z-10 flex flex-col items-start gap-5">
          <span className="rounded-full border border-white/20 bg-white/10 px-3.5 py-1 text-xs font-semibold backdrop-blur">
            🌿 دفعات مصوّرة اليوم — بشوف ما بتستلمه
          </span>

          <div>
            <h1 className="text-3xl font-black tracking-tight sm:text-5xl">
              ذهب <span className="gold-text">أخضر</span>
            </h1>
            <p className="mt-3 max-w-xl text-sm leading-relaxed text-emerald-50/90 sm:text-lg">
              قات اليوم في عدن — بشوف ما بتستلمه قبل ما تدفع:
              صور حقيقية لكل دفعة، جودة مقيسة، وسعر واضح من البداية.
            </p>
          </div>

          {/* شريط الحالة */}
          <div className="flex flex-wrap items-center gap-2.5">
            <span className="flex min-h-9 items-center gap-2 rounded-full border border-white/20 bg-white/10 px-3.5 py-1.5 text-xs font-semibold backdrop-blur sm:text-sm">
              <span className="pulse-dot inline-block size-2 rounded-full bg-emerald-300" aria-hidden />
              {loading ? (
                <Skeleton className="h-4 w-28 bg-white/20" />
              ) : (
                <>
                  <strong className="font-black">{availableCount}</strong> دفعة متوفرة الآن
                </>
              )}
            </span>
            <span className="flex min-h-9 items-center gap-2 rounded-full border border-white/15 bg-white/5 px-3.5 py-1.5 text-xs text-emerald-50/80 backdrop-blur sm:text-sm">
              <RefreshCw className="size-3.5" aria-hidden />
              {lastUpdated ? `تحديث آخر ${timeAgoAr(lastUpdated)}` : "جارٍ جلب الدفعات…"}
            </span>
            <span className="hidden min-h-9 items-center gap-2 rounded-full border border-white/15 bg-white/5 px-3.5 py-1.5 text-xs text-emerald-50/80 backdrop-blur sm:flex sm:text-sm">
              🚚 توصيل داخل عدن
            </span>
          </div>

          {/* الأزرار */}
          <div className="flex flex-wrap items-center gap-3">
            <Button
              asChild
              className="gold-glow h-11 border-none bg-gold px-6 text-base font-black text-gold-foreground hover:bg-gold/90"
            >
              <a href="#catalog">تصفّح قات اليوم</a>
            </Button>
            <Button
              variant="outline"
              onClick={onOrders}
              className="h-11 border-white/30 bg-white/5 px-6 text-white hover:bg-white/15 hover:text-white"
            >
              <Package className="size-4" aria-hidden />
              تتبع طلبي
            </Button>
          </div>
        </div>
      </div>
    </section>
  );
}
