"use client";

// ============================================================
// GREEN GOLD | متتبع الطلب — شريط خطوات + دفع + تقييم + واتساب
// ============================================================
import { useCallback, useEffect, useRef, useState } from "react";
import {
  Camera,
  ChevronDown,
  Copy,
  Loader2,
  MessageCircle,
  RefreshCw,
  Send,
} from "lucide-react";

import { fetchOrderByCode, submitPayment, submitReview } from "@/components/shop/api";
import {
  compressImageToDataUrl,
  copyText,
  orderWaMessage,
  SMILEY_RATING,
  waLink,
} from "@/components/shop/utils";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from "@/components/ui/collapsible";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import { Textarea } from "@/components/ui/textarea";
import { toast } from "@/hooks/use-toast";
import {
  CUSTOMER_TRACK_STEPS,
  DELIVERY_STATUSES,
  ORDER_FLOW,
  ORDER_STATUSES,
  ORDER_STATUS_STYLE,
  PAYMENT_STATUSES,
  PAYMENT_STATUS_STYLE,
  PAYMENT_TYPES,
  SMILEYS,
  formatArabicDate,
  formatYER,
  timeAgoAr,
  type OrderDTO,
  type OrderStatus,
  type PaymentMethodDTO,
  type Smiley,
} from "@/lib/contracts";
import { cn } from "@/lib/utils";

export interface OrderTrackerProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  code: string;
  phone: string;
  methods: PaymentMethodDTO[];
  whatsapp: string;
  /** يُستدعى عند أي تغيير على الطلب (دفع/تقييم) لتحديث القوائم */
  onChanged?: () => void;
}

const FAILED_STATUSES: OrderStatus[] = [
  "CANCELLED",
  "REFUNDED",
  "FAILED_DELIVERY",
  "PAYMENT_REJECTED",
];

export function OrderTrackerDialog({
  open,
  onOpenChange,
  code,
  phone,
  methods,
  whatsapp,
  onChanged,
}: OrderTrackerProps) {
  const [order, setOrder] = useState<OrderDTO | null>(null);
  const [loading, setLoading] = useState(true);

  // نموذج التقييم
  const [smiley, setSmiley] = useState<Smiley | null>(null);
  const [matched, setMatched] = useState<boolean | null>(null);
  const [comment, setComment] = useState("");
  const [sendingReview, setSendingReview] = useState(false);

  // إرفاق إثبات دفع
  const [showAttach, setShowAttach] = useState(false);
  const [attachMethodRaw, setAttachMethodRaw] = useState("");
  const [attachRef, setAttachRef] = useState("");
  const [attachImg, setAttachImg] = useState("");
  const [sendingPayment, setSendingPayment] = useState(false);
  const attachFileRef = useRef<HTMLInputElement>(null);

  // جلب الطلب عند التركيب (الأب يعيد التركيب بمفتاح جديد عند كل فتح)
  useEffect(() => {
    if (!code || !phone) return;
    let cancelled = false;
    fetchOrderByCode(code, phone).then((o) => {
      if (!cancelled) {
        setOrder(o);
        setLoading(false);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [code, phone]);

  // للتحديث اليدوي ولإعادة الجلب بعد التقييم/الدفع (من معالجات أحداث)
  const load = useCallback(async () => {
    if (!code || !phone) return;
    setLoading(true);
    const o = await fetchOrderByCode(code, phone);
    setOrder(o);
    setLoading(false);
  }, [code, phone]);

  // أول طريقة غير COD افتراضية (مشتق بلا تأثيرات)
  const attachFallback = methods.find((m) => m.type !== "COD") ?? methods[0];
  const attachMethodId = attachMethodRaw || attachFallback?.id || "";

  const status = order?.status;
  const failed = status != null && FAILED_STATUSES.includes(status);
  const flowIdx = status != null ? ORDER_FLOW.indexOf(status) : -1;

  const stepState = (key: OrderStatus): "done" | "current" | "pending" => {
    if (failed) return "pending";
    const sIdx = ORDER_FLOW.indexOf(key);
    if (flowIdx >= sIdx) return flowIdx === sIdx ? "current" : "done";
    if (flowIdx >= 0 && flowIdx < ORDER_FLOW.indexOf("CONFIRMED") && key === "CONFIRMED")
      return "current";
    return "pending";
  };

  const sendReview = async () => {
    if (!order || !smiley || matched == null || sendingReview) return;
    setSendingReview(true);
    const ok = await submitReview({
      orderCode: order.orderCode,
      phone,
      rating: SMILEY_RATING[smiley],
      smiley,
      matchedPhotos: matched,
      comment: comment.trim() || undefined,
    });
    setSendingReview(false);
    if (ok) {
      toast({ title: "شكرًا لتقييمك 🌿", description: "رأيك يساعد باقي العملاء" });
      await load();
      onChanged?.();
    }
  };

  const sendPaymentProof = async () => {
    if (!order || sendingPayment) return;
    if (!attachRef.trim() && !attachImg) {
      toast({
        title: "إثبات ناقص",
        description: "أرفق رقم العملية أو صورة الإثبات",
        variant: "destructive",
      });
      return;
    }
    setSendingPayment(true);
    const paid = await submitPayment(order.orderCode, {
      phone,
      methodId: attachMethodId,
      transactionRef: attachRef.trim() || undefined,
      proofDataUrl: attachImg || undefined,
    });
    setSendingPayment(false);
    if (paid) {
      toast({ title: "تم إرسال الإثبات ✅", description: "سيُتحقق منه خلال دقائق" });
      setShowAttach(false);
      setAttachImg("");
      setAttachRef("");
      setOrder(paid);
      onChanged?.();
    }
  };

  const onPickImage = async (file: File | undefined) => {
    if (!file) return;
    try {
      setAttachImg(await compressImageToDataUrl(file, 600, 0.7));
    } catch {
      toast({ title: "تعذر قراءة الصورة", variant: "destructive" });
    }
  };

  const copyCode = async () => {
    if (!order) return;
    const ok = await copyText(order.orderCode);
    if (ok) toast({ title: "تم نسخ رقم الطلب ✅" });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] gap-0 overflow-hidden rounded-2xl p-0 sm:max-w-xl">
        <DialogHeader className="border-b p-4 ps-12 sm:p-5 sm:ps-12">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <DialogTitle className="flex items-center gap-2 text-lg font-black">
              تتبع الطلب
              <button
                type="button"
                onClick={copyCode}
                className="flex items-center gap-1 rounded-lg border bg-muted/50 px-2 py-0.5 text-sm font-mono transition-colors hover:bg-muted"
                aria-label="نسخ رقم الطلب"
              >
                <span dir="ltr">{order?.orderCode ?? code}</span>
                <Copy className="size-3.5 text-muted-foreground" aria-hidden />
              </button>
            </DialogTitle>
            <Button
              variant="ghost"
              size="icon"
              className="size-9 rounded-lg"
              onClick={load}
              disabled={loading}
              aria-label="تحديث الطلب"
            >
              <RefreshCw className={`size-4 ${loading ? "animate-spin" : ""}`} aria-hidden />
            </Button>
          </div>
          <DialogDescription>
            {order ? formatArabicDate(order.createdAt) : "تفاصيل طلبك لحظة بلحظة"}
          </DialogDescription>
        </DialogHeader>

        <div className="max-h-[calc(92vh-6rem)] overflow-y-auto p-4 sm:p-5">
          {loading && !order && (
            <div className="space-y-4">
              <Skeleton className="h-16 w-full rounded-xl" />
              <Skeleton className="h-24 w-full rounded-xl" />
              <Skeleton className="h-40 w-full rounded-xl" />
            </div>
          )}

          {!loading && !order && (
            <p className="py-10 text-center text-sm text-muted-foreground">
              تعذر جلب الطلب — تأكد من رقم الهاتف المسجّل به 🌿
            </p>
          )}

          {order && (
            <div className="space-y-5">
              {/* الحالة */}
              <div className="flex flex-wrap items-center gap-2">
                <span
                  className={`inline-flex items-center rounded-full border px-3 py-1 text-xs font-bold ${ORDER_STATUS_STYLE[order.status]}`}
                >
                  {ORDER_STATUSES[order.status]}
                </span>
                {order.payment && (
                  <span
                    className={`inline-flex items-center rounded-full border px-3 py-1 text-xs font-bold ${PAYMENT_STATUS_STYLE[order.payment.status]}`}
                  >
                    💳 {PAYMENT_STATUSES[order.payment.status]}
                  </span>
                )}
              </div>

              {/* تنبيهات الحالات الخاصة */}
              {order.status === "PENDING_PAYMENT" && (
                <Alert className="rounded-xl border-amber-300 bg-amber-50 text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200">
                  <AlertTitle className="font-bold">⏳ بانتظار الدفع</AlertTitle>
                  <AlertDescription className="text-xs leading-relaxed text-amber-800 dark:text-amber-300">
                    أكمل الدفع وأرفق الإثبات ليتم تأكيد طلبك.
                  </AlertDescription>
                </Alert>
              )}
              {order.status === "PAYMENT_SUBMITTED" && (
                <Alert className="rounded-xl border-emerald-300 bg-emerald-50 dark:border-emerald-800 dark:bg-emerald-950">
                  <AlertTitle className="font-bold text-emerald-900 dark:text-emerald-300">✅ وصل إثبات الدفع</AlertTitle>
                  <AlertDescription className="text-xs text-emerald-800 dark:text-emerald-300">
                    جارٍ التحقق من الدفع — عادةً خلال دقائق، ثم يبدأ التجهيز.
                  </AlertDescription>
                </Alert>
              )}
              {order.status === "PAYMENT_REJECTED" && (
                <Alert variant="destructive" className="rounded-xl">
                  <AlertTitle className="font-bold">❌ تم رفض إثبات الدفع</AlertTitle>
                  <AlertDescription className="text-xs">
                    {order.payment?.rejectReason || "راجع المتجر وأعد إرفاق إثبات صحيح."}
                  </AlertDescription>
                </Alert>
              )}
              {(order.status === "CANCELLED" || order.status === "REFUNDED" || order.status === "FAILED_DELIVERY") && (
                <Alert variant="destructive" className="rounded-xl">
                  <AlertTitle className="font-bold">{ORDER_STATUSES[order.status]}</AlertTitle>
                  <AlertDescription className="text-xs">
                    للاستفسار تواصل معنا عبر واتساب من أسفل الشاشة.
                  </AlertDescription>
                </Alert>
              )}

              {/* شريط الخطوات ✅🟡⚪ */}
              {!["CANCELLED", "REFUNDED", "FAILED_DELIVERY"].includes(order.status) && (
                <div className="rounded-2xl border bg-muted/30 p-4" aria-label="مراحل الطلب">
                  <div className="flex items-start">
                    {CUSTOMER_TRACK_STEPS.map((s, i) => {
                      const st = stepState(s.key);
                      return (
                        <div key={s.key} className={cn("flex items-start", i < CUSTOMER_TRACK_STEPS.length - 1 && "flex-1")}>
                          <div className="flex w-14 flex-col items-center gap-1.5 text-center">
                            <span className="text-2xl leading-none" aria-hidden>
                              {st === "done" ? "✅" : st === "current" ? "🟡" : "⚪"}
                            </span>
                            <span
                              className={cn(
                                "text-[11px] font-bold leading-tight",
                                st === "done" && "text-emerald-700 dark:text-emerald-400",
                                st === "current" && "text-amber-700 dark:text-amber-400",
                                st === "pending" && "text-muted-foreground"
                              )}
                            >
                              {s.label}
                            </span>
                          </div>
                          {i < CUSTOMER_TRACK_STEPS.length - 1 && (
                            <span
                              className={cn(
                                "-mt-4 h-0.5 flex-1 rounded-full",
                                stepState(s.key) === "done" ? "bg-emerald-400" : "bg-muted-foreground/25"
                              )}
                              aria-hidden
                            />
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}

              {/* إرفاق إثبات الدفع */}
              {(order.status === "PENDING_PAYMENT" || order.status === "PAYMENT_REJECTED") && methods.length > 0 && (
                <div className="rounded-2xl border p-4">
                  {!showAttach ? (
                    <Button
                      onClick={() => setShowAttach(true)}
                      variant="outline"
                      className="h-11 w-full rounded-xl font-bold"
                    >
                      <Camera className="size-4" aria-hidden />
                      إرفاق إثبات الدفع
                    </Button>
                  ) : (
                    <div className="space-y-3">
                      <h4 className="text-sm font-bold">إثبات الدفع</h4>
                      <Label className="text-xs font-semibold">طريقة الدفع</Label>
                      <RadioGroup
                        value={attachMethodId}
                        onValueChange={setAttachMethodRaw}
                        className="grid gap-2"
                      >
                        {methods
                          .filter((m) => m.type !== "COD")
                          .map((m) => (
                            <Label
                              key={m.id}
                              htmlFor={`at-${m.id}`}
                              className="flex cursor-pointer items-center gap-2.5 rounded-xl border p-2.5 text-sm has-[button[data-state=checked]]:border-primary has-[button[data-state=checked]]:bg-primary/5"
                            >
                              <RadioGroupItem id={`at-${m.id}`} value={m.id} />
                              <span className="font-bold">{m.name}</span>
                              <span className="text-[10px] text-muted-foreground">{PAYMENT_TYPES[m.type]}</span>
                              {m.accountNumber && (
                                <span dir="ltr" className="ms-auto font-mono text-[11px] text-muted-foreground">
                                  {m.accountNumber}
                                </span>
                              )}
                            </Label>
                          ))}
                      </RadioGroup>

                      <Input
                        value={attachRef}
                        onChange={(e) => setAttachRef(e.target.value)}
                        placeholder="رقم العملية / الحوالة"
                        dir="ltr"
                        className="h-11 rounded-xl text-left"
                        inputMode="numeric"
                      />

                      <input
                        ref={attachFileRef}
                        type="file"
                        accept="image/*"
                        className="hidden"
                        onChange={(e) => {
                          onPickImage(e.target.files?.[0]);
                          e.target.value = "";
                        }}
                      />
                      {attachImg ? (
                        <div className="relative w-fit overflow-hidden rounded-xl border">
                          <img src={attachImg} alt="إثبات الدفع" className="max-h-40 object-contain" />
                          <Button
                            variant="secondary"
                            size="icon"
                            className="absolute end-1.5 top-1.5 size-8 rounded-full"
                            onClick={() => setAttachImg("")}
                            aria-label="إزالة الصورة"
                          >
                            ✕
                          </Button>
                        </div>
                      ) : (
                        <Button
                          type="button"
                          variant="outline"
                          className="h-11 w-full rounded-xl border-dashed font-bold"
                          onClick={() => attachFileRef.current?.click()}
                        >
                          <Camera className="size-4" aria-hidden />
                          صورة الإثبات
                        </Button>
                      )}

                      <div className="flex gap-2">
                        <Button variant="ghost" className="h-11" onClick={() => setShowAttach(false)}>
                          إلغاء
                        </Button>
                        <Button onClick={sendPaymentProof} disabled={sendingPayment} className="h-11 flex-1 rounded-xl font-bold">
                          {sendingPayment ? <Loader2 className="size-4 animate-spin" aria-hidden /> : "إرسال الإثبات"}
                        </Button>
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* بطاقة الدفع */}
              {order.payment && order.payment.status !== "UNPAID" && (
                <div className="space-y-2 rounded-2xl border p-4 text-sm">
                  <h4 className="text-sm font-bold">💳 الدفع</h4>
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <span className="text-muted-foreground">الطريقة</span>
                    <span className="font-semibold">
                      {order.payment.methodSnapshot
                        ? `${order.payment.methodSnapshot.name}`
                        : "—"}
                    </span>
                  </div>
                  {order.payment.transactionRef && (
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <span className="text-muted-foreground">رقم العملية</span>
                      <span dir="ltr" className="rounded-md border bg-muted/50 px-2 py-0.5 font-mono text-xs font-bold">
                        {order.payment.transactionRef}
                      </span>
                    </div>
                  )}
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-muted-foreground">المبلغ</span>
                    <span className="font-black text-primary">{formatYER(order.payment.amount)}</span>
                  </div>
                  {order.payment.submittedAt && (
                    <p className="text-[11px] text-muted-foreground">
                      أُرسل {timeAgoAr(order.payment.submittedAt)}
                    </p>
                  )}
                  {order.payment.proofUrl && (
                    <a
                      href={order.payment.proofUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="mt-1 inline-flex items-center gap-2 rounded-xl border p-1.5 pe-3 transition-colors hover:bg-muted/50"
                    >
                      <img
                        src={order.payment.proofUrl}
                        alt="صورة إثبات الدفع"
                        loading="lazy"
                        className="size-12 rounded-lg object-cover"
                      />
                      <span className="text-xs font-bold text-primary">عرض صورة الإثبات</span>
                    </a>
                  )}
                </div>
              )}

              {/* الأصناف */}
              <div className="space-y-2.5 rounded-2xl border p-4">
                <h4 className="text-sm font-bold">🌿 الأصناف</h4>
                <ul className="space-y-2.5">
                  {order.items.map((it) => (
                    <li key={it.id} className="flex items-center gap-3">
                      <div className="size-12 shrink-0 overflow-hidden rounded-lg bg-muted">
                        {it.mainImage ? (
                          <img
                            src={it.mainImage}
                            alt={`قات ${it.productName}`}
                            loading="lazy"
                            className="size-full object-cover"
                          />
                        ) : (
                          <span className="grid size-full place-items-center text-xl" aria-hidden>🌿</span>
                        )}
                      </div>
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-bold">قات {it.productName}</p>
                        <p className="text-[11px] text-muted-foreground">
                          {it.batchCode} • {formatYER(it.unitPrice)} × {it.qty}
                        </p>
                      </div>
                      <span className="text-sm font-black">{formatYER(it.lineTotal)}</span>
                    </li>
                  ))}
                </ul>
                <Separator />
                <div className="space-y-1 text-sm">
                  <div className="flex justify-between text-muted-foreground">
                    <span>المجموع الفرعي</span>
                    <span>{formatYER(order.itemsTotal)}</span>
                  </div>
                  <div className="flex justify-between text-muted-foreground">
                    <span>التوصيل{order.zoneName ? ` — ${order.zoneName}` : ""}</span>
                    <span>{formatYER(order.deliveryFee)}</span>
                  </div>
                  {order.discount > 0 && (
                    <div className="flex justify-between text-emerald-700 dark:text-emerald-400">
                      <span>خصم</span>
                      <span>- {formatYER(order.discount)}</span>
                    </div>
                  )}
                  <div className="flex justify-between text-base font-black">
                    <span>الإجمالي</span>
                    <span className="text-primary">{formatYER(order.total)}</span>
                  </div>
                </div>
              </div>

              {/* العنوان */}
              <div className="space-y-1.5 rounded-2xl border p-4 text-sm">
                <h4 className="text-sm font-bold">📍 التوصيل</h4>
                <p className="font-semibold">
                  {order.zoneName ? `${order.zoneName} — ` : ""}
                  {order.addressText}
                </p>
                {order.note && (
                  <p className="text-xs text-muted-foreground">ملاحظة: {order.note}</p>
                )}
              </div>

              {/* حالة التوصيل + OTP */}
              {order.delivery && (
                <div className="space-y-2.5 rounded-2xl border p-4 text-sm">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <h4 className="text-sm font-bold">🚚 المندوب</h4>
                    <Badge variant="secondary" className="font-bold">
                      {DELIVERY_STATUSES[order.delivery.status]}
                    </Badge>
                  </div>
                  {order.delivery.driverName && (
                    <p className="text-muted-foreground">
                      السائق: <span className="font-bold text-foreground">{order.delivery.driverName}</span>
                    </p>
                  )}
                  {order.delivery.otp && order.delivery.status !== "DELIVERED" && (
                    <div className="rounded-xl border-2 border-dashed border-gold/50 bg-gold/10 p-3 text-center">
                      <p className="text-xs font-bold text-muted-foreground">🔑 رمز التسليم — أعطه للمندوب عند الاستلام</p>
                      <p className="mt-1 text-2xl font-black tracking-[0.4em] text-gold-foreground" dir="ltr">
                        {order.delivery.otp}
                      </p>
                    </div>
                  )}
                  {order.delivery.deliveredAt && (
                    <p className="text-xs text-emerald-700 dark:text-emerald-400">
                      ✅ تم التسليم {timeAgoAr(order.delivery.deliveredAt)}
                    </p>
                  )}
                </div>
              )}

              {/* التقييم */}
              {order.status === "DELIVERED" && (
                <div className="rounded-2xl border p-4">
                  <h4 className="mb-3 text-sm font-bold">🌿 قيّم تجربتك</h4>
                  {order.reviewed ? (
                    <p className="rounded-xl bg-muted/50 p-3 text-center text-sm font-semibold text-muted-foreground">
                      ⭐ تم تقييم هذا الطلب — شكرًا لك!
                    </p>
                  ) : (
                    <div className="space-y-4">
                      <div className="flex justify-center gap-2" role="radiogroup" aria-label="تقييمك العام">
                        {(Object.keys(SMILEYS) as Smiley[]).map((k) => (
                          <button
                            key={k}
                            type="button"
                            role="radio"
                            aria-checked={smiley === k}
                            aria-label={`تقييم: ${k}`}
                            onClick={() => setSmiley(k)}
                            className={cn(
                              "grid size-14 place-items-center rounded-2xl border-2 text-3xl transition-all outline-none focus-visible:ring-2 focus-visible:ring-ring",
                              smiley === k
                                ? "scale-110 border-gold bg-gold/10 gold-glow"
                                : "border-transparent opacity-70 hover:opacity-100"
                            )}
                          >
                            {SMILEYS[k]}
                          </button>
                        ))}
                      </div>

                      <div className="space-y-2">
                        <Label className="text-xs font-bold">هل كان القات مطابقًا للصور؟</Label>
                        <RadioGroup
                          value={matched == null ? undefined : matched ? "yes" : "no"}
                          onValueChange={(v) => setMatched(v === "yes")}
                          className="flex gap-2"
                        >
                          <Label
                            htmlFor="mt-yes"
                            className="flex flex-1 cursor-pointer items-center justify-center gap-2 rounded-xl border p-2.5 text-sm font-bold has-[button[data-state=checked]]:border-primary has-[button[data-state=checked]]:bg-primary/5"
                          >
                            <RadioGroupItem id="mt-yes" value="yes" />
                            ✅ نعم مطابق
                          </Label>
                          <Label
                            htmlFor="mt-no"
                            className="flex flex-1 cursor-pointer items-center justify-center gap-2 rounded-xl border p-2.5 text-sm font-bold has-[button[data-state=checked]]:border-primary has-[button[data-state=checked]]:bg-primary/5"
                          >
                            <RadioGroupItem id="mt-no" value="no" />
                            ❌ لا
                          </Label>
                        </RadioGroup>
                      </div>

                      <Textarea
                        value={comment}
                        onChange={(e) => setComment(e.target.value)}
                        placeholder="تعليق اختياري — جودة القات، سرعة التوصيل…"
                        rows={2}
                        className="rounded-xl"
                      />

                      <Button
                        onClick={sendReview}
                        disabled={!smiley || matched == null || sendingReview}
                        className="h-11 w-full rounded-xl font-black"
                      >
                        {sendingReview ? (
                          <Loader2 className="size-4 animate-spin" aria-hidden />
                        ) : (
                          <>
                            <Send className="size-4" aria-hidden />
                            إرسال التقييم
                          </>
                        )}
                      </Button>
                    </div>
                  )}
                </div>
              )}

              {/* سجل الطلب */}
              {order.history.length > 0 && (
                <Collapsible dir="rtl">
                  <CollapsibleTrigger className="flex h-11 w-full items-center justify-between rounded-xl border px-4 text-sm font-bold outline-none focus-visible:ring-2 focus-visible:ring-ring">
                    سجل الطلب
                    <ChevronDown className="size-4 transition-transform group-data-[state=open]:rotate-180" aria-hidden />
                  </CollapsibleTrigger>
                  <CollapsibleContent>
                    <ol className="mt-2 space-y-2 rounded-xl border p-4">
                      {[...order.history].reverse().map((h, i) => (
                        <li key={i} className="flex items-start gap-2.5 text-xs">
                          <span className="mt-1 size-2 shrink-0 rounded-full bg-primary/50" aria-hidden />
                          <div>
                            <p className="font-bold">
                              {ORDER_STATUSES[h.toStatus as OrderStatus] ?? h.toStatus}
                              {h.actor && <span className="font-normal text-muted-foreground"> — {h.actor}</span>}
                            </p>
                            <p className="text-muted-foreground">
                              {timeAgoAr(h.createdAt)}
                              {h.note ? ` • ${h.note}` : ""}
                            </p>
                          </div>
                        </li>
                      ))}
                    </ol>
                  </CollapsibleContent>
                </Collapsible>
              )}

              {/* واتساب */}
              <Button
                asChild
                className="h-12 w-full rounded-xl bg-[#1faa53] text-base font-black text-white hover:bg-[#1b8c47]"
              >
                <a
                  href={waLink(whatsapp, orderWaMessage(order.orderCode))}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <MessageCircle className="size-5" aria-hidden />
                  متابعة الطلب عبر واتساب
                </a>
              </Button>
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
