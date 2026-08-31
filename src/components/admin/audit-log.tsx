"use client";

// ============================================================
// GREEN GOLD | سجل التدقيق (AuditLog)
// المتصفح الوقت / الفاعل بدوره / الإجراء / الكيان / قبل→بعد
// ============================================================

import { useCallback, useEffect, useState } from "react";
import { ScrollText, ArrowLeft, RefreshCw, ShieldCheck } from "lucide-react";
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
import { Input } from "@/components/ui/input";
import { STAFF_ROLES, formatArabicDate, type StaffRole } from "@/lib/contracts";
import { adminApi, normalizeAudit, type AuditRowDTO } from "./api";
import { EmptyState, LoadingRows, useDebounce } from "./bits";
import { timeAgoArSafe } from "./dashboard";

const ACTION_LABELS: Record<string, string> = {
  ORDER_STATUS: "تغيير حالة طلب",
  PAYMENT_VERIFIED: "تحقق دفع",
  PAYMENT_REJECTED: "رفض دفع",
  BATCH_CREATED: "إنشاء دفعة",
  BATCH_STATUS: "تغيير حالة دفعة",
  PRICE_CHANGED: "تغيير سعر",
  QTY_ADDED: "إضافة كمية",
  DELIVERY_ACTION: "إجراء توصيل",
  LOGIN: "تسجيل دخول",
};

const ENTITY_LABELS: Record<string, string> = {
  ORDER: "طلب",
  BATCH: "دفعة",
  PAYMENT: "دفع",
  DELIVERY: "توصيل",
  SETTING: "إعداد",
  CUSTOMER: "عميل",
};

function shortJson(raw: string | null): string {
  if (!raw) return "—";
  try {
    const parsed = JSON.parse(raw);
    return JSON.stringify(parsed);
  } catch {
    return raw;
  }
}

function roleLabel(role: string): string {
  return STAFF_ROLES[role as StaffRole] ?? role;
}

export function AuditLog() {
  const [rows, setRows] = useState<AuditRowDTO[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState("");
  const debouncedQ = useDebounce(q, 300);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await adminApi.get<unknown>("/api/admin/audit", { silent: true });
      setRows(normalizeAudit(data));
    } catch {
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const filtered = (rows ?? []).filter((r) => {
    const term = debouncedQ.trim().toLowerCase();
    if (!term) return true;
    return (
      r.actorName.toLowerCase().includes(term) ||
      r.action.toLowerCase().includes(term) ||
      r.entityType.toLowerCase().includes(term) ||
      r.entityId.toLowerCase().includes(term) ||
      (ACTION_LABELS[r.action] ?? "").includes(debouncedQ.trim())
    );
  });

  return (
    <div className="space-y-4">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-lg font-extrabold">سجل التدقيق</h2>
          <p className="text-muted-foreground text-xs">
            آخر 100 عملية حساسة — من فعل ماذا ومتى ومع «قبل ← بعد».
          </p>
        </div>
        <div className="flex gap-2">
          <Input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="بحث بالاسم أو الإجراء…"
            className="sm:w-60"
            aria-label="بحث في السجل"
          />
          <Button variant="outline" size="icon" onClick={() => void load()} aria-label="تحديث السجل">
            <RefreshCw className="size-4" aria-hidden="true" />
          </Button>
        </div>
      </div>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="flex items-center gap-2 text-base font-bold">
            <ScrollText className="text-primary size-5" aria-hidden="true" />
            العمليات
            <Badge variant="secondary" className="text-[10px]">{filtered.length} سجل</Badge>
          </CardTitle>
        </CardHeader>
        <CardContent>
          {loading && !rows ? (
            <LoadingRows rows={4} />
          ) : filtered.length === 0 ? (
            <EmptyState title="لا توجد سجلات" sub="تظهر هنا العمليات الحساسة فور حدوثها" icon={ShieldCheck} />
          ) : (
            <div className="max-h-[70vh] overflow-auto" dir="rtl">
              <Table>
                <TableHeader className="sticky top-0 z-10 bg-card">
                  <TableRow>
                    <TableHead className="text-right">الوقت</TableHead>
                    <TableHead className="text-right">الفاعل</TableHead>
                    <TableHead className="text-right">الإجراء</TableHead>
                    <TableHead className="text-right">الكيان</TableHead>
                    <TableHead className="text-right">قبل ← بعد</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filtered.map((r) => (
                    <TableRow key={r.id}>
                      <TableCell className="whitespace-nowrap text-xs">
                        <p className="font-bold tabular-nums">{formatArabicDate(r.createdAt)}</p>
                        <p className="text-muted-foreground text-[10px]">{timeAgoArSafe(r.createdAt)}</p>
                      </TableCell>
                      <TableCell className="text-xs">
                        <p className="font-bold">{r.actorName}</p>
                        <Badge variant="secondary" className="mt-0.5 text-[10px]">
                          {roleLabel(r.actorRole)}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <Badge
                          variant="outline"
                          className={
                            r.action.includes("REJECT") || r.action.includes("CANCEL")
                              ? "border-red-200 bg-red-50 text-red-700 dark:border-red-900 dark:bg-red-500/10"
                              : r.action.includes("PRICE")
                                ? "border-amber-200 bg-amber-50 text-amber-800 dark:border-amber-900 dark:bg-amber-500/10"
                                : "border-emerald-200 bg-emerald-50 text-emerald-800 dark:border-emerald-900 dark:bg-emerald-500/10"
                          }
                        >
                          {ACTION_LABELS[r.action] ?? r.action}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-xs">
                        <p className="font-bold">{ENTITY_LABELS[r.entityType] ?? r.entityType}</p>
                        <p className="text-muted-foreground max-w-28 truncate font-mono text-[10px]" dir="ltr" title={r.entityId}>
                          {r.entityId}
                        </p>
                      </TableCell>
                      <TableCell>
                        <div className="flex max-w-72 items-center gap-1.5" dir="ltr">
                          <code
                            className="bg-muted block max-w-32 truncate rounded px-1.5 py-0.5 font-mono text-[10px]"
                            title={shortJson(r.before)}
                          >
                            {shortJson(r.before)}
                          </code>
                          <ArrowLeft className="text-muted-foreground size-3 shrink-0" aria-hidden="true" />
                          <code
                            className="bg-primary/10 text-primary block max-w-32 truncate rounded px-1.5 py-0.5 font-mono text-[10px]"
                            title={shortJson(r.after)}
                          >
                            {shortJson(r.after)}
                          </code>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
