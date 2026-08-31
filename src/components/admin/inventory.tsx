"use client";

// ============================================================
// GREEN GOLD | جدول المخزون + سجل الحركات
// متاح/محجوز/مباع/إجمالي + شارات التحذير + أيقونات الحركات
// ============================================================

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  ArrowUpCircle,
  Lock,
  Undo2,
  CheckCircle2,
  Scale,
  XCircle,
  RefreshCw,
  Boxes,
  History,
  ArrowDownLeft,
  ArrowUpRight,
} from "lucide-react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  CAN,
  LOW_STOCK_THRESHOLD,
  formatArabicDate,
  formatYER,
} from "@/lib/contracts";
import {
  adminApi,
  formatNum,
  listOf,
  normalizeMovements,
  type AdminBatchDTO,
  type MovementDTO,
  type StaffSession,
} from "./api";
import { BatchStatusBadge, EmptyState, GradeBadge, LoadingRows, StockBadge } from "./bits";
import { timeAgoArSafe } from "./dashboard";
import { cn } from "@/lib/utils";

// أيقونات وأنماط أنواع الحركات
const MOVEMENT_META: Record<string, { icon: typeof ArrowUpCircle; label: string; cls: string }> = {
  ADD: { icon: ArrowUpCircle, label: "إضافة كمية", cls: "text-emerald-600 bg-emerald-100 dark:bg-emerald-500/15" },
  RESERVE: { icon: Lock, label: "حجز لطلب", cls: "text-amber-700 bg-amber-100 dark:bg-amber-500/15" },
  RELEASE: { icon: Undo2, label: "تحرير حجز", cls: "text-teal-700 bg-teal-100 dark:bg-teal-500/15" },
  SOLD: { icon: CheckCircle2, label: "بيع مؤكد", cls: "text-emerald-700 bg-emerald-100 dark:bg-emerald-500/15" },
  ADJUST: { icon: Scale, label: "تسوية يدوية", cls: "text-stone-600 bg-stone-100 dark:bg-stone-500/15" },
  CANCEL: { icon: XCircle, label: "إلغاء طلب", cls: "text-red-600 bg-red-100 dark:bg-red-500/15" },
};

export function MovementIcon({ type, className }: { type: string; className?: string }) {
  const meta = MOVEMENT_META[type] ?? MOVEMENT_META.ADJUST;
  const Icon = meta.icon;
  return (
    <span
      className={cn("flex size-8 shrink-0 items-center justify-center rounded-lg", meta.cls, className)}
      title={meta.label}
      aria-label={meta.label}
    >
      <Icon className="size-4" aria-hidden="true" />
    </span>
  );
}

export function movementLabel(type: string): string {
  return MOVEMENT_META[type]?.label ?? type;
}

interface InventoryProps {
  session: StaffSession;
}

export function Inventory({ session }: InventoryProps) {
  const [batches, setBatches] = useState<AdminBatchDTO[] | null>(null);
  const [movements, setMovements] = useState<MovementDTO[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [onlyProblems, setOnlyProblems] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [bData, iData] = await Promise.all([
        adminApi.get<unknown>("/api/admin/batches", { silent: true }),
        adminApi.get<unknown>("/api/admin/inventory", { silent: true }),
      ]);
      setBatches(listOf<AdminBatchDTO>(bData, "batches"));
      setMovements(normalizeMovements(iData));
    } catch {
      setBatches([]);
      setMovements([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const rows = useMemo(() => {
    let list = batches ?? [];
    if (onlyProblems) {
      list = list.filter((b) => b.availableQty <= LOW_STOCK_THRESHOLD);
    }
    return [...list].sort((a, b) => a.availableQty - b.availableQty);
  }, [batches, onlyProblems]);

  const totals = useMemo(() => {
    let total = 0;
    let reserved = 0;
    let sold = 0;
    let available = 0;
    for (const b of batches ?? []) {
      const t = b.totalQty ?? b.availableQty + (b.soldQty ?? b.soldCount) + (b.reservedQty ?? 0);
      total += t;
      reserved += b.reservedQty ?? 0;
      sold += b.soldQty ?? b.soldCount;
      available += b.availableQty;
    }
    return { total, reserved, sold, available };
  }, [batches]);

  const canManage = (CAN.manageBatches as readonly string[]).includes(session.role);

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h2 className="text-lg font-extrabold">المخزون والحركات</h2>
          <p className="text-muted-foreground text-xs">
            المتاح = الإجمالي − المحجوز − المباع • عتبة «مخزون منخفض»: آخر {formatNum(LOW_STOCK_THRESHOLD)} حزم
          </p>
        </div>
        <div className="flex gap-2">
          <Button
            variant={onlyProblems ? "default" : "outline"}
            size="sm"
            className="font-bold"
            onClick={() => setOnlyProblems((v) => !v)}
            aria-pressed={onlyProblems}
          >
            ⚠️ المنخفض والنافد فقط
          </Button>
          <Button variant="outline" size="icon" onClick={() => void load()} aria-label="تحديث المخزون">
            <RefreshCw className="size-4" aria-hidden="true" />
          </Button>
        </div>
      </div>

      {/* ملخص سريع */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {[
          { label: "إجمالي الحزم", value: totals.total, cls: "text-foreground" },
          { label: "متاح الآن", value: totals.available, cls: "text-emerald-700 dark:text-emerald-400" },
          { label: "محجوز لطلبات", value: totals.reserved, cls: "text-amber-700 dark:text-amber-400" },
          { label: "مباع مؤكد", value: totals.sold, cls: "text-primary" },
        ].map((s) => (
          <Card key={s.label} className="rounded-xl">
            <CardContent className="p-3">
              <p className="text-muted-foreground text-[11px] font-medium">{s.label}</p>
              <p className={cn("text-xl font-extrabold tabular-nums", s.cls)}>{formatNum(s.value)}</p>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* جدول الدفعات */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="flex items-center gap-2 text-base font-bold">
            <Boxes className="text-primary size-5" aria-hidden="true" />
            جدول الدفعات
          </CardTitle>
        </CardHeader>
        <CardContent>
          {loading && !batches ? (
            <LoadingRows rows={3} />
          ) : rows.length === 0 ? (
            <EmptyState title={onlyProblems ? "لا توجد دفعات منخفضة أو نافدة 👍" : "لا توجد دفعات في المخزون"} icon={Boxes} />
          ) : (
            <div className="max-h-[52vh] overflow-y-auto" dir="rtl">
              <Table>
                <TableHeader className="sticky top-0 z-10 bg-card">
                  <TableRow>
                    <TableHead className="text-right">الدفعة</TableHead>
                    <TableHead className="text-right">التصنيف</TableHead>
                    <TableHead className="text-center">إجمالي</TableHead>
                    <TableHead className="text-center">محجوز</TableHead>
                    <TableHead className="text-center">مباع</TableHead>
                    <TableHead className="text-center">متاح</TableHead>
                    <TableHead className="text-right">الحالة</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map((b) => {
                    const reserved = b.reservedQty ?? 0;
                    const sold = b.soldQty ?? b.soldCount;
                    const total = b.totalQty ?? b.availableQty + sold + reserved;
                    return (
                      <TableRow key={b.id} className={cn(b.availableQty <= 0 && "bg-red-50/60 dark:bg-red-500/5")}>
                        <TableCell className="max-w-44">
                          <p className="truncate text-xs font-bold">{b.productName}</p>
                          <p className="text-muted-foreground font-mono text-[10px]" dir="ltr">{b.batchCode}</p>
                          <p className="text-muted-foreground text-[10px]">{formatYER(b.price)}</p>
                        </TableCell>
                        <TableCell>
                          <GradeBadge grade={b.grade} />
                        </TableCell>
                        <TableCell className="text-center text-xs tabular-nums">{formatNum(total)}</TableCell>
                        <TableCell className="text-center text-xs font-bold text-amber-700 tabular-nums dark:text-amber-400">
                          {reserved > 0 ? formatNum(reserved) : "—"}
                        </TableCell>
                        <TableCell className="text-center text-xs tabular-nums">{formatNum(sold)}</TableCell>
                        <TableCell className="text-center">
                          <StockBadge available={b.availableQty} />
                        </TableCell>
                        <TableCell>
                          <BatchStatusBadge status={b.status} />
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* سجل الحركات */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="flex items-center gap-2 text-base font-bold">
            <History className="text-primary size-5" aria-hidden="true" />
            آخر حركات المخزون
            {canManage ? (
              <Badge variant="secondary" className="text-[10px]">
                ADD↑ RESERVE🔒 RELEASE↩ SOLD✓ ADJUST⚖ CANCEL✗
              </Badge>
            ) : null}
          </CardTitle>
        </CardHeader>
        <CardContent>
          {!movements ? (
            <LoadingRows rows={3} />
          ) : movements.length === 0 ? (
            <EmptyState title="لا توجد حركات بعد" icon={History} />
          ) : (
            <ul className="max-h-96 space-y-1.5 overflow-y-auto pl-1" aria-label="سجل حركات المخزون">
              {movements.map((m) => {
                const positive = m.qty > 0;
                return (
                  <li
                    key={m.id}
                    className="flex items-center gap-2.5 rounded-xl border p-2.5"
                  >
                    <MovementIcon type={m.type} />
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-xs font-bold">
                        {movementLabel(m.type)}
                        {m.productName || m.batchCode ? (
                          <span className="text-muted-foreground font-normal">
                            {" • "}
                            {m.productName ?? ""}
                            {m.batchCode ? <span className="font-mono text-[10px]" dir="ltr"> {m.batchCode}</span> : null}
                          </span>
                        ) : null}
                      </p>
                      <p className="text-muted-foreground truncate text-[11px]">
                        {m.note ? `${m.note} • ` : ""}
                        {m.actor && m.actor !== "SYSTEM" ? `${m.actor} • ` : ""}
                        {timeAgoArSafe(m.createdAt) || formatArabicDate(m.createdAt)}
                      </p>
                    </div>
                    <span
                      className={cn(
                        "flex shrink-0 items-center gap-0.5 rounded-lg px-2 py-1 text-xs font-extrabold tabular-nums",
                        positive
                          ? "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15"
                          : "bg-red-100 text-red-700 dark:bg-red-500/15"
                      )}
                      dir="ltr"
                    >
                      {positive ? <ArrowUpRight className="size-3" aria-hidden="true" /> : <ArrowDownLeft className="size-3" aria-hidden="true" />}
                      {formatNum(Math.abs(m.qty))}
                    </span>
                  </li>
                );
              })}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
