"use client";

// ============================================================
// GREEN GOLD | أقسام الكتالوج: شرائح + بحث + شبكة الدفعات
// ============================================================
import { useMemo, useState } from "react";
import { RotateCw, Search } from "lucide-react";

import { BatchCard } from "@/components/shop/batch-card";
import { EmptyState } from "@/components/shop/empty-state";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { GRADES, type BatchCardDTO, type Grade } from "@/lib/contracts";

export interface SectionsProps {
  batches: BatchCardDTO[];
  loading: boolean;
  error: boolean;
  onRefresh: () => void;
  onOpenBatch: (batchId: string) => void;
}

type TabKey = "all" | Grade | "popular" | "new";

const TABS: { key: TabKey; label: string }[] = [
  { key: "all", label: "🌿 قات اليوم" },
  { key: "PREMIUM", label: "💎 فاخر" },
  { key: "EXCELLENT", label: "⭐ ممتاز" },
  { key: "ECONOMIC", label: "💰 اقتصادي" },
  { key: "popular", label: "🔥 الأكثر طلبًا" },
  { key: "new", label: "🆕 وصل حديثًا" },
];

export function Sections({ batches, loading, error, onRefresh, onOpenBatch }: SectionsProps) {
  const [tab, setTab] = useState<TabKey>("all");
  const [search, setSearch] = useState("");

  const filtered = useMemo(() => {
    let list = [...batches];
    const q = search.trim();
    if (q) {
      list = list.filter(
        (b) =>
          b.productName.includes(q) ||
          b.batchCode.toLowerCase().includes(q.toLowerCase()) ||
          GRADES[b.grade].includes(q)
      );
    }
    switch (tab) {
      case "PREMIUM":
      case "EXCELLENT":
      case "ECONOMIC":
        list = list.filter((b) => b.grade === tab);
        break;
      case "popular":
        list.sort((a, b) => b.soldCount - a.soldCount);
        break;
      case "new":
        list.sort((a, b) => new Date(b.capturedAt).getTime() - new Date(a.capturedAt).getTime());
        list = list.slice(0, 8);
        break;
      default:
        list.sort((a, b) => new Date(b.capturedAt).getTime() - new Date(a.capturedAt).getTime());
    }
    return list;
  }, [batches, tab, search]);

  return (
    <section id="catalog" className="mx-auto w-full max-w-7xl scroll-mt-24 px-4 py-8 sm:px-6" aria-label="كتالوج الدفعات">
      {/* الرأس: العنوان + تحديث + بحث */}
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-2.5">
          <h2 className="text-xl font-black sm:text-2xl">🌿 قات اليوم</h2>
          {!loading && !error && (
            <span className="rounded-full bg-muted px-2.5 py-1 text-xs font-bold text-muted-foreground">
              {filtered.length} دفعة
            </span>
          )}
          <Button
            variant="ghost"
            size="icon"
            onClick={onRefresh}
            disabled={loading}
            className="size-11 rounded-xl"
            aria-label="تحديث الدفعات"
          >
            <RotateCw className={`size-4 ${loading ? "animate-spin" : ""}`} aria-hidden />
          </Button>
        </div>

        <div className="relative w-full sm:w-72">
          <Search
            className="pointer-events-none absolute inset-y-0 start-3 my-auto size-4 text-muted-foreground"
            aria-hidden
          />
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="ابحث باسم النوع أو رقم الدفعة…"
            className="h-11 rounded-xl ps-9"
            aria-label="بحث في الدفعات"
          />
        </div>
      </div>

      {/* الشرائح */}
      <Tabs value={tab} onValueChange={(v) => setTab(v as TabKey)} className="gap-5">
        <TabsList className="h-auto w-full justify-start gap-1 overflow-x-auto rounded-2xl bg-muted/60 p-1.5">
          {TABS.map((t) => (
            <TabsTrigger
              key={t.key}
              value={t.key}
              className="h-auto flex-none rounded-xl px-4 py-2.5 text-sm font-semibold whitespace-nowrap data-[state=active]:bg-primary data-[state=active]:text-primary-foreground data-[state=active]:shadow-md"
            >
              {t.label}
            </TabsTrigger>
          ))}
        </TabsList>

        <div>
          {/* تحميل */}
          {loading && (
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
              {Array.from({ length: 8 }).map((_, i) => (
                <div key={i} className="overflow-hidden rounded-2xl border bg-card">
                  <Skeleton className="aspect-[4/3] w-full rounded-none" />
                  <div className="space-y-2.5 p-4">
                    <Skeleton className="h-5 w-2/3" />
                    <Skeleton className="h-3.5 w-1/2" />
                    <Skeleton className="h-3.5 w-2/5" />
                    <div className="flex items-center justify-between pt-2">
                      <Skeleton className="h-7 w-24" />
                      <Skeleton className="h-11 w-24 rounded-xl" />
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* خطأ */}
          {!loading && error && batches.length === 0 && (
            <EmptyState
              icon="📡"
              title="تعذر تحميل الدفعات"
              description="حدث خلل في الاتصال بالخادم. حاول التحديث بعد لحظات."
              action={
                <Button onClick={onRefresh} className="h-11 rounded-xl px-6 font-bold">
                  <RotateCw className="size-4" aria-hidden />
                  إعادة المحاولة
                </Button>
              }
            />
          )}

          {/* لا نتائج */}
          {!loading && !error && filtered.length === 0 && batches.length > 0 && (
            <EmptyState
              icon="🌿"
              title="لا توجد دفعات مطابقة"
              description={
                search.trim()
                  ? `لم نجد نتائج للبحث «${search.trim()}» — جرّب كلمة أخرى أو تصفح تصنيفًا مختلفًا.`
                  : "لا توجد دفعات في هذا التصنيف حاليًا، تصفح «قات اليوم» أو حدّث الصفحة."
              }
              action={
                <Button
                  variant="outline"
                  onClick={() => {
                    setSearch("");
                    setTab("all");
                  }}
                  className="h-11 rounded-xl px-6 font-bold"
                >
                  عرض كل الدفعات
                </Button>
              }
            />
          )}

          {/* لا دفعات إطلاقًا */}
          {!loading && !error && batches.length === 0 && (
            <EmptyState
              icon="🌿"
              title="لا توجد دفعات متوفرة الآن"
              description="الدفعات تُنشر يوميًا مع صور الصباح — عد لاحقًا اليوم أو حدّث الصفحة."
              action={
                <Button onClick={onRefresh} variant="outline" className="h-11 rounded-xl px-6 font-bold">
                  <RotateCw className="size-4" aria-hidden />
                  تحديث
                </Button>
              }
            />
          )}

          {/* الشبكة */}
          {!loading && filtered.length > 0 && (
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
              {filtered.map((b) => (
                <BatchCard key={b.id} batch={b} onOpen={onOpenBatch} />
              ))}
            </div>
          )}
        </div>
      </Tabs>
    </section>
  );
}
