"use client";

// ============================================================
// GREEN GOLD | عناصر مشتركة صغيرة لواجهة الإدارة
// (شارات + حالات فراغ + hook debounce + بطاقات KPI)
// ============================================================

import { useEffect, useRef, useState } from "react";
import {
  ORDER_STATUSES,
  ORDER_STATUS_STYLE,
  PAYMENT_STATUSES,
  PAYMENT_STATUS_STYLE,
  GRADES,
  GRADE_STYLE,
  GRADE_EMOJI,
  LOW_STOCK_THRESHOLD,
  formatYER,
  type Grade,
  type OrderStatus,
  type PaymentStatus,
} from "@/lib/contracts";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import { formatNum } from "./api";
import type { LucideIcon } from "lucide-react";
import { PackageOpen } from "lucide-react";

/** debounce بسيط للبحث */
export function useDebounce<T>(value: T, delay = 400): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(t);
  }, [value, delay]);
  return debounced;
}

/** شارة حالة الطلب — من العقود مباشرة */
export function OrderStatusBadge({ status, className }: { status: OrderStatus; className?: string }) {
  return (
    <Badge variant="outline" className={cn(ORDER_STATUS_STYLE[status] ?? "", className)}>
      {ORDER_STATUSES[status] ?? status}
    </Badge>
  );
}

/** شارة حالة الدفع */
export function PaymentStatusBadge({
  status,
  className,
}: {
  status: PaymentStatus | null | undefined;
  className?: string;
}) {
  if (!status || !(status in PAYMENT_STATUSES)) return null;
  return (
    <Badge variant="outline" className={cn(PAYMENT_STATUS_STYLE[status], className)}>
      {PAYMENT_STATUSES[status]}
    </Badge>
  );
}

/** شارة التصنيف */
export function GradeBadge({ grade, className }: { grade: Grade | string; className?: string }) {
  const key = (grade in GRADES ? grade : "ECONOMIC") as Grade;
  return (
    <Badge variant="outline" className={cn(GRADE_STYLE[key], className)}>
      {GRADE_EMOJI[key]} {GRADES[key]}
    </Badge>
  );
}

/** شارة حالة الدفعة (ACTIVE/HIDDEN/CLOSED/SOLD_OUT) */
export const BATCH_STATUS_LABELS: Record<string, string> = {
  ACTIVE: "نشطة",
  HIDDEN: "مخفية",
  CLOSED: "مغلقة",
  SOLD_OUT: "نافدة",
};
export const BATCH_STATUS_STYLE: Record<string, string> = {
  ACTIVE: "bg-emerald-100 text-emerald-800 border-emerald-200",
  HIDDEN: "bg-stone-100 text-stone-600 border-stone-300",
  CLOSED: "bg-orange-100 text-orange-800 border-orange-200",
  SOLD_OUT: "bg-red-100 text-red-700 border-red-200",
};
export function BatchStatusBadge({ status, className }: { status: string; className?: string }) {
  return (
    <Badge variant="outline" className={cn(BATCH_STATUS_STYLE[status] ?? "", className)}>
      {BATCH_STATUS_LABELS[status] ?? status}
    </Badge>
  );
}

/** شارة المخزون: 🟢 متوفر / 🟡 آخر X / 🔴 نافد */
export function StockBadge({
  available,
  className,
}: {
  available: number;
  className?: string;
}) {
  if (available <= 0) {
    return (
      <Badge variant="outline" className={cn("bg-red-100 text-red-700 border-red-200", className)}>
        🔴 نافد
      </Badge>
    );
  }
  if (available <= LOW_STOCK_THRESHOLD) {
    return (
      <Badge variant="outline" className={cn("bg-amber-100 text-amber-800 border-amber-200", className)}>
        🟡 آخر {formatNum(available)}
      </Badge>
    );
  }
  return (
    <Badge variant="outline" className={cn("bg-emerald-100 text-emerald-800 border-emerald-200", className)}>
      🟢 متوفر {formatNum(available)}
    </Badge>
  );
}

/** مبلغ مالي منسق */
export function Money({
  amount,
  className,
  strong = true,
}: {
  amount: number;
  className?: string;
  strong?: boolean;
}) {
  return (
    <span dir="rtl" className={cn(strong && "font-extrabold", className)}>
      {formatYER(amount)}
    </span>
  );
}

/** بطاقة KPI كبيرة */
export function KpiCard({
  icon: Icon,
  label,
  value,
  sub,
  tone = "default",
  className,
}: {
  icon: LucideIcon;
  label: string;
  value: string;
  sub?: string;
  tone?: "default" | "gold" | "warning" | "danger" | "success";
  className?: string;
}) {
  const tones: Record<string, string> = {
    default: "text-primary bg-primary/10",
    gold: "text-amber-700 dark:text-amber-400 bg-amber-100 dark:bg-amber-500/15",
    warning: "text-amber-700 dark:text-amber-400 bg-amber-100 dark:bg-amber-500/15",
    danger: "text-red-600 dark:text-red-400 bg-red-100 dark:bg-red-500/15",
    success: "text-emerald-700 dark:text-emerald-400 bg-emerald-100 dark:bg-emerald-500/15",
  };
  return (
    <Card className={cn("rounded-xl shadow-sm", className)}>
      <CardContent className="flex items-center gap-3 p-4">
        <div className={cn("flex size-11 shrink-0 items-center justify-center rounded-xl", tones[tone])}>
          <Icon className="size-5" aria-hidden="true" />
        </div>
        <div className="min-w-0 flex-1">
          <p className="text-muted-foreground truncate text-xs font-medium">{label}</p>
          <p className="truncate text-xl font-extrabold tabular-nums" dir="rtl">
            {value}
          </p>
          {sub ? <p className="text-muted-foreground truncate text-[11px]">{sub}</p> : null}
        </div>
      </CardContent>
    </Card>
  );
}

/** حالة فراغ أنيقة للقوائم */
export function EmptyState({
  title,
  sub,
  icon: Icon = PackageOpen,
}: {
  title: string;
  sub?: string;
  icon?: LucideIcon;
}) {
  return (
    <div className="text-muted-foreground flex flex-col items-center justify-center gap-2 rounded-xl border border-dashed p-8 text-center">
      <Icon className="size-10 opacity-40" aria-hidden="true" />
      <p className="text-sm font-semibold">{title}</p>
      {sub ? <p className="text-xs opacity-80">{sub}</p> : null}
    </div>
  );
}

/** مؤشر تحميل صف متكرر */
export function LoadingRows({ rows = 3 }: { rows?: number }) {
  return (
    <div className="space-y-3" aria-busy="true" aria-label="جارٍ التحميل">
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="bg-muted/60 h-20 animate-pulse rounded-xl" />
      ))}
    </div>
  );
}

/** زر أيقونة صغير موحد */
export function MiniInfo({ text }: { text: string }) {
  return (
    <span className="text-muted-foreground text-[11px] leading-relaxed" role="note">
      {text}
    </span>
  );
}

/** يمنع تحديث المكوّن عند عدم التركيز — يوقف الـ polling عندما تكون النافذة مخفية */
export function useIsVisible(): boolean {
  const [visible, setVisible] = useState(true);
  const ref = useRef<boolean>(true);
  useEffect(() => {
    const onChange = () => {
      const v = document.visibilityState === "visible";
      ref.current = v;
      setVisible(v);
    };
    document.addEventListener("visibilitychange", onChange);
    return () => document.removeEventListener("visibilitychange", onChange);
  }, []);
  return visible;
}
