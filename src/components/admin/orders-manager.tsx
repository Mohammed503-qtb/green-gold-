"use client";

// ============================================================
// GREEN GOLD | إدارة الطلبات
// Tabs حسب الحالة + بحث + بطاقات + Dialog تفاصيل كامل + إجراءات + OTP
// ============================================================

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Search,
  ClipboardList,
  ChefHat,
  PackageCheck,
  Truck,
  Ban,
  Undo2,
  Copy,
  KeyRound,
  MapPin,
  Phone,
  MessageCircle,
  CreditCard,
  Loader2,
  RefreshCw,
  History,
  ImageIcon,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { cn } from "@/lib/utils";
import { toast } from "@/hooks/use-toast";
import {
  CAN,
  ORDER_STATUSES,
  ORDER_STATUS_STYLE,
  PAYMENT_STATUSES,
  formatArabicDate,
  formatYER,
  type OrderDTO,
  type OrderStatus,
} from "@/lib/contracts";
import {
  adminApi,
  broadcastAdminRefresh,
  copyText,
  formatNum,
  listOf,
  whatsappUrl,
  type StaffSession,
} from "./api";
import {
  EmptyState,
  GradeBadge,
  LoadingRows,
  Money,
  OrderStatusBadge,
  PaymentStatusBadge,
  useDebounce,
} from "./bits";
import { timeAgoArSafe } from "./dashboard";

// ───────── تعريف الإجراءات ─────────

type OrderAction = "start_preparing" | "ready" | "out_for_delivery" | "cancel" | "refund";

interface ActionDef {
  label: string;
  icon: typeof ChefHat;
  btnClass: string;
  title: string;
  desc: string;
  needNote: boolean;
}

const ACTION_DEFS: Record<OrderAction, ActionDef> = {
  start_preparing: {
    label: "بدء التجهيز",
    icon: ChefHat,
    btnClass: "",
    title: "بدء تجهيز الطلب؟",
    desc: "سيبدأ تجهيز أصناف الطلب الآن.",
    needNote: false,
  },
  ready: {
    label: "جاهز للتوصيل",
    icon: PackageCheck,
    btnClass: "",
    title: "تأكيد جهوزية الطلب للتوصيل؟",
    desc: "سيصبح الطلب جاهزًا للخروج مع السائق.",
    needNote: false,
  },
  out_for_delivery: {
    label: "خرج للتوصيل",
    icon: Truck,
    btnClass: "",
    title: "إخراج الطلب للتوصيل؟",
    desc: "سيتم توليد رمز تسليم (OTP) من 4 أرقام يجب أخذه من العميل عند التسليم.",
    needNote: false,
  },
  cancel: {
    label: "إلغاء",
    icon: Ban,
    btnClass: "border-red-200 text-red-600 hover:bg-red-50 hover:text-red-700 dark:border-red-900 dark:text-red-400",
    title: "إلغاء هذا الطلب؟",
    desc: "سيتم تحرير الكميات المحجوزة لهذا الطلب فورًا.",
    needNote: true,
  },
  refund: {
    label: "استرجاع",
    icon: Undo2,
    btnClass: "border-orange-200 text-orange-700 hover:bg-orange-50 hover:text-orange-800 dark:border-orange-900 dark:text-orange-400",
    title: "استرجاع هذا الطلب؟",
    desc: "سيُسجَّل الطلب كمسترجع ويُعاد المبلغ للعميل (يظهر في سجل التدقيق).",
    needNote: true,
  },
};

function availableActions(o: OrderDTO): OrderAction[] {
  const acts: OrderAction[] = [];
  const s = o.status;
  if (s === "CONFIRMED") acts.push("start_preparing");
  if (s === "PREPARING") acts.push("ready");
  if (s === "READY_FOR_DELIVERY") acts.push("out_for_delivery");
  if (["PENDING_PAYMENT", "PAYMENT_SUBMITTED", "CONFIRMED", "PREPARING", "READY_FOR_DELIVERY"].includes(s)) {
    acts.push("cancel");
  }
  if (o.payment?.status === "PAID" && s !== "REFUNDED" && s !== "CANCELLED") acts.push("refund");
  return acts;
}

function allowed(action: OrderAction, role: string): boolean {
  if (action === "refund") return (CAN.verifyPayment as readonly string[]).includes(role);
  return (CAN.advanceOrder as readonly string[]).includes(role);
}

const CANCELLABLE_FOR_CANCEL_ICON = Ban;

// ───────── المكوّن ─────────

interface OrdersManagerProps {
  session: StaffSession;
  initialStatus?: OrderStatus | "ALL";
}

export function OrdersManager({ session, initialStatus = "ALL" }: OrdersManagerProps) {
  const [tab, setTab] = useState<OrderStatus | "ALL">(initialStatus);
  const [q, setQ] = useState("");
  const debouncedQ = useDebounce(q, 400);
  const [orders, setOrders] = useState<OrderDTO[] | null>(null);
  const [loading, setLoading] = useState(true);

  // تفاصيل الطلب
  const [detail, setDetail] = useState<OrderDTO | null>(null);
  const [detailOpen, setDetailOpen] = useState(false);
  const [detailLoading, setDetailLoading] = useState(false);

  // تأكيد الإجراء
  const [confirmAction, setConfirmAction] = useState<{ order: OrderDTO; action: OrderAction } | null>(null);
  const [note, setNote] = useState("");
  const [acting, setActing] = useState(false);

  // رمز التسليم OTP
  const [otpInfo, setOtpInfo] = useState<{ code: string; orderCode: string } | null>(null);

  // صورة الإثبات مكبرة
  const [proofUrl, setProofUrl] = useState<string | null>(null);

  useEffect(() => {
    setTab(initialStatus);
  }, [initialStatus]);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await adminApi.get<unknown>(
        `/api/admin/orders?status=&q=${encodeURIComponent(debouncedQ)}`,
        { silent: true }
      );
      setOrders(listOf<OrderDTO>(data, "orders"));
    } catch {
      setOrders([]);
    } finally {
      setLoading(false);
    }
  }, [debouncedQ]);

  useEffect(() => {
    void load();
  }, [load]);

  const counts = useMemo(() => {
    const map = new Map<string, number>();
    for (const o of orders ?? []) map.set(o.status, (map.get(o.status) ?? 0) + 1);
    return map;
  }, [orders]);

  const filtered = useMemo(
    () => (orders ?? []).filter((o) => tab === "ALL" || o.status === tab),
    [orders, tab]
  );

  const openDetail = async (o: OrderDTO) => {
    setDetail(o); // عرض فوري ببيانات القائمة
    setDetailOpen(true);
    setDetailLoading(true);
    try {
      const data = await adminApi.get<unknown>(`/api/admin/orders/${o.id}`, { silent: true });
      const full = (data as { order?: OrderDTO })?.order ?? o;
      setDetail(full);
    } catch {
      // نبقى على بيانات القائمة
    } finally {
      setDetailLoading(false);
    }
  };

  const runAction = async () => {
    if (!confirmAction) return;
    const { order, action } = confirmAction;
    setActing(true);
    try {
      const resp = await adminApi.post<{ order?: OrderDTO; otp?: string }>(
        `/api/admin/orders/${order.id}/action`,
        {
          action,
          note: note.trim() || undefined,
        }
      );
      toast({ title: "تم تنفيذ الإجراء ✓", description: `${ACTION_DEFS[action].label} — ${order.orderCode}` });

      // رمز التسليم عند الخروج للتوصيل
      if (action === "out_for_delivery") {
        const otp = resp?.otp ?? resp?.order?.delivery?.otp ?? null;
        if (otp) {
          setOtpInfo({ code: otp, orderCode: order.orderCode });
        } else {
          // جلب التفاصيل للعثور على الرمز
          try {
            const data = await adminApi.get<{ order?: OrderDTO }>(`/api/admin/orders/${order.id}`, {
              silent: true,
            });
            const otp2 = data?.order?.delivery?.otp ?? null;
            if (otp2) setOtpInfo({ code: otp2, orderCode: order.orderCode });
          } catch {
            /* لا شيء */
          }
        }
      }

      setConfirmAction(null);
      setNote("");
      broadcastAdminRefresh();
      void load();
      if (detailOpen && detail?.id === order.id) {
        try {
          const data = await adminApi.get<{ order?: OrderDTO }>(`/api/admin/orders/${order.id}`, {
            silent: true,
          });
          if (data?.order) setDetail(data.order);
        } catch {
          /* لا شيء */
        }
      }
    } catch {
      // toast عربية من api.ts
    } finally {
      setActing(false);
    }
  };

  const tabKeys: (keyof typeof ORDER_STATUSES)[] = Object.keys(ORDER_STATUSES) as (keyof typeof ORDER_STATUSES)[];

  return (
    <div className="space-y-4">
      {/* البحث */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <Search
            className="text-muted-foreground absolute top-1/2 right-3 size-4 -translate-y-1/2"
            aria-hidden="true"
          />
          <Input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="بحث برقم الطلب أو اسم العميل أو الهاتف أو رقم العملية…"
            className="pr-9"
            aria-label="بحث في الطلبات"
          />
        </div>
        <Button variant="outline" size="icon" onClick={() => void load()} aria-label="تحديث القائمة">
          <RefreshCw className="size-4" aria-hidden="true" />
        </Button>
      </div>

      {/* Tabs الحالات */}
      <Tabs value={tab} onValueChange={(v) => setTab(v as OrderStatus | "ALL")}>
        <TabsList className="h-auto w-full max-w-full flex-wrap justify-start gap-1 bg-muted/60 p-1 md:h-auto">
          <TabsTrigger value="ALL" className="gap-1.5 text-xs">
            الكل
            <Badge variant="secondary" className="h-4 min-w-4 px-1 text-[10px] tabular-nums">
              {formatNum(orders?.length ?? 0)}
            </Badge>
          </TabsTrigger>
          {tabKeys.map((k) => (
            <TabsTrigger key={k} value={k} className="gap-1.5 text-xs">
              {ORDER_STATUSES[k]}
              {counts.get(k) ? (
                <Badge variant="secondary" className="h-4 min-w-4 px-1 text-[10px] tabular-nums">
                  {formatNum(counts.get(k) ?? 0)}
                </Badge>
              ) : null}
            </TabsTrigger>
          ))}
        </TabsList>
      </Tabs>

      {/* القائمة */}
      {loading && !orders ? (
        <LoadingRows rows={4} />
      ) : filtered.length === 0 ? (
        <EmptyState
          title="لا توجد طلبات مطابقة"
          sub={tab === "ALL" ? "جرّب تغيير كلمة البحث" : `لا توجد طلبات بحالة «${ORDER_STATUSES[tab as OrderStatus] ?? tab}»`}
          icon={ClipboardList}
        />
      ) : (
        <ul className="max-h-[62vh] space-y-2.5 overflow-y-auto pl-1" aria-label="قائمة الطلبات">
          {filtered.map((o) => (
            <li key={o.id}>
              <button
                onClick={() => void openDetail(o)}
                className="hover:bg-accent/50 w-full rounded-xl border p-3.5 text-start shadow-sm transition hover:shadow"
                aria-label={`تفاصيل الطلب ${o.orderCode}`}
              >
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-mono text-sm font-extrabold" dir="ltr">
                    {o.orderCode}
                  </span>
                  <OrderStatusBadge status={o.status} />
                  <PaymentStatusBadge status={o.payment?.status} />
                  {o.reviewed ? <Badge variant="outline" className="border-amber-200 bg-amber-50 text-amber-800 dark:bg-amber-500/10">⭐ مُقيَّم</Badge> : null}
                  <span className="text-muted-foreground ms-auto text-[11px]">{timeAgoArSafe(o.createdAt)}</span>
                </div>
                <div className="mt-2 flex flex-wrap items-center justify-between gap-2">
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-bold">
                      {o.customerName} <span className="text-muted-foreground font-normal" dir="ltr">{o.phone}</span>
                    </p>
                    <p className="text-muted-foreground truncate text-xs">
                      {o.items.length > 0
                        ? `${o.items[0].productName} × ${formatNum(o.items[0].qty)}${o.items.length > 1 ? ` +${formatNum(o.items.length - 1)} أصناف` : ""}`
                        : "—"}
                      {" • "}
                      {o.zoneName ?? "بدون منطقة"}
                    </p>
                  </div>
                  <Money amount={o.total} className="text-primary text-base" />
                </div>
                {/* أزرار إجراءات سريعة */}
                {availableActions(o).filter((a) => allowed(a, session.role)).length > 0 ? (
                  <div className="mt-2.5 flex flex-wrap gap-2" onClick={(e) => e.stopPropagation()}>
                    {availableActions(o)
                      .filter((a) => allowed(a, session.role))
                      .map((a) => {
                        const def = ACTION_DEFS[a];
                        const Icon = def.icon;
                        return (
                          <span
                            key={a}
                            role="button"
                            tabIndex={0}
                            onClick={(e) => {
                              e.stopPropagation();
                              setNote("");
                              setConfirmAction({ order: o, action: a });
                            }}
                            onKeyDown={(e) => {
                              if (e.key === "Enter" || e.key === " ") {
                                e.stopPropagation();
                                setNote("");
                                setConfirmAction({ order: o, action: a });
                              }
                            }}
                            className={cn(
                              "inline-flex cursor-pointer items-center gap-1.5 rounded-lg border px-2.5 py-1.5 text-xs font-bold transition hover:shadow-sm",
                              def.btnClass ||
                                "border-primary/30 bg-primary/5 text-primary hover:bg-primary/10"
                            )}
                          >
                            <Icon className="size-3.5" aria-hidden="true" />
                            {def.label}
                          </span>
                        );
                      })}
                  </div>
                ) : null}
              </button>
            </li>
          ))}
        </ul>
      )}

      {/* Dialog التفاصيل الكاملة */}
      <Dialog open={detailOpen} onOpenChange={setDetailOpen}>
        <DialogContent className="max-h-[90vh] max-w-3xl overflow-y-auto sm:max-w-3xl">
          {detail ? (
            <>
              <DialogHeader>
                <div className="flex flex-wrap items-center gap-2">
                  <DialogTitle className="font-mono text-lg" dir="ltr">
                    {detail.orderCode}
                  </DialogTitle>
                  <OrderStatusBadge status={detail.status} />
                  <PaymentStatusBadge status={detail.payment?.status} />
                  {detailLoading ? <Loader2 className="text-muted-foreground size-4 animate-spin" aria-hidden="true" /> : null}
                </div>
                <DialogDescription className="text-xs">
                  أُنشئ الطلب {formatArabicDate(detail.createdAt)} • {timeAgoArSafe(detail.createdAt)}
                </DialogDescription>
              </DialogHeader>

              <div className="space-y-4">
                {/* العميل */}
                <section className="rounded-xl border p-3" aria-label="بيانات العميل">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div>
                      <p className="text-sm font-bold">{detail.customerName}</p>
                      <p className="font-mono text-xs" dir="ltr">{detail.phone}</p>
                    </div>
                    <div className="flex gap-1.5">
                      <Button variant="outline" size="icon" className="size-8" asChild>
                        <a href={`tel:${detail.phone}`} aria-label="اتصال بالعميل">
                          <Phone className="size-4" aria-hidden="true" />
                        </a>
                      </Button>
                      <Button variant="outline" size="icon" className="size-8" asChild>
                        <a
                          href={whatsappUrl(
                            detail.phone,
                            `مرحبًا ${detail.customerName}، بخصوص طلبك ${detail.orderCode} من ذهب أخضر 🌿`
                          )}
                          target="_blank"
                          rel="noreferrer"
                          aria-label="مراسلة العميل واتساب"
                        >
                          <MessageCircle className="size-4" aria-hidden="true" />
                        </a>
                      </Button>
                    </div>
                  </div>
                  <Separator className="my-2.5" />
                  <p className="text-muted-foreground flex items-start gap-1.5 text-xs leading-relaxed">
                    <MapPin className="mt-0.5 size-3.5 shrink-0" aria-hidden="true" />
                    <span>
                      {detail.zoneName ? `${detail.zoneName} — ` : ""}
                      {detail.addressText}
                      {detail.note ? <span className="block">📝 ملاحظة العميل: {detail.note}</span> : null}
                    </span>
                  </p>
                </section>

                {/* الأصناف */}
                <section aria-label="أصناف الطلب">
                  <h3 className="mb-2 text-sm font-bold">الأصناف</h3>
                  <ul className="space-y-2">
                    {detail.items.map((it) => (
                      <li key={it.id} className="flex items-center gap-3 rounded-xl border p-2.5">
                        {it.mainImage ? (
                          <img
                            src={it.mainImage}
                            alt={it.productName}
                            loading="lazy"
                            className="size-12 shrink-0 rounded-lg border object-cover"
                          />
                        ) : (
                          <div className="bg-muted flex size-12 shrink-0 items-center justify-center rounded-lg border">
                            <ImageIcon className="text-muted-foreground size-5" aria-hidden="true" />
                          </div>
                        )}
                        <div className="min-w-0 flex-1">
                          <div className="flex flex-wrap items-center gap-1.5">
                            <p className="text-sm font-bold">{it.productName}</p>
                            <GradeBadge grade={it.grade} />
                            <span className="text-muted-foreground font-mono text-[10px]" dir="ltr">{it.batchCode}</span>
                          </div>
                          <p className="text-muted-foreground text-xs">
                            {formatYER(it.unitPrice)} × {formatNum(it.qty)} ={" "}
                            <span className="text-foreground font-bold">{formatYER(it.lineTotal)}</span>
                          </p>
                        </div>
                      </li>
                    ))}
                  </ul>
                  <div className="mt-2.5 space-y-1 rounded-xl bg-muted/60 p-3 text-sm">
                    <div className="text-muted-foreground flex justify-between">
                      <span>الأصناف</span>
                      <span className="tabular-nums">{formatYER(detail.itemsTotal)}</span>
                    </div>
                    <div className="text-muted-foreground flex justify-between">
                      <span>التوصيل {detail.zoneName ? `(${detail.zoneName})` : ""}</span>
                      <span className="tabular-nums">{formatYER(detail.deliveryFee)}</span>
                    </div>
                    {detail.discount > 0 ? (
                      <div className="flex justify-between text-orange-600">
                        <span>خصم</span>
                        <span className="tabular-nums">- {formatYER(detail.discount)}</span>
                      </div>
                    ) : null}
                    <Separator className="my-1" />
                    <div className="flex justify-between text-base font-extrabold">
                      <span>الإجمالي</span>
                      <Money amount={detail.total} className="text-primary" />
                    </div>
                  </div>
                </section>

                {/* الدفع */}
                {detail.payment ? (
                  <section className="rounded-xl border p-3" aria-label="بيانات الدفع">
                    <h3 className="mb-2 flex items-center gap-1.5 text-sm font-bold">
                      <CreditCard className="size-4" aria-hidden="true" /> الدفع
                    </h3>
                    <div className="grid grid-cols-2 gap-x-3 gap-y-1.5 text-xs sm:grid-cols-3">
                      <p>
                        <span className="text-muted-foreground">الطريقة: </span>
                        {detail.payment.methodSnapshot?.name ?? "—"}
                      </p>
                      <p>
                        <span className="text-muted-foreground">الحالة: </span>
                        {PAYMENT_STATUSES[detail.payment.status]}
                      </p>
                      <p>
                        <span className="text-muted-foreground">المبلغ: </span>
                        {formatYER(detail.payment.amount)}
                      </p>
                      {detail.payment.transactionRef ? (
                        <p className="col-span-2">
                          <span className="text-muted-foreground">رقم العملية: </span>
                          <span className="font-mono" dir="ltr">{detail.payment.transactionRef}</span>
                        </p>
                      ) : null}
                      {detail.payment.submittedAt ? (
                        <p>
                          <span className="text-muted-foreground">أُرسل: </span>
                          {formatArabicDate(detail.payment.submittedAt)}
                        </p>
                      ) : null}
                      {detail.payment.rejectReason ? (
                        <p className="col-span-2 text-red-600">سبب الرفض: {detail.payment.rejectReason}</p>
                      ) : null}
                    </div>
                    {detail.payment.proofUrl ? (
                      <button
                        onClick={() => setProofUrl(detail.payment?.proofUrl ?? null)}
                        className="mt-2.5 block overflow-hidden rounded-lg border transition hover:shadow"
                        aria-label="عرض صورة إثبات الدفع مكبرة"
                      >
                        <img
                          src={detail.payment.proofUrl}
                          alt={`إثبات دفع الطلب ${detail.orderCode}`}
                          loading="lazy"
                          className="h-24 object-cover"
                        />
                      </button>
                    ) : null}
                  </section>
                ) : null}

                {/* التوصيل */}
                {detail.delivery ? (
                  <section className="rounded-xl border p-3" aria-label="حالة التوصيل">
                    <h3 className="mb-1.5 flex items-center gap-1.5 text-sm font-bold">
                      <Truck className="size-4" aria-hidden="true" /> التوصيل
                    </h3>
                    <p className="text-xs">
                      <span className="text-muted-foreground">الحالة: </span>
                      {detail.delivery.status === "DELIVERED" ? "تم التسليم" : detail.delivery.status}
                      {detail.delivery.driverName ? ` • السائق: ${detail.delivery.driverName}` : ""}
                      {detail.delivery.otp ? (
                        <>
                          {" • "}
                          <span className="font-mono font-bold text-amber-700 dark:text-amber-400" dir="ltr">
                            OTP: {detail.delivery.otp}
                          </span>
                        </>
                      ) : null}
                    </p>
                  </section>
                ) : null}

                {/* سجل الحالات */}
                <section aria-label="سجل حالات الطلب">
                  <h3 className="mb-2 flex items-center gap-1.5 text-sm font-bold">
                    <History className="size-4" aria-hidden="true" /> سجل الحالات
                  </h3>
                  <ol className="max-h-56 space-y-2 overflow-y-auto border-r-2 border-primary/20 pr-3">
                    {[...detail.history].reverse().map((h, i) => (
                      <li key={i} className="relative">
                        <span
                          className={cn(
                            "absolute -right-[19px] top-1.5 size-2.5 rounded-full",
                            i === 0 ? "bg-primary pulse-dot" : "bg-primary/30"
                          )}
                          aria-hidden="true"
                        />
                        <p className="text-xs font-bold">
                          {h.fromStatus
                            ? `${ORDER_STATUSES[h.fromStatus as OrderStatus] ?? h.fromStatus} ← ${ORDER_STATUSES[h.toStatus as OrderStatus] ?? h.toStatus}`
                            : `أنشئ الطلب (${ORDER_STATUSES[h.toStatus as OrderStatus] ?? h.toStatus})`}
                        </p>
                        <p className="text-muted-foreground text-[11px]">
                          {h.actor} • {formatArabicDate(h.createdAt)}
                          {h.note ? ` • ${h.note}` : ""}
                        </p>
                      </li>
                    ))}
                  </ol>
                </section>

                {/* إجراءات داخل التفاصيل */}
                {detail.status === "PAYMENT_SUBMITTED" ? (
                  <p className="rounded-xl border border-amber-200 bg-amber-50 p-3 text-xs font-semibold text-amber-800 dark:border-amber-900 dark:bg-amber-500/10 dark:text-amber-400">
                    ⏳ هذا الطلب ينتظر التحقق من الدفع — عالجه من قسم «الدفعات».
                  </p>
                ) : null}
                <div className="flex flex-wrap gap-2">
                  {availableActions(detail)
                    .filter((a) => allowed(a, session.role))
                    .map((a) => {
                      const def = ACTION_DEFS[a];
                      const Icon = def.icon === Ban ? CANCELLABLE_FOR_CANCEL_ICON : def.icon;
                      return (
                        <Button
                          key={a}
                          variant={a === "cancel" ? "destructive" : a === "refund" ? "outline" : "default"}
                          className={cn(a === "refund" && "border-orange-300 text-orange-700 hover:bg-orange-50 dark:border-orange-900 dark:text-orange-400")}
                          onClick={() => {
                            setNote("");
                            setConfirmAction({ order: detail, action: a });
                          }}
                        >
                          <Icon className="size-4" aria-hidden="true" />
                          {def.label}
                        </Button>
                      );
                    })}
                </div>
              </div>
            </>
          ) : null}
        </DialogContent>
      </Dialog>

      {/* تأكيد الإجراء */}
      <AlertDialog open={!!confirmAction} onOpenChange={(o) => !o && setConfirmAction(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>
              {confirmAction ? ACTION_DEFS[confirmAction.action].title : ""}
            </AlertDialogTitle>
            <AlertDialogDescription asChild>
              <div>
                <p>
                  {confirmAction ? ACTION_DEFS[confirmAction.action].desc : ""} الطلب{" "}
                  <span className="font-mono font-bold" dir="ltr">
                    {confirmAction?.order.orderCode}
                  </span>{" "}
                  — {confirmAction?.order.customerName}.
                </p>
                {confirmAction && ACTION_DEFS[confirmAction.action].needNote ? (
                  <div className="mt-3">
                    <label htmlFor="action-note" className="mb-1 block text-xs font-bold">
                      ملاحظة {confirmAction.action === "cancel" ? "(اختيارية)" : "(اختيارية)"}
                    </label>
                    <Textarea
                      id="action-note"
                      value={note}
                      onChange={(e) => setNote(e.target.value)}
                      placeholder="سبب أو توضيح يظهر في سجل الحالات…"
                      rows={2}
                    />
                  </div>
                ) : null}
              </div>
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={acting}>تراجع</AlertDialogCancel>
            <AlertDialogAction
              disabled={acting}
              onClick={(e) => {
                e.preventDefault(); // نبقي الحوار مفتوحًا حتى تنتهي العملية
                void runAction();
              }}
              className={cn(confirmAction?.action === "cancel" && "bg-destructive text-white hover:bg-destructive/90")}
            >
              {acting ? <Loader2 className="size-4 animate-spin" aria-hidden="true" /> : null}
              تأكيد
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* رمز تسليم العميل (OTP) */}
      <Dialog open={!!otpInfo} onOpenChange={(o) => !o && setOtpInfo(null)}>
        <DialogContent className="gold-glow max-w-sm border-amber-300 bg-gradient-to-b from-amber-50 to-yellow-100 dark:from-amber-950/60 dark:to-yellow-950/30 sm:max-w-sm">
          <DialogHeader>
            <DialogTitle className="flex items-center justify-center gap-2 text-center text-base font-extrabold text-amber-900 dark:text-amber-300">
              <KeyRound className="size-5" aria-hidden="true" />
              رمز تسليم العميل
            </DialogTitle>
            <DialogDescription className="text-center text-xs text-amber-800/80 dark:text-amber-400/80">
              الطلب <span className="font-mono font-bold" dir="ltr">{otpInfo?.orderCode}</span> خرج للتوصيل — اطلب من العميل هذا الرمز عند الاستلام:
            </DialogDescription>
          </DialogHeader>
          <div className="flex flex-col items-center gap-3 py-2">
            <p className="text-5xl font-black tracking-[0.4em] text-amber-900 dark:text-amber-300" dir="ltr">
              {otpInfo?.code}
            </p>
            <Button
              variant="outline"
              className="border-amber-400 bg-white/70 text-amber-900 hover:bg-white dark:bg-transparent dark:text-amber-300"
              onClick={() => otpInfo && void copyText(otpInfo.code, "تم نسخ رمز التسليم")}
            >
              <Copy className="size-4" aria-hidden="true" /> نسخ الرمز
            </Button>
            <p className="text-center text-[11px] leading-relaxed text-amber-800/70 dark:text-amber-400/70">
              لن يكتمل التسليم إلا بإدخال هذا الرمز في قسم التوصيل.
            </p>
          </div>
        </DialogContent>
      </Dialog>

      {/* تكبير صورة الإثبات */}
      <Dialog open={!!proofUrl} onOpenChange={(o) => !o && setProofUrl(null)}>
        <DialogContent className="max-w-lg sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>إثبات الدفع</DialogTitle>
          </DialogHeader>
          {proofUrl ? (
            <img
              src={proofUrl}
              alt="صورة إثبات الدفع مكبرة"
              className="max-h-[70vh] w-full rounded-xl border object-contain bg-muted"
            />
          ) : null}
        </DialogContent>
      </Dialog>
    </div>
  );
}
