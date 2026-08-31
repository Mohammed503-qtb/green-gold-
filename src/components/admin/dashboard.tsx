"use client";

// ============================================================
// GREEN GOLD | لوحة المعلومات (Dashboard)
// بطاقات KPI + مخزون + بانتظار التحقق + رسم مبيعات 14 يوم + آخر الطلبات
// ============================================================

import { useEffect, useState } from "react";
import {
  Banknote,
  ClipboardList,
  Hourglass,
  Truck,
  Package,
  AlertTriangle,
  PackageX,
  BadgeCheck,
  ChevronLeft,
  TrendingUp,
  RefreshCw,
} from "lucide-react";
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";
import {
  CAN,
  formatArabicDate,
  formatYER,
  timeAgoAr as timeAgo,
  type OrderStatus,
} from "@/lib/contracts";
import {
  adminApi,
  formatNum,
  normalizeReports,
  type DashboardDTO,
  type ReportsDTO,
  type StaffSession,
} from "./api";
import { EmptyState, KpiCard, Money, OrderStatusBadge } from "./bits";

export type AdminSection =
  | "dashboard"
  | "orders"
  | "payments"
  | "inventory"
  | "delivery"
  | "customers"
  | "reports"
  | "audit";

interface DashboardProps {
  data: DashboardDTO | null;
  loading: boolean;
  session: StaffSession;
  onNavigate: (section: AdminSection, orderStatus?: OrderStatus) => void;
}

function ChartTooltip({ active, payload, label }: {
  active?: boolean;
  payload?: Array<{ value?: number | string; name?: string; dataKey?: string | number }>;
  label?: string | number;
}) {
  if (!active || !payload?.length) return null;
  const total = Number(payload[0]?.value ?? 0);
  return (
    <div className="rounded-lg border bg-popover px-3 py-2 text-xs shadow-md" dir="rtl">
      <p className="font-bold">{typeof label === "string" ? label : String(label ?? "")}</p>
      <p className="text-primary font-semibold">{formatYER(total)}</p>
    </div>
  );
}

export function Dashboard({ data, loading, session, onNavigate }: DashboardProps) {
  const [reports, setReports] = useState<ReportsDTO | null>(null);
  const canViewReports = (CAN.viewReports as readonly string[]).includes(session.role);

  // رسم المبيعات — من التقارير (فقط لمن يملك صلاحية التقارير)
  useEffect(() => {
    if (!canViewReports) return;
    let alive = true;
    adminApi
      .get<unknown>("/api/admin/reports", { silent: true })
      .then((r) => {
        if (alive) setReports(normalizeReports(r));
      })
      .catch(() => {
        /* الرسم اختياري — تجاهل بصمت */
      });
    return () => {
      alive = false;
    };
  }, [canViewReports, data]);

  if (loading && !data) {
    return (
      <div className="space-y-4" aria-busy="true">
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-5">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-20 rounded-xl" />
          ))}
        </div>
        <Skeleton className="h-40 rounded-xl" />
        <Skeleton className="h-64 rounded-xl" />
      </div>
    );
  }

  if (!data) {
    return (
      <EmptyState
        title="تعذر تحميل لوحة المعلومات"
        sub="اسحب للتحديث أو أعد المحاولة بعد لحظات"
        icon={RefreshCw}
      />
    );
  }

  const t = data.today;
  const inv = data.inventory;
  const chartData = reports?.salesByDay.map((d) => ({
    ...d,
    label: d.date ? formatArabicDate(d.date, false) : "",
  }));

  return (
    <div className="space-y-4">
      {/* KPI اليوم */}
      <section aria-label="مؤشرات اليوم" className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-5">
        <KpiCard icon={Banknote} label="مبيعات اليوم" value={formatYER(t.sales)} tone="success" />
        <KpiCard icon={ClipboardList} label="طلبات اليوم" value={formatNum(t.orders)} />
        <KpiCard icon={BadgeCheck} label="طلبات مدفوعة اليوم" value={formatNum(t.paidCount)} tone="success" />
        <button onClick={() => onNavigate("payments")} className="text-start" aria-label="الانتقال إلى الدفعات بانتظار التحقق">
          <KpiCard
            icon={Hourglass}
            label="بانتظار تحقق الدفع"
            value={formatNum(t.pendingVerify)}
            tone={t.pendingVerify > 0 ? "gold" : "default"}
            sub={t.pendingVerify > 0 ? "اضغط للمعالجة الآن ←" : "لا شيء ينتظر"}
            className={cn("h-full transition hover:shadow-md", t.pendingVerify > 0 && "gold-glow")}
          />
        </button>
        <KpiCard icon={Truck} label="خرج للتوصيل" value={formatNum(t.outForDelivery)} />
      </section>

      {/* صف المخزون */}
      <section aria-label="حالة المخزون" className="grid grid-cols-3 gap-3">
        <KpiCard icon={Package} label="دفعات نشطة" value={formatNum(inv.activeBatches)} tone="success" />
        <button onClick={() => onNavigate("inventory")} className="text-start" aria-label="الانتقال إلى المخزون">
          <KpiCard
            icon={AlertTriangle}
            label="مخزون منخفض"
            value={formatNum(inv.lowStock)}
            tone={inv.lowStock > 0 ? "warning" : "default"}
            className="h-full transition hover:shadow-md"
          />
        </button>
        <KpiCard
          icon={PackageX}
          label="دفعات نافدة"
          value={formatNum(inv.soldOut)}
          tone={inv.soldOut > 0 ? "danger" : "default"}
        />
      </section>

      <div className="grid gap-4 lg:grid-cols-5">
        {/* بانتظار التحقق — قائمة سريعة */}
        <Card className="lg:col-span-2">
          <CardHeader className="flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="flex items-center gap-2 text-base font-bold">
              <Hourglass className="text-amber-600 size-5" aria-hidden="true" />
              دفعات بانتظار التحقق
            </CardTitle>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => onNavigate("payments")}
              className="text-primary h-8 gap-1 text-xs font-bold"
            >
              عرض الكل <ChevronLeft className="size-4" aria-hidden="true" />
            </Button>
          </CardHeader>
          <CardContent>
            {data.pendingPayments.length === 0 ? (
              <EmptyState title="لا توجد دفعات بانتظار التحقق" sub="سيظهر هنا كل إثبات دفع جديد ✅" icon={BadgeCheck} />
            ) : (
              <ul className="max-h-72 space-y-2 overflow-y-auto pl-1" aria-label="قائمة الدفعات بانتظار التحقق">
                {data.pendingPayments.map((p) => (
                  <li key={p.paymentId}>
                    <button
                      onClick={() => onNavigate("payments")}
                      className="hover:bg-accent/60 flex w-full items-center justify-between gap-2 rounded-xl border p-3 text-start transition"
                    >
                      <div className="min-w-0">
                        <p className="truncate text-sm font-bold">
                          {p.customerName} <span className="text-muted-foreground">•</span>{" "}
                          <span className="font-mono text-xs" dir="ltr">{p.orderCode}</span>
                        </p>
                        <p className="text-muted-foreground text-xs">
                          {p.submittedAt ? timeAgoArSafe(p.submittedAt) : ""}
                          {p.transactionRef ? ` • مرجع: ${p.transactionRef}` : ""}
                        </p>
                      </div>
                      <Money amount={p.amount} className="text-primary shrink-0 text-sm" />
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>

        {/* رسم مبيعات 14 يوم */}
        {canViewReports ? (
          <Card className="lg:col-span-3">
            <CardHeader className="pb-2">
              <CardTitle className="flex items-center gap-2 text-base font-bold">
                <TrendingUp className="text-primary size-5" aria-hidden="true" />
                المبيعات — آخر 14 يومًا
              </CardTitle>
            </CardHeader>
            <CardContent>
              {chartData && chartData.length > 0 ? (
                <div className="h-56 w-full" dir="ltr">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={chartData} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
                      <defs>
                        <linearGradient id="salesFill" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="var(--chart-1)" stopOpacity={0.45} />
                          <stop offset="100%" stopColor="var(--chart-1)" stopOpacity={0.04} />
                        </linearGradient>
                        <linearGradient id="salesStroke" x1="0" y1="0" x2="1" y2="0">
                          <stop offset="0%" stopColor="var(--chart-1)" />
                          <stop offset="100%" stopColor="var(--chart-2)" />
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
                      <XAxis
                        dataKey="label"
                        tick={{ fontSize: 10 }}
                        stroke="var(--muted-foreground)"
                        interval="preserveStartEnd"
                        tickLine={false}
                        axisLine={false}
                      />
                      <YAxis
                        tick={{ fontSize: 10 }}
                        stroke="var(--muted-foreground)"
                        width={44}
                        tickLine={false}
                        axisLine={false}
                        tickFormatter={(v: number) => (v >= 1000 ? `${Math.round(v / 1000)}k` : String(v))}
                      />
                      <Tooltip content={<ChartTooltip />} />
                      <Area
                        type="monotone"
                        dataKey="total"
                        stroke="url(#salesStroke)"
                        strokeWidth={2.5}
                        fill="url(#salesFill)"
                        name="المبيعات"
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              ) : (
                <div className="flex h-56 items-center justify-center">
                  <EmptyState title="لا توجد بيانات مبيعات بعد" icon={TrendingUp} />
                </div>
              )}
            </CardContent>
          </Card>
        ) : null}
      </div>

      {/* آخر الطلبات */}
      <Card>
        <CardHeader className="flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-base font-bold">آخر الطلبات</CardTitle>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => onNavigate("orders")}
            className="text-primary h-8 gap-1 text-xs font-bold"
          >
            كل الطلبات <ChevronLeft className="size-4" aria-hidden="true" />
          </Button>
        </CardHeader>
        <CardContent>
          {data.recentOrders.length === 0 ? (
            <EmptyState title="لا توجد طلبات بعد" icon={ClipboardList} />
          ) : (
            <ul className="grid gap-2 md:grid-cols-2" aria-label="آخر الطلبات">
              {data.recentOrders.slice(0, 8).map((o) => (
                <li key={o.id}>
                  <button
                    onClick={() => onNavigate("orders")}
                    className="hover:bg-accent/60 flex w-full items-center justify-between gap-2 rounded-xl border p-3 text-start transition"
                  >
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-xs font-bold" dir="ltr">{o.orderCode}</span>
                        <OrderStatusBadge status={o.status} />
                      </div>
                      <p className="text-muted-foreground mt-1 truncate text-xs">
                        {o.customerName} • {o.items.length} صنف • {timeAgoArSafe(o.createdAt)}
                      </p>
                    </div>
                    <Money amount={o.total} className="shrink-0 text-sm" />
                  </button>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

// غلاف آمن لـ timeAgoAr (يتحقق من صلاحية التاريخ)
export function timeAgoArSafe(d: string | null | undefined): string {
  if (!d) return "";
  const date = new Date(d);
  if (Number.isNaN(date.getTime())) return "";
  return timeAgo(date);
}
