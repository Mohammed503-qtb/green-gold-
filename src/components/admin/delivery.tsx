"use client";

// ============================================================
// GREEN GOLD | إدارة التوصيل
// مهام حسب الحالة + تعيين سائق + تقدم + تسليم برمز OTP + واتساب
// ============================================================

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Truck,
  User,
  MapPin,
  Phone,
  MessageCircle,
  KeyRound,
  Copy,
  CheckCircle2,
  XCircle,
  PackageCheck,
  Navigation,
  Loader2,
  RefreshCw,
  Clock,
  AlertTriangle,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { toast } from "@/hooks/use-toast";
import { cn } from "@/lib/utils";
import { PinInput } from "./pin-input";
import {
  DELIVERY_STATUSES,
  PAYMENT_STATUSES,
  PAYMENT_STATUS_STYLE,
  formatArabicDate,
  formatYER,
  type DeliveryStatus,
} from "@/lib/contracts";
import {
  adminApi,
  broadcastAdminRefresh,
  copyText,
  formatNum,
  normalizeDeliveryTasks,
  whatsappUrl,
  type DeliveryTaskDTO,
} from "./api";
import { EmptyState, LoadingRows, useDebounce } from "./bits";
import { timeAgoArSafe } from "./dashboard";

// أنماط شارات حالات التوصيل
const DELIVERY_STATUS_STYLE: Record<DeliveryStatus, string> = {
  WAITING: "bg-stone-100 text-stone-700 border-stone-200",
  ASSIGNED: "bg-amber-100 text-amber-800 border-amber-200",
  PICKED_UP: "bg-teal-100 text-teal-800 border-teal-200",
  OUT_FOR_DELIVERY: "bg-cyan-100 text-cyan-800 border-cyan-200",
  DELIVERED: "bg-emerald-100 text-emerald-800 border-emerald-200",
  FAILED: "bg-red-100 text-red-700 border-red-200",
};

const DEFAULT_DRIVERS = ["فهد", "سالم", "أبو عمر"];

interface DeliveryProps {
  /** لتحديث شارة المهام إن وجدت */
  onRefresh?: () => void;
}

export function Delivery({ onRefresh }: DeliveryProps) {
  const [tasks, setTasks] = useState<DeliveryTaskDTO[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<DeliveryStatus | "ALL">("ALL");

  // تعيين سائق
  const [assignTarget, setAssignTarget] = useState<DeliveryTaskDTO | null>(null);
  const [driverChoice, setDriverChoice] = useState("فهد");
  const [customDriver, setCustomDriver] = useState("");
  const [busy, setBusy] = useState(false);

  // تسليم برمز
  const [otpTarget, setOtpTarget] = useState<DeliveryTaskDTO | null>(null);
  const [otpValue, setOtpValue] = useState("");
  const [otpError, setOtpError] = useState<string | null>(null);

  // تعذر التسليم
  const [failTarget, setFailTarget] = useState<DeliveryTaskDTO | null>(null);
  const [failReason, setFailReason] = useState("");
  const [failError, setFailError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await adminApi.get<unknown>("/api/admin/delivery?status=", { silent: true });
      setTasks(normalizeDeliveryTasks(data));
    } catch {
      setTasks([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const knownDrivers = useMemo(() => {
    const set = new Set<string>(DEFAULT_DRIVERS);
    for (const t of tasks ?? []) {
      if (t.driverName) set.add(t.driverName);
    }
    return Array.from(set);
  }, [tasks]);

  const counts = useMemo(() => {
    const map = new Map<string, number>();
    for (const t of tasks ?? []) map.set(t.status, (map.get(t.status) ?? 0) + 1);
    return map;
  }, [tasks]);

  const filtered = useMemo(
    () => (tasks ?? []).filter((t) => tab === "ALL" || t.status === tab),
    [tasks, tab]
  );

  const runAction = async (task: DeliveryTaskDTO, body: Record<string, unknown>, okMsg: string): Promise<boolean> => {
    setBusy(true);
    try {
      await adminApi.post(`/api/admin/delivery/${task.id}/action`, body);
      toast({ title: okMsg, description: task.orderCode });
      broadcastAdminRefresh();
      onRefresh?.();
      void load();
      return true;
    } catch {
      return false;
    } finally {
      setBusy(false);
    }
  };

  const verifyDelivery = async () => {
    if (!otpTarget) return;
    if (otpValue.length !== 4) {
      setOtpError("أدخل الرمز المكوّن من 4 أرقام");
      return;
    }
    setBusy(true);
    setOtpError(null);
    try {
      const res = await adminApi.post<{ ok?: boolean; error?: string }>(
        `/api/admin/delivery/${otpTarget.id}/action`,
        { action: "delivered", otp: otpValue },
        { silent: true }
      );
      if (res && typeof res === "object" && "error" in res && res.error) {
        setOtpError(res.error);
        return;
      }
      toast({
        title: "تم التسليم بنجاح ✅",
        description: `${otpTarget.orderCode} — تحقق من الرمز وسُجّل التسليم`,
      });
      setOtpTarget(null);
      setOtpValue("");
      broadcastAdminRefresh();
      onRefresh?.();
      void load();
    } catch (e) {
      const msg = e instanceof Error ? e.message : "رمز غير صحيح";
      setOtpError(msg);
    } finally {
      setBusy(false);
    }
  };

  const tabKeys = Object.keys(DELIVERY_STATUSES) as DeliveryStatus[];

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h2 className="text-lg font-extrabold">مهام التوصيل</h2>
          <p className="text-muted-foreground text-xs">
            لا يكتمل التسليم إلا برمز العميل (OTP) — الرمز يظهر للمهمة بعد الخروج للتوصيل.
          </p>
        </div>
        <Button variant="outline" size="icon" onClick={() => void load()} aria-label="تحديث المهام">
          <RefreshCw className="size-4" aria-hidden="true" />
        </Button>
      </div>

      <Tabs value={tab} onValueChange={(v) => setTab(v as DeliveryStatus | "ALL")}>
        <TabsList className="h-auto w-full max-w-full flex-wrap justify-start gap-1 bg-muted/60 p-1 md:h-auto">
          <TabsTrigger value="ALL" className="gap-1.5 text-xs">
            الكل
            <Badge variant="secondary" className="h-4 px-1 text-[10px] tabular-nums">
              {formatNum(tasks?.length ?? 0)}
            </Badge>
          </TabsTrigger>
          {tabKeys.map((k) => (
            <TabsTrigger key={k} value={k} className="gap-1.5 text-xs">
              {DELIVERY_STATUSES[k]}
              {counts.get(k) ? (
                <Badge variant="secondary" className="h-4 px-1 text-[10px] tabular-nums">
                  {formatNum(counts.get(k) ?? 0)}
                </Badge>
              ) : null}
            </TabsTrigger>
          ))}
        </TabsList>
      </Tabs>

      {loading && !tasks ? (
        <LoadingRows rows={3} />
      ) : filtered.length === 0 ? (
        <EmptyState title="لا توجد مهام توصيل مطابقة" icon={Truck} sub="تظهر المهام تلقائيًا عند خروج الطلبات للتوصيل" />
      ) : (
        <ul className="grid max-h-[64vh] gap-3 overflow-y-auto pl-1 lg:grid-cols-2" aria-label="قائمة مهام التوصيل">
          {filtered.map((t) => {
            const paid = t.paymentStatus === "PAID";
            return (
              <li key={t.id} className="space-y-3 rounded-xl border p-4 shadow-sm">
                {/* رأس المهمة */}
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-mono text-sm font-extrabold" dir="ltr">{t.orderCode}</span>
                  <Badge variant="outline" className={DELIVERY_STATUS_STYLE[t.status] ?? ""}>
                    {DELIVERY_STATUSES[t.status] ?? t.status}
                  </Badge>
                  <Badge
                    variant="outline"
                    className={
                      paid
                        ? "bg-emerald-100 text-emerald-800 border-emerald-200"
                        : t.paymentStatus && t.paymentStatus in PAYMENT_STATUSES && t.paymentStatus !== "UNPAID"
                          ? PAYMENT_STATUS_STYLE[t.paymentStatus as keyof typeof PAYMENT_STATUS_STYLE]
                          : "bg-amber-100 text-amber-800 border-amber-200"
                    }
                  >
                    {paid ? "مدفوع ✅" : t.paymentStatus === "PENDING_VERIFICATION" ? "بانتظار تحقق الدفع" : "الدفع عند الاستلام"}
                  </Badge>
                  <span className="text-muted-foreground ms-auto text-[11px]">
                    {t.createdAt ? timeAgoArSafe(t.createdAt) : ""}
                  </span>
                </div>

                {/* العميل والعنوان */}
                <div className="space-y-1.5 text-xs">
                  <p className="flex items-center gap-1.5 font-bold">
                    <User className="text-muted-foreground size-3.5" aria-hidden="true" />
                    {t.customerName}
                    <span className="text-muted-foreground font-mono font-normal" dir="ltr">{t.phone}</span>
                  </p>
                  <p className="text-muted-foreground flex items-start gap-1.5 leading-relaxed">
                    <MapPin className="mt-0.5 size-3.5 shrink-0" aria-hidden="true" />
                    {t.zoneName ? `${t.zoneName} — ` : ""}
                    {t.addressText || "لا يوجد عنوان"}
                  </p>
                  <p className="flex items-center justify-between">
                    <span className="text-muted-foreground">الإجمالي</span>
                    <span className="text-primary text-sm font-extrabold">{formatYER(t.total)}</span>
                  </p>
                </div>

                {/* السائق */}
                <div className="flex items-center justify-between rounded-lg bg-muted/60 px-3 py-2 text-xs">
                  <span className="text-muted-foreground">السائق</span>
                  <span className={cn("font-bold", !t.driverName && "text-amber-700 dark:text-amber-400")}>
                    {t.driverName ?? "غير معيّن بعد"}
                  </span>
                </div>

                {/* رمز العميل عند الخروج للتوصيل */}
                {t.status === "OUT_FOR_DELIVERY" && t.otp ? (
                  <div className="gold-glow flex items-center justify-between gap-2 rounded-xl border border-amber-300 bg-gradient-to-l from-amber-50 to-yellow-100 p-3 dark:border-amber-800 dark:from-amber-950/50 dark:to-yellow-950/20">
                    <div className="flex items-center gap-2">
                      <KeyRound className="size-5 text-amber-700 dark:text-amber-400" aria-hidden="true" />
                      <div>
                        <p className="text-[11px] font-bold text-amber-900 dark:text-amber-300">رمز العميل للتسليم</p>
                        <p className="text-2xl font-black tracking-[0.3em] text-amber-900 dark:text-amber-300" dir="ltr">
                          {t.otp}
                        </p>
                      </div>
                    </div>
                    <Button
                      variant="outline"
                      size="sm"
                      className="border-amber-400 bg-white/70 font-bold text-amber-900 hover:bg-white dark:bg-transparent dark:text-amber-300"
                      onClick={() => void copyText(t.otp ?? "", "تم نسخ رمز العميل")}
                      aria-label="نسخ رمز العميل"
                    >
                      <Copy className="size-3.5" aria-hidden="true" /> نسخ
                    </Button>
                  </div>
                ) : null}

                {t.status === "DELIVERED" && t.deliveredAt ? (
                  <p className="flex items-center gap-1.5 rounded-lg bg-emerald-50 p-2 text-xs font-bold text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-400">
                    <CheckCircle2 className="size-4" aria-hidden="true" />
                    سُلِّم في {formatArabicDate(t.deliveredAt)}
                  </p>
                ) : null}
                {t.status === "FAILED" && t.failReason ? (
                  <p className="flex items-start gap-1.5 rounded-lg bg-red-50 p-2 text-xs font-semibold text-red-700 dark:bg-red-500/10 dark:text-red-400">
                    <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
                    تعذر التسليم: {t.failReason}
                  </p>
                ) : null}

                {/* أزرار الإجراءات حسب الحالة */}
                <div className="flex flex-wrap gap-2 pt-0.5">
                  {t.status === "WAITING" || t.status === "ASSIGNED" ? (
                    <Button
                      size="sm"
                      variant="secondary"
                      className="h-9 gap-1.5 text-xs font-bold"
                      onClick={() => {
                        setDriverChoice(t.driverName ?? knownDrivers[0] ?? "فهد");
                        setCustomDriver("");
                        setAssignTarget(t);
                      }}
                    >
                      <User className="size-3.5" aria-hidden="true" />
                      {t.driverName ? "تغيير السائق" : "تعيين سائق"}
                    </Button>
                  ) : null}
                  {t.status === "ASSIGNED" ? (
                    <Button
                      size="sm"
                      className="h-9 gap-1.5 text-xs font-bold"
                      disabled={busy}
                      onClick={() => void runAction(t, { action: "picked_up" }, "تم الاستلام من المحل ✓")}
                    >
                      <PackageCheck className="size-3.5" aria-hidden="true" /> تم الاستلام من المحل
                    </Button>
                  ) : null}
                  {t.status === "PICKED_UP" ? (
                    <Button
                      size="sm"
                      className="h-9 gap-1.5 text-xs font-bold"
                      disabled={busy}
                      onClick={() => void runAction(t, { action: "out" }, "خرج للتوصيل 🚚")}
                    >
                      <Navigation className="size-3.5" aria-hidden="true" /> خرج للتوصيل
                    </Button>
                  ) : null}
                  {t.status === "OUT_FOR_DELIVERY" ? (
                    <>
                      <Button
                        size="sm"
                        className="h-9 gap-1.5 bg-emerald-700 text-xs font-bold hover:bg-emerald-800 dark:bg-emerald-600"
                        onClick={() => {
                          setOtpValue("");
                          setOtpError(null);
                          setOtpTarget(t);
                        }}
                      >
                        <KeyRound className="size-3.5" aria-hidden="true" /> تسليم برمز العميل
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        className="h-9 gap-1.5 border-red-200 text-xs font-bold text-red-600 hover:bg-red-50 dark:border-red-900 dark:text-red-400"
                        onClick={() => {
                          setFailReason("");
                          setFailError(null);
                          setFailTarget(t);
                        }}
                      >
                        <XCircle className="size-3.5" aria-hidden="true" /> تعذر التسليم
                      </Button>
                    </>
                  ) : null}
                  {/* واتساب السائق ببيانات الطلب */}
                  {t.status !== "DELIVERED" ? (
                    <Button variant="outline" size="sm" className="h-9 gap-1.5 text-xs font-bold" asChild>
                      <a
                        href={whatsappUrl(
                          null,
                          `🚚 مهمة توصيل — ${t.orderCode}\nالعميل: ${t.customerName} (${t.phone})\nالمنطقة: ${t.zoneName ?? "-"}\nالعنوان: ${t.addressText || "-"}\nالإجمالي: ${formatYER(t.total)} (${paid ? "مدفوع مسبقًا" : "يُحصَّل عند التسليم"})${t.driverName ? `\nالسائق: ${t.driverName}` : ""}`
                        )}
                        target="_blank"
                        rel="noreferrer"
                      >
                        <MessageCircle className="size-3.5" aria-hidden="true" /> إرسال للسائق
                      </a>
                    </Button>
                  ) : null}
                  <Button variant="outline" size="icon" className="size-9" asChild>
                    <a href={`tel:${t.phone}`} aria-label={`اتصال بـ ${t.customerName}`}>
                      <Phone className="size-4" aria-hidden="true" />
                    </a>
                  </Button>
                  <Button variant="outline" size="icon" className="size-9" asChild>
                    <a
                      href={whatsappUrl(t.phone, `مرحبًا ${t.customerName}، معك توصيل طلبك ${t.orderCode} من ذهب أخضر 🌿`)}
                      target="_blank"
                      rel="noreferrer"
                      aria-label={`مراسلة ${t.customerName} واتساب`}
                    >
                      <MessageCircle className="size-4" aria-hidden="true" />
                    </a>
                  </Button>
                </div>
              </li>
            );
          })}
        </ul>
      )}

      {/* Dialog تعيين سائق */}
      <Dialog open={!!assignTarget} onOpenChange={(o) => !o && !busy && setAssignTarget(null)}>
        <DialogContent className="max-w-sm sm:max-w-sm">
          <DialogHeader>
            <DialogTitle>تعيين سائق</DialogTitle>
            <DialogDescription>
              المهمة <span className="font-mono font-bold" dir="ltr">{assignTarget?.orderCode}</span> —{" "}
              {assignTarget?.zoneName ?? "بدون منطقة"}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-2.5">
            <Select value={driverChoice} onValueChange={(v) => setDriverChoice(v)}>
              <SelectTrigger className="w-full" aria-label="اختيار السائق">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {knownDrivers.map((d) => (
                  <SelectItem key={d} value={d}>{d}</SelectItem>
                ))}
                <SelectItem value="__custom">سائق آخر (اكتب الاسم)…</SelectItem>
              </SelectContent>
            </Select>
            {driverChoice === "__custom" ? (
              <Input
                value={customDriver}
                onChange={(e) => setCustomDriver(e.target.value)}
                placeholder="اسم السائق…"
                autoFocus
              />
            ) : null}
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" disabled={busy} onClick={() => setAssignTarget(null)}>
              إلغاء
            </Button>
            <Button
              disabled={
                busy ||
                (driverChoice === "__custom" && customDriver.trim().length < 2)
              }
              onClick={() => {
                if (!assignTarget) return;
                const name = driverChoice === "__custom" ? customDriver.trim() : driverChoice;
                void (async () => {
                  const ok = await runAction(assignTarget, { action: "assign", driverName: name }, `تم تعيين ${name} سائقًا 🚚`);
                  if (ok) setAssignTarget(null);
                })();
              }}
              className="font-bold"
            >
              {busy ? <Loader2 className="size-4 animate-spin" aria-hidden="true" /> : <Truck className="size-4" aria-hidden="true" />}
              تأكيد التعيين
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Dialog التسليم برمز OTP */}
      <Dialog open={!!otpTarget} onOpenChange={(o) => !o && !busy && (setOtpTarget(null), setOtpError(null))}>
        <DialogContent className="max-w-sm sm:max-w-sm">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <KeyRound className="text-amber-600 size-5" aria-hidden="true" />
              رمز تسليم العميل
            </DialogTitle>
            <DialogDescription>
              اطلب من العميل <b>{otpTarget?.customerName}</b> رمز التسليم المكوّن من 4 أرقام للطلب{" "}
              <span className="font-mono" dir="ltr">{otpTarget?.orderCode}</span>
            </DialogDescription>
          </DialogHeader>
          <div className="flex flex-col items-center gap-3 py-1">
            <div>
              <PinInput
                value={otpValue}
                onChange={(v) => {
                  setOtpValue(v);
                  if (otpError) setOtpError(null);
                }}
                autoFocus
                aria-label="رمز تسليم العميل"
                invalid={!!otpError}
                boxClassName="h-12 w-11 text-xl"
              />
            </div>
            {otpError ? (
              <p className="flex items-center gap-1.5 text-sm font-bold text-red-600" role="alert">
                <XCircle className="size-4" aria-hidden="true" />
                {otpError}
              </p>
            ) : (
              <p className="text-muted-foreground flex items-center gap-1.5 text-[11px]">
                <Clock className="size-3.5" aria-hidden="true" />
                في حال عدم تطابق الرمز أعد إدخاله — لا يكتمل التسليم بدونه
              </p>
            )}
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" disabled={busy} onClick={() => setOtpTarget(null)}>
              إلغاء
            </Button>
            <Button
              className="bg-emerald-700 font-bold hover:bg-emerald-800 dark:bg-emerald-600"
              disabled={busy || otpValue.length !== 4}
              onClick={() => void verifyDelivery()}
            >
              {busy ? <Loader2 className="size-4 animate-spin" aria-hidden="true" /> : <CheckCircle2 className="size-4" aria-hidden="true" />}
              تأكيد التسليم
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Dialog تعذر التسليم */}
      <Dialog open={!!failTarget} onOpenChange={(o) => !o && !busy && setFailTarget(null)}>
        <DialogContent className="max-w-sm sm:max-w-sm">
          <DialogHeader>
            <DialogTitle className="text-red-600">تعذر التسليم</DialogTitle>
            <DialogDescription>
              الطلب <span className="font-mono font-bold" dir="ltr">{failTarget?.orderCode}</span> —{" "}
              {failTarget?.customerName}. سجِّل السبب ليتابع الفريق الطلب لاحقًا.
            </DialogDescription>
          </DialogHeader>
          <div>
            <label htmlFor="fail-reason" className="mb-1.5 block text-sm font-bold">
              سبب تعذر التسليم <span className="text-red-600">*</span>
            </label>
            <Textarea
              id="fail-reason"
              value={failReason}
              onChange={(e) => {
                setFailReason(e.target.value);
                if (failError) setFailError(null);
              }}
              placeholder="مثال: العميل لم يرد على الهاتف…"
              rows={3}
              aria-invalid={!!failError}
              className={cn(failError && "border-red-400 focus-visible:ring-red-300")}
            />
            {failError ? (
              <p className="mt-1.5 text-xs font-bold text-red-600" role="alert">
                {failError}
              </p>
            ) : null}
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" disabled={busy} onClick={() => setFailTarget(null)}>
              تراجع
            </Button>
            <Button
              variant="destructive"
              disabled={busy}
              onClick={() => {
                if (!failTarget) return;
                if (failReason.trim().length < 3) {
                  setFailError("السبب إجباري (3 أحرف على الأقل)");
                  return;
                }
                void (async () => {
                  const ok = await runAction(
                    failTarget,
                    { action: "failed", failReason: failReason.trim() },
                    "سُجّل تعذر التسليم"
                  );
                  if (ok) setFailTarget(null);
                })();
              }}
            >
              {busy ? <Loader2 className="size-4 animate-spin" aria-hidden="true" /> : <XCircle className="size-4" aria-hidden="true" />}
              تأكيد تعذر التسليم
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
