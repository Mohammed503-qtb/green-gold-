"use client";

// ============================================================
// GREEN GOLD | إتمام الطلب — 3 خطوات + شاشة نجاح ذهبية 🏆
// (1) البيانات والمنطقة → (2) طريقة الدفع + نسخ الحساب
// → (3) الإثبات (رقم عملية + صورة مضغوطة) أو الدفع عند الاستلام
// ============================================================
import { useMemo, useRef, useState } from "react";
import {
  Banknote,
  Camera,
  Check,
  CheckCircle2,
  Copy,
  Landmark,
  Loader2,
  MessageCircle,
  PackageSearch,
  Wallet,
  X,
} from "lucide-react";

import { createOrder, submitPayment } from "@/components/shop/api";
import {
  compressImageToDataUrl,
  copyText,
  LS_KEYS,
  lsGet,
  lsSet,
  normalizePhone,
  orderWaMessage,
  setSavedPhone,
  waLink,
} from "@/components/shop/utils";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { ScrollArea } from "@/components/ui/scroll-area";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Separator } from "@/components/ui/separator";
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { Textarea } from "@/components/ui/textarea";
import { toast } from "@/hooks/use-toast";
import { cartSubtotal, useCartStore } from "@/lib/cart-store";
import {
  PAYMENT_TYPES,
  formatYER,
  type OrderDTO,
  type PaymentMethodDTO,
  type PaymentType,
  type ZoneDTO,
} from "@/lib/contracts";
import { cn } from "@/lib/utils";

export interface CheckoutSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  zones: ZoneDTO[];
  methods: PaymentMethodDTO[];
  zoneId: string;
  onZoneChange: (zoneId: string) => void;
  whatsapp: string;
  onTrack: (code: string, phone: string) => void;
}

type Step = 1 | 2 | 3 | "success";

const STEP_LABELS = ["بياناتك", "الدفع", "الإثبات"];

const TYPE_ICON: Record<PaymentType, typeof Landmark> = {
  BANK: Landmark,
  WALLET: Wallet,
  COD: Banknote,
};

interface FormErrors {
  name?: string;
  phone?: string;
  zone?: string;
  address?: string;
  proof?: string;
}

export function CheckoutSheet({
  open,
  onOpenChange,
  zones,
  methods,
  zoneId,
  onZoneChange,
  whatsapp,
  onTrack,
}: CheckoutSheetProps) {
  const items = useCartStore((s) => s.items);
  const clearCart = useCartStore((s) => s.clear);

  const [step, setStep] = useState<Step>(1);
  // المكوّن يُعاد تركيبه عند كل فتح (key من الأب) — المُهيّئات تقرأ آخر بيانات
  const [name, setName] = useState(() => lsGet(LS_KEYS.name) ?? "");
  const [phone, setPhone] = useState(() => lsGet(LS_KEYS.phone) ?? "");
  const [addressText, setAddressText] = useState("");
  const [label, setLabel] = useState("");
  const [notes, setNotes] = useState("");
  const [errors, setErrors] = useState<FormErrors>({});
  const [methodIdRaw, setMethodIdRaw] = useState("");
  const [transactionRef, setTransactionRef] = useState("");
  const [proofDataUrl, setProofDataUrl] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [successOrder, setSuccessOrder] = useState<OrderDTO | null>(null);
  const [attachFailed, setAttachFailed] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const subtotal = cartSubtotal(items);
  const zone = zones.find((z) => z.id === zoneId) ?? null;
  const total = subtotal + (zone ? zone.fee : 0);
  // أول طريقة دفع افتراضية (مشتق بلا تأثيرات)
  const methodId = methodIdRaw || methods[0]?.id || "";
  const method = methods.find((m) => m.id === methodId) ?? null;
  const isCod = method?.type === "COD";

  const validateStep1 = (): boolean => {
    const e: FormErrors = {};
    if (name.trim().length < 2) e.name = "اكتب اسمك الكامل (حرفان على الأقل)";
    if (!normalizePhone(phone)) e.phone = "أدخل رقمًا يمنيًا صحيحًا مثل 771234567";
    if (!zoneId) e.zone = "اختر منطقة التوصيل";
    if (addressText.trim().length < 5) e.address = "اكتب وصف العنوان بشكل أوضح (5 أحرف فأكثر)";
    setErrors(e);
    return Object.keys(e).length === 0;
  };

  const goStep2 = () => {
    if (!validateStep1()) return;
    lsSet(LS_KEYS.name, name.trim());
    setSavedPhone(normalizePhone(phone)!);
    setStep(2);
  };

  const onPickImage = async (file: File | undefined) => {
    if (!file) return;
    if (!file.type.startsWith("image/")) {
      toast({ title: "ملف غير صالح", description: "اختر صورة لإثبات الدفع", variant: "destructive" });
      return;
    }
    try {
      const dataUrl = await compressImageToDataUrl(file, 600, 0.7);
      setProofDataUrl(dataUrl);
      setErrors((e) => ({ ...e, proof: undefined }));
    } catch {
      toast({ title: "تعذر قراءة الصورة", description: "جرّب صورة أخرى", variant: "destructive" });
    }
  };

  const confirmOrder = async () => {
    if (submitting) return;
    const phoneNorm = normalizePhone(phone)!;
    if (!isCod && !transactionRef.trim() && !proofDataUrl) {
      setErrors({ proof: "أرفق رقم العملية أو صورة الإثبات على الأقل" });
      return;
    }
    setSubmitting(true);
    const order = await createOrder({
      customer: { name: name.trim(), phone: phoneNorm },
      address: {
        zoneId,
        addressText: addressText.trim(),
        notes: notes.trim() || undefined,
        label: label.trim() || undefined,
      },
      items: items.map((i) => ({ batchId: i.batchId, qty: i.qty })),
    });
    if (!order) {
      setSubmitting(false); // toast عربي صادر من api.ts (مثل نفاد الكمية 409)
      return;
    }

    // إرفاق إثبات الدفع إن كانت الطريقة تتطلب ذلك
    let finalOrder = order;
    let failed = false;
    if (!isCod && method && (transactionRef.trim() || proofDataUrl)) {
      const paid = await submitPayment(order.orderCode, {
        phone: phoneNorm,
        methodId: method.id,
        transactionRef: transactionRef.trim() || undefined,
        proofDataUrl: proofDataUrl || undefined,
      });
      if (paid) finalOrder = paid;
      else failed = true;
    }

    clearCart();
    setSavedPhone(phoneNorm);
    lsSet(LS_KEYS.name, name.trim());
    setAttachFailed(failed);
    setSuccessOrder(finalOrder);
    setStep("success");
    setSubmitting(false);
  };

  const copyAccount = async (value: string) => {
    const ok = await copyText(value);
    toast({
      title: ok ? "تم نسخ رقم الحساب ✅" : "تعذر النسخ",
      description: ok ? value : "انسخ الرقم يدويًا من الشاشة",
      variant: ok ? "default" : "destructive",
    });
  };

  const copyOrderCode = async () => {
    if (!successOrder) return;
    const ok = await copyText(successOrder.orderCode);
    toast({
      title: ok ? "تم نسخ رقم الطلب ✅" : "تعذر النسخ",
      description: ok ? successOrder.orderCode : undefined,
      variant: ok ? "default" : "destructive",
    });
  };

  const summaryLines = useMemo(
    () => (
      <div className="space-y-1.5 text-sm">
        <div className="flex justify-between text-muted-foreground">
          <span>المجموع الفرعي ({items.reduce((a, i) => a + i.qty, 0)} حزمة)</span>
          <span className="font-semibold text-foreground">{formatYER(subtotal)}</span>
        </div>
        <div className="flex justify-between text-muted-foreground">
          <span>التوصيل{zone ? ` — ${zone.name}` : ""}</span>
          {zone ? (
            <span className="font-semibold text-foreground">{formatYER(zone.fee)}</span>
          ) : (
            <span className="text-xs">اختر المنطقة</span>
          )}
        </div>
        <div className="flex justify-between text-base font-black">
          <span>الإجمالي</span>
          <span className="text-primary">{formatYER(total)}</span>
        </div>
      </div>
    ),
    [items, subtotal, zone, total]
  );

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="left" className="flex w-full flex-col gap-0 p-0 sm:max-w-lg">
        <SheetHeader className="border-b ps-12 pe-4">
          <SheetTitle className="text-lg font-black">
            {step === "success" ? "تم الطلب بنجاح" : "إتمام الطلب"}
          </SheetTitle>
          <SheetDescription>
            {step === "success" ? "احتفظ برقم الطلب للمتابعة" : "خطوات قليلة ويوصلك قاتك 🌿"}
          </SheetDescription>
        </SheetHeader>

        {/* مؤشر الخطوات */}
        {step !== "success" && (
          <div className="flex items-center gap-1 border-b bg-muted/30 px-5 py-3.5" aria-label={`الخطوة ${step} من 3`}>
            {STEP_LABELS.map((lbl, i) => {
              const n = (i + 1) as 1 | 2 | 3;
              const done = typeof step === "number" && step > n;
              const active = step === n;
              return (
                <div key={lbl} className={cn("flex items-center", i < 2 && "flex-1")}>
                  <div className="flex flex-col items-center gap-1">
                    <span
                      className={cn(
                        "grid size-8 place-items-center rounded-full border-2 text-xs font-black transition-all",
                        done && "border-primary bg-primary text-primary-foreground",
                        active && "border-primary bg-primary/10 text-primary ring-4 ring-primary/15",
                        !done && !active && "border-muted-foreground/30 text-muted-foreground"
                      )}
                    >
                      {done ? <Check className="size-4" aria-hidden /> : n}
                    </span>
                    <span
                      className={cn(
                        "text-[11px] font-bold",
                        active ? "text-primary" : done ? "text-foreground" : "text-muted-foreground"
                      )}
                    >
                      {lbl}
                    </span>
                  </div>
                  {i < 2 && (
                    <span
                      className={cn("mx-2 mb-5 h-0.5 flex-1 rounded-full", done ? "bg-primary" : "bg-muted")}
                      aria-hidden
                    />
                  )}
                </div>
              );
            })}
          </div>
        )}

        <ScrollArea className="flex-1">
          <div className="p-4 sm:p-5">
            {/* السلة فارغة (حالة حدّية) */}
            {step !== "success" && items.length === 0 && (
              <div className="py-16 text-center">
                <span className="text-5xl" aria-hidden>🛒</span>
                <p className="mt-3 font-bold">سلتك فارغة</p>
                <p className="mt-1 text-sm text-muted-foreground">أضف دفعة من المتجر أولًا</p>
                <Button variant="outline" className="mt-4 h-11 rounded-xl px-6" onClick={() => onOpenChange(false)}>
                  تصفح الدفعات
                </Button>
              </div>
            )}

            {/* ───── الخطوة 1: البيانات ───── */}
            {step === 1 && items.length > 0 && (
              <div className="space-y-4">
                <div className="grid gap-2">
                  <Label htmlFor="co-name" className="font-bold">الاسم الكامل *</Label>
                  <Input
                    id="co-name"
                    value={name}
                    onChange={(e) => {
                      setName(e.target.value);
                      setErrors((x) => ({ ...x, name: undefined }));
                    }}
                    placeholder="مثال: أحمد عبدالله"
                    className="h-11 rounded-xl"
                    autoComplete="name"
                  />
                  {errors.name && <p className="text-xs font-semibold text-destructive">{errors.name}</p>}
                </div>

                <div className="grid gap-2">
                  <Label htmlFor="co-phone" className="font-bold">رقم الهاتف *</Label>
                  <Input
                    id="co-phone"
                    value={phone}
                    onChange={(e) => {
                      setPhone(e.target.value);
                      setErrors((x) => ({ ...x, phone: undefined }));
                    }}
                    placeholder="7XXXXXXXX"
                    inputMode="tel"
                    dir="ltr"
                    className="h-11 rounded-xl text-left"
                    autoComplete="tel"
                  />
                  {errors.phone ? (
                    <p className="text-xs font-semibold text-destructive">{errors.phone}</p>
                  ) : (
                    <p className="text-[11px] text-muted-foreground">نستخدم رقمك لعرض طلباتك فقط</p>
                  )}
                </div>

                <div className="grid gap-2">
                  <Label className="font-bold">منطقة التوصيل *</Label>
                  <Select
                    value={zoneId}
                    onValueChange={(v) => {
                      onZoneChange(v);
                      setErrors((x) => ({ ...x, zone: undefined }));
                    }}
                  >
                    <SelectTrigger className="h-11 rounded-xl" aria-label="منطقة التوصيل">
                      <SelectValue placeholder="اختر المنطقة" />
                    </SelectTrigger>
                    <SelectContent>
                      {zones.map((z) => (
                        <SelectItem key={z.id} value={z.id} className="py-2.5">
                          {z.name} — {formatYER(z.fee)}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  {errors.zone && <p className="text-xs font-semibold text-destructive">{errors.zone}</p>}
                </div>

                <div className="grid gap-2">
                  <Label htmlFor="co-address" className="font-bold">وصف العنوان *</Label>
                  <Textarea
                    id="co-address"
                    value={addressText}
                    onChange={(e) => {
                      setAddressText(e.target.value);
                      setErrors((x) => ({ ...x, address: undefined }));
                    }}
                    placeholder="مثال: كريتر، جولة المصلى، قرب مسجد النور، العمارة الثالثة"
                    className="min-h-20 rounded-xl"
                    rows={2}
                  />
                  {errors.address && <p className="text-xs font-semibold text-destructive">{errors.address}</p>}
                </div>

                <div className="grid gap-4 sm:grid-cols-2">
                  <div className="grid gap-2">
                    <Label htmlFor="co-label" className="text-sm font-bold">وسم المكان (اختياري)</Label>
                    <Input
                      id="co-label"
                      value={label}
                      onChange={(e) => setLabel(e.target.value)}
                      placeholder="المنزل / العمل"
                      className="h-11 rounded-xl"
                    />
                  </div>
                  <div className="grid gap-2">
                    <Label htmlFor="co-notes" className="text-sm font-bold">ملاحظات (اختياري)</Label>
                    <Input
                      id="co-notes"
                      value={notes}
                      onChange={(e) => setNotes(e.target.value)}
                      placeholder="وقت مناسب للتوصيل…"
                      className="h-11 rounded-xl"
                    />
                  </div>
                </div>

                <Separator />
                {summaryLines}

                <div className="flex gap-2 pt-1">
                  <Button variant="outline" className="h-11 rounded-xl" onClick={() => onOpenChange(false)}>
                    رجوع
                  </Button>
                  <Button onClick={goStep2} className="h-11 flex-1 rounded-xl text-base font-black">
                    متابعة للدفع
                  </Button>
                </div>
              </div>
            )}

            {/* ───── الخطوة 2: طريقة الدفع ───── */}
            {step === 2 && items.length > 0 && (
              <div className="space-y-4">
                <RadioGroup value={methodId} onValueChange={setMethodIdRaw} className="gap-3">
                  {methods.map((m) => {
                    const Icon = TYPE_ICON[m.type] ?? Banknote;
                    return (
                      <Label
                        key={m.id}
                        htmlFor={`pm-${m.id}`}
                        className={cn(
                          "flex cursor-pointer items-start gap-3 rounded-xl border p-3.5 transition-all",
                          "has-[button[data-state=checked]]:border-primary has-[button[data-state=checked]]:bg-primary/5 has-[button[data-state=checked]]:shadow-sm"
                        )}
                      >
                        <RadioGroupItem id={`pm-${m.id}`} value={m.id} className="mt-1" />
                        <span className="grid size-10 shrink-0 place-items-center rounded-lg bg-primary/10 text-primary">
                          <Icon className="size-5" aria-hidden />
                        </span>
                        <span className="min-w-0 flex-1">
                          <span className="flex flex-wrap items-center gap-2">
                            <span className="font-bold">{m.name}</span>
                            <span className="rounded-full bg-muted px-2 py-0.5 text-[10px] font-bold text-muted-foreground">
                              {PAYMENT_TYPES[m.type]}
                            </span>
                          </span>
                          {m.accountNumber && (
                            <span className="mt-2 flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                              {m.institution && <span>{m.institution}</span>}
                              {m.accountName && <span>— {m.accountName}</span>}
                              <span className="flex items-center gap-1.5">
                                <span dir="ltr" className="rounded-md border bg-card px-2 py-1 font-mono text-[11px] font-bold text-foreground">
                                  {m.accountNumber}
                                </span>
                                <Button
                                  type="button"
                                  variant="outline"
                                  size="icon"
                                  className="size-8"
                                  onClick={(e) => {
                                    e.preventDefault();
                                    copyAccount(m.accountNumber!);
                                  }}
                                  aria-label="نسخ رقم الحساب"
                                >
                                  <Copy className="size-3.5" aria-hidden />
                                </Button>
                              </span>
                            </span>
                          )}
                          {m.instructions && (
                            <span className="mt-1.5 block text-[11px] leading-relaxed text-muted-foreground">
                              {m.instructions}
                            </span>
                          )}
                        </span>
                      </Label>
                    );
                  })}
                </RadioGroup>

                {methods.length === 0 && (
                  <p className="rounded-xl border border-dashed p-4 text-center text-sm text-muted-foreground">
                    لا توجد طرق دفع متاحة حاليًا — جرّب لاحقًا 🌿
                  </p>
                )}

                <Separator />
                {summaryLines}

                <div className="flex gap-2 pt-1">
                  <Button variant="outline" className="h-11 rounded-xl" onClick={() => setStep(1)}>
                    رجوع
                  </Button>
                  <Button
                    onClick={() => setStep(3)}
                    disabled={!methodId}
                    className="h-11 flex-1 rounded-xl text-base font-black"
                  >
                    متابعة
                  </Button>
                </div>
              </div>
            )}

            {/* ───── الخطوة 3: الإثبات والتأكيد ───── */}
            {step === 3 && items.length > 0 && (
              <div className="space-y-4">
                {method && (
                  <Alert className="rounded-xl border-primary/25 bg-primary/5">
                    <AlertDescription className="text-xs leading-relaxed">
                      طريقة الدفع: <strong>{method.name}</strong>
                      {isCod ? (
                        <> — ستدفع <strong>{formatYER(total)}</strong> نقدًا عند الاستلام، لا حاجة لإثبات الآن.</>
                      ) : (
                        <> — حوّل <strong>{formatYER(total)}</strong> ثم أرفق الإثبات أدناه.</>
                      )}
                    </AlertDescription>
                  </Alert>
                )}

                {!isCod && (
                  <>
                    <div className="grid gap-2">
                      <Label htmlFor="co-ref" className="font-bold">رقم العملية / الحوالة</Label>
                      <Input
                        id="co-ref"
                        value={transactionRef}
                        onChange={(e) => {
                          setTransactionRef(e.target.value);
                          setErrors((x) => ({ ...x, proof: undefined }));
                        }}
                        placeholder="مثال: 8462091"
                        dir="ltr"
                        className="h-11 rounded-xl text-left"
                        inputMode="numeric"
                      />
                    </div>

                    <div className="grid gap-2">
                      <Label className="font-bold">صورة الإثبات (تُضغط تلقائيًا 🌿)</Label>
                      <input
                        ref={fileInputRef}
                        type="file"
                        accept="image/*"
                        className="hidden"
                        onChange={(e) => {
                          onPickImage(e.target.files?.[0]);
                          e.target.value = "";
                        }}
                      />
                      {proofDataUrl ? (
                        <div className="relative inline-block w-fit overflow-hidden rounded-xl border">
                          <img
                            src={proofDataUrl}
                            alt="معاينة إثبات الدفع"
                            className="max-h-48 max-w-full object-contain"
                          />
                          <Button
                            type="button"
                            variant="secondary"
                            size="icon"
                            className="absolute end-2 top-2 size-8 rounded-full shadow"
                            onClick={() => setProofDataUrl("")}
                            aria-label="إزالة الصورة"
                          >
                            <X className="size-4" aria-hidden />
                          </Button>
                        </div>
                      ) : (
                        <button
                          type="button"
                          onClick={() => fileInputRef.current?.click()}
                          className="flex min-h-28 w-full flex-col items-center justify-center gap-2 rounded-xl border-2 border-dashed p-4 text-sm text-muted-foreground transition-colors outline-none hover:border-primary/40 hover:bg-primary/5 focus-visible:ring-2 focus-visible:ring-ring"
                        >
                          <Camera className="size-7 text-primary" aria-hidden />
                          <span className="font-bold text-foreground">أرفق صورة الإثبات</span>
                          <span className="text-[11px]">لقطة شاشة التحويل أو صورة الإيصال</span>
                        </button>
                      )}
                    </div>

                    {errors.proof && <p className="text-xs font-semibold text-destructive">{errors.proof}</p>}
                  </>
                )}

                <Separator />
                {summaryLines}

                <div className="flex gap-2 pt-1">
                  <Button variant="outline" className="h-11 rounded-xl" onClick={() => setStep(2)} disabled={submitting}>
                    رجوع
                  </Button>
                  <Button
                    onClick={confirmOrder}
                    disabled={submitting || !zoneId}
                    className="gold-glow h-11 flex-1 rounded-xl border-none bg-gold text-base font-black text-gold-foreground hover:bg-gold/90"
                  >
                    {submitting ? (
                      <>
                        <Loader2 className="size-4 animate-spin" aria-hidden />
                        جارٍ تأكيد الطلب…
                      </>
                    ) : (
                      "تأكيد الطلب"
                    )}
                  </Button>
                </div>
              </div>
            )}

            {/* ───── شاشة النجاح الذهبية ───── */}
            {step === "success" && successOrder && (
              <div className="flex flex-col items-center gap-4 py-6 text-center">
                <span className="gold-glow grid size-20 place-items-center rounded-full bg-gold/15">
                  <CheckCircle2 className="size-10 text-gold" aria-hidden />
                </span>

                <div>
                  <h3 className="text-2xl font-black">تم استلام طلبك 🎉</h3>
                  <p className="mt-1 text-sm text-muted-foreground">
                    {successOrder.status === "PAYMENT_SUBMITTED"
                      ? "وصل إثبات الدفع — سيُتحقق منه خلال دقائق ثم يبدأ التجهيز."
                      : successOrder.status === "PENDING_PAYMENT" && isCod
                        ? "الدفع عند الاستلام — سنتواصل معك لتأكيد الطلب."
                        : attachFailed
                          ? "تم حفظ طلبك لكن تعذّر إرفاق الإثبات — أرفقه من شاشة «تتبع الطلب»."
                          : "سنتواصل معك عبر واتساب عند الحاجة."}
                  </p>
                </div>

                <div className="w-full rounded-2xl border-2 border-dashed border-gold/50 bg-gold/10 px-4 py-4">
                  <p className="text-xs font-bold text-muted-foreground">رقم الطلب — احتفظ به</p>
                  <div className="mt-1 flex items-center justify-center gap-2">
                    <span className="text-2xl font-black tracking-wider" dir="ltr">
                      {successOrder.orderCode}
                    </span>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="size-9"
                      onClick={copyOrderCode}
                      aria-label="نسخ رقم الطلب"
                    >
                      <Copy className="size-4" aria-hidden />
                    </Button>
                  </div>
                  <p className="mt-1 text-xs text-muted-foreground">
                    الإجمالي: <strong>{formatYER(successOrder.total)}</strong>
                  </p>
                </div>

                <div className="grid w-full gap-2">
                  <Button asChild className="h-12 rounded-xl bg-[#1faa53] text-base font-black text-white hover:bg-[#1b8c47]">
                    <a
                      href={waLink(whatsapp, orderWaMessage(successOrder.orderCode))}
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      <MessageCircle className="size-5" aria-hidden />
                      متابعة عبر واتساب
                    </a>
                  </Button>
                  <div className="grid grid-cols-2 gap-2">
                    <Button
                      variant="outline"
                      className="h-11 rounded-xl font-bold"
                      onClick={() => onTrack(successOrder.orderCode, normalizePhone(phone) ?? phone)}
                    >
                      <PackageSearch className="size-4" aria-hidden />
                      تتبع طلبي
                    </Button>
                    <Button
                      variant="ghost"
                      className="h-11 rounded-xl font-bold"
                      onClick={() => onOpenChange(false)}
                    >
                      متابعة التسوق
                    </Button>
                  </div>
                </div>
              </div>
            )}
          </div>
        </ScrollArea>
      </SheetContent>
    </Sheet>
  );
}
