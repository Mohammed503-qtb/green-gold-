"use client";

// ============================================================
// GREEN GOLD | التقارير — بطاقات + رسوم recharts
// مبيعات 14 يوم (Area) + توزيع التصنيفات (Pie) + أفضل الدفعات (Bar)
// ============================================================

import { useEffect, useState } from "react";
import {
  Users,
  Repeat,
  Percent,
  Timer,
  TrendingUp,
  PieChart as PieIcon,
  BarChart3,
  RefreshCw,
  Star,
} from "lucide-react";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { toast } from "@/hooks/use-toast";
import { GRADES, formatArabicDate, formatYER } from "@/lib/contracts";
import { adminApi, formatNum, normalizeReports, type ReportsDTO } from "./api";
import { EmptyState, KpiCard, LoadingRows } from "./bits";

const PIE_COLORS = ["var(--chart-1)", "var(--chart-2)", "var(--chart-3)", "var(--chart-4)"];

export function Reports() {
  const [data, setData] = useState<ReportsDTO | null>(null);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    setLoading(true);
    try {
      const res = await adminApi.get<unknown>("/api/admin/reports", { silent: true });
      setData(normalizeReports(res));
    } catch {
      setData(null);
      toast({ title: "تعذر تحميل التقارير", variant: "destructive" });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  if (loading && !data) return <LoadingRows rows={5} />;

  if (!data) {
    return (
      <div className="space-y-4">
        <EmptyState title="تعذر تحميل التقارير" icon={BarChart3} />
        <div className="flex justify-center">
          <Button variant="outline" onClick={() => void load()}>
            <RefreshCw className="size-4" aria-hidden="true" /> إعادة المحاولة
          </Button>
        </div>
      </div>
    );
  }

  const repeatRate =
    data.totalCustomers > 0 ? Math.round((data.repeatCustomers / data.totalCustomers) * 100) : 0;

  const salesChart = data.salesByDay.map((d) => ({
    ...d,
    label: d.date ? formatArabicDate(d.date, false) : "",
  }));

  const gradeChart = data.gradeDistribution.map((g) => ({
    name: GRADES[g.grade as keyof typeof GRADES] ?? g.grade,
    value: g.count,
  }));

  const topChart = data.topBatches.slice(0, 8).map((b) => ({
    name: b.productName.length > 10 ? `${b.productName.slice(0, 10)}…` : b.productName,
    full: `${b.productName} (${b.batchCode})`,
    revenue: b.revenue,
    soldQty: b.soldQty,
    avgRating: b.avgRating,
  }));

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-extrabold">التقارير</h2>
          <p className="text-muted-foreground text-xs">نظرة تحليلية على المبيعات والعملاء والمخزون.</p>
        </div>
        <Button variant="outline" size="icon" onClick={() => void load()} aria-label="تحديث التقارير">
          <RefreshCw className="size-4" aria-hidden="true" />
        </Button>
      </div>

      {/* بطاقات الإحصاء */}
      <section className="grid grid-cols-2 gap-3 lg:grid-cols-4" aria-label="إحصاءات عامة">
        <KpiCard icon={Users} label="إجمالي العملاء" value={formatNum(data.totalCustomers)} />
        <KpiCard icon={Repeat} label="عملاء متكررون" value={formatNum(data.repeatCustomers)} tone="success" />
        <KpiCard
          icon={Percent}
          label="معدل إعادة الطلب"
          value={`${formatNum(repeatRate)}%`}
          tone={repeatRate >= 30 ? "success" : "default"}
          sub="نسبة المتكررين من الإجمالي"
        />
        <KpiCard
          icon={Timer}
          label="متوسط زمن التوصيل"
          value={data.avgDeliveryMinutes != null ? `${formatNum(Math.round(data.avgDeliveryMinutes))} دقيقة` : "—"}
          tone="gold"
        />
      </section>

      {/* مبيعات 14 يوم */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="flex items-center gap-2 text-base font-bold">
            <TrendingUp className="text-primary size-5" aria-hidden="true" />
            المبيعات — آخر 14 يومًا
          </CardTitle>
        </CardHeader>
        <CardContent>
          {salesChart.length === 0 ? (
            <EmptyState title="لا توجد مبيعات مسجلة بعد" icon={TrendingUp} />
          ) : (
            <div className="h-64 w-full" dir="ltr">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={salesChart} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
                  <defs>
                    <linearGradient id="repSalesFill" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="var(--chart-1)" stopOpacity={0.45} />
                      <stop offset="100%" stopColor="var(--chart-1)" stopOpacity={0.04} />
                    </linearGradient>
                    <linearGradient id="repSalesStroke" x1="0" y1="0" x2="1" y2="0">
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
                  <Tooltip
                    formatter={(value: number | string) => [formatYER(Number(value)), "المبيعات"]}
                    contentStyle={{
                      borderRadius: 12,
                      border: "1px solid var(--border)",
                      background: "var(--popover)",
                      direction: "rtl",
                      fontSize: 12,
                    }}
                  />
                  <Area
                    type="monotone"
                    dataKey="total"
                    stroke="url(#repSalesStroke)"
                    strokeWidth={2.5}
                    fill="url(#repSalesFill)"
                    name="المبيعات"
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          )}
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-5">
        {/* توزيع التصنيفات */}
        <Card className="lg:col-span-2">
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-base font-bold">
              <PieIcon className="text-primary size-5" aria-hidden="true" />
              توزيع الدفعات حسب التصنيف
            </CardTitle>
          </CardHeader>
          <CardContent>
            {gradeChart.length === 0 ? (
              <EmptyState title="لا توجد دفعات" icon={PieIcon} />
            ) : (
              <div className="h-60 w-full" dir="ltr">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={gradeChart}
                      dataKey="value"
                      nameKey="name"
                      cx="50%"
                      cy="50%"
                      innerRadius={45}
                      outerRadius={80}
                      paddingAngle={3}
                      strokeWidth={0}
                    >
                      {gradeChart.map((_, i) => (
                        <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip
                      formatter={(value: number | string, name: string) => [`${formatNum(Number(value))} دفعة`, name]}
                      contentStyle={{
                        borderRadius: 12,
                        border: "1px solid var(--border)",
                        background: "var(--popover)",
                        direction: "rtl",
                        fontSize: 12,
                      }}
                    />
                    <Legend
                      formatter={(value: string) => <span style={{ fontSize: 12, marginInline: 4 }}>{value}</span>}
                    />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            )}
          </CardContent>
        </Card>

        {/* أفضل الدفعات */}
        <Card className="lg:col-span-3">
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-base font-bold">
              <BarChart3 className="text-primary size-5" aria-hidden="true" />
              أفضل الدفعات مبيعًا (الإيراد)
            </CardTitle>
          </CardHeader>
          <CardContent>
            {topChart.length === 0 ? (
              <EmptyState title="لا توجد مبيعات بعد" icon={BarChart3} />
            ) : (
              <div className="h-60 w-full" dir="ltr">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={topChart} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
                    <XAxis
                      dataKey="name"
                      tick={{ fontSize: 10 }}
                      stroke="var(--muted-foreground)"
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
                    <Tooltip
                      cursor={{ fill: "var(--accent)" }}
                      formatter={(value: number | string, _name: string, item: { payload?: { full?: string; soldQty?: number; avgRating?: number | null } }) => {
                        const p = item?.payload;
                        return [
                          <span key="v" dir="rtl">
                            {formatYER(Number(value))}
                            {p?.soldQty ? ` • ${formatNum(p.soldQty)} حزمة` : ""}
                            {p?.avgRating ? ` • ⭐ ${p.avgRating}` : ""}
                          </span>,
                          p?.full ?? "",
                        ];
                      }}
                      contentStyle={{
                        borderRadius: 12,
                        border: "1px solid var(--border)",
                        background: "var(--popover)",
                        direction: "rtl",
                        fontSize: 12,
                      }}
                    />
                    <Bar
                      dataKey="revenue"
                      fill="var(--chart-2)"
                      radius={[6, 6, 0, 0]}
                      maxBarSize={42}
                      name="الإيراد"
                    />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* جدول أفضل الدفعات */}
      {data.topBatches.length > 0 ? (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-base font-bold">
              <Star className="text-amber-500 size-5" aria-hidden="true" />
              التفاصيل — أفضل الدفعات
            </CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="max-h-72 divide-y overflow-y-auto pl-1" aria-label="أفضل الدفعات تفصيلًا">
              {data.topBatches.map((b, i) => (
                <li key={b.batchCode + i} className="flex items-center justify-between gap-2 py-2.5 text-xs">
                  <div className="flex min-w-0 items-center gap-2">
                    <span className="bg-primary/10 text-primary flex size-6 shrink-0 items-center justify-center rounded-md text-[10px] font-extrabold tabular-nums">
                      {formatNum(i + 1)}
                    </span>
                    <div className="min-w-0">
                      <p className="truncate font-bold">{b.productName}</p>
                      <p className="text-muted-foreground font-mono text-[10px]" dir="ltr">{b.batchCode}</p>
                    </div>
                  </div>
                  <div className="shrink-0 text-left">
                    <p className="font-extrabold">{formatYER(b.revenue)}</p>
                    <p className="text-muted-foreground text-[10px]">
                      {formatNum(b.soldQty)} حزمة
                      {b.avgRating ? ` • ⭐ ${b.avgRating}` : ""}
                    </p>
                  </div>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      ) : null}
    </div>
  );
}
