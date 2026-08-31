"use client";

// ============================================================
// GREEN GOLD | طلباتي — إدخال هاتف (محفوظ) + قائمة الطلبات
// ============================================================
import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import { ChevronLeft, LogIn, Phone, RefreshCw, Store } from "lucide-react";

import { fetchOrdersByPhone } from "@/components/shop/api";
import { EmptyState } from "@/components/shop/empty-state";
import {
  getSavedPhoneSnapshot,
  normalizePhone,
  setSavedPhone,
  subscribeSavedPhone,
} from "@/components/shop/utils";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import {
  ORDER_STATUSES,
  ORDER_STATUS_STYLE,
  PAYMENT_STATUSES,
  PAYMENT_STATUS_STYLE,
  formatArabicDate,
  formatYER,
  type OrderDTO,
} from "@/lib/contracts";
import { cn } from "@/lib/utils";

export interface OrdersViewProps {
  onBack: () => void;
  onTrack: (code: string, phone: string) => void;
  /** يرتفع عند تغيّر طلب من المتتبع لإعادة الجلب */
  refreshKey: number;
}

export function OrdersView({ onBack, onTrack, refreshKey }: OrdersViewProps) {
  // هاتف محفوظ كمخزن خارجي متفاعل (آمن للترطيب)
  const savedRaw = useSyncExternalStore(
    subscribeSavedPhone,
    getSavedPhoneSnapshot,
    () => null
  );
  const savedPhone = savedRaw ? normalizePhone(savedRaw) : null;

  const [phoneInput, setPhoneInput] = useState("");
  const [phoneError, setPhoneError] = useState<string | null>(null);
  const [changeMode, setChangeMode] = useState(false);
  const [orders, setOrders] = useState<OrderDTO[] | null>(null);
  const [busy, setBusy] = useState(false);
  const startedRef = useRef(false);

  // تحميل تلقائي عند وجود هاتف محفوظ
  useEffect(() => {
    if (!savedPhone || startedRef.current) return;
    startedRef.current = true;
    let cancelled = false;
    fetchOrdersByPhone(savedPhone).then((list) => {
      if (!cancelled && list) setOrders(list);
    });
    return () => {
      cancelled = true;
    };
  }, [savedPhone]);

  // إعادة الجلب عند تغيّر طلب من المتتبع أو تغيّر الهاتف
  useEffect(() => {
    if (!savedPhone) return;
    let cancelled = false;
    fetchOrdersByPhone(savedPhone).then((list) => {
      if (!cancelled && list) setOrders(list);
    });
    return () => {
      cancelled = true;
    };
  }, [refreshKey, savedPhone]);

  const submitPhone = async () => {
    const norm = normalizePhone(phoneInput);
    if (!norm) {
      setPhoneError("أدخل رقمًا يمنيًا صحيحًا مثل 771234567");
      return;
    }
    setPhoneError(null);
    setBusy(true);
    setSavedPhone(norm);
    startedRef.current = true;
    setOrders(null);
    const list = await fetchOrdersByPhone(norm);
    if (list) setOrders(list);
    setBusy(false);
    setChangeMode(false);
  };

  const refresh = async () => {
    if (!savedPhone || busy) return;
    setBusy(true);
    const list = await fetchOrdersByPhone(savedPhone);
    if (list) setOrders(list);
    setBusy(false);
  };

  const showForm = changeMode || !savedPhone;
  const showList = !showForm && orders !== null && !busy;
  const showSkeletons = !showForm && (orders === null || busy);

  return (
    <section className="mx-auto w-full max-w-3xl px-4 py-8 sm:px-6" aria-label="طلباتي">
      {/* الرأس */}
      <div className="mb-5 flex items-center justify-between gap-2">
        <h2 className="text-xl font-black sm:text-2xl">📦 طلباتي</h2>
        <div className="flex items-center gap-1.5">
          {savedPhone && !showForm && (
            <Button
              variant="ghost"
              size="icon"
              className="size-11 rounded-xl"
              onClick={refresh}
              disabled={busy}
              aria-label="تحديث الطلبات"
            >
              <RefreshCw className={`size-4 ${busy ? "animate-spin" : ""}`} aria-hidden />
            </Button>
          )}
          <Button variant="outline" className="h-11 gap-2 rounded-xl font-bold" onClick={onBack}>
            <Store className="size-4" aria-hidden />
            المتجر
          </Button>
        </div>
      </div>

      {/* إدخال الهاتف */}
      {showForm && (
        <div className="rounded-2xl border bg-card p-5 shadow-sm">
          <div className="mb-4 flex items-center gap-3">
            <span className="grid size-11 place-items-center rounded-xl bg-primary/10 text-primary">
              <Phone className="size-5" aria-hidden />
            </span>
            <div>
              <h3 className="font-bold">اعرض طلباتك برقم هاتفك</h3>
              <p className="text-xs text-muted-foreground">
                يُحفظ الرقم على جهازك فقط — لا حاجة لكلمة مرور
              </p>
            </div>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="orders-phone" className="font-bold">
              رقم الهاتف
            </Label>
            <Input
              id="orders-phone"
              value={phoneInput}
              onChange={(e) => {
                setPhoneInput(e.target.value);
                setPhoneError(null);
              }}
              onKeyDown={(e) => e.key === "Enter" && submitPhone()}
              placeholder="7XXXXXXXX"
              inputMode="tel"
              dir="ltr"
              className="h-12 rounded-xl text-left text-base"
            />
            {phoneError && <p className="text-xs font-semibold text-destructive">{phoneError}</p>}
            <Button onClick={submitPhone} disabled={busy} className="mt-1 h-11 rounded-xl text-base font-black">
              {busy ? "جارٍ الجلب…" : "عرض طلباتي"}
              {!busy && <LogIn className="size-4" aria-hidden />}
            </Button>
          </div>
        </div>
      )}

      {/* الهاتف المحفوظ */}
      {!showForm && savedPhone && (
        <div className="mb-4 flex flex-wrap items-center justify-between gap-2 rounded-xl border bg-muted/40 px-4 py-2.5">
          <p className="flex items-center gap-2 text-sm">
            <Phone className="size-4 text-primary" aria-hidden />
            الطلبات المرتبطة بالرقم
            <span dir="ltr" className="rounded-md border bg-card px-2 py-0.5 font-mono text-xs font-bold">
              {savedPhone}
            </span>
          </p>
          <Button
            variant="ghost"
            className="h-9 rounded-lg text-xs font-bold"
            onClick={() => {
              setChangeMode(true);
              setPhoneInput(savedPhone);
            }}
          >
            تغيير الرقم
          </Button>
        </div>
      )}

      {/* التحميل */}
      {showSkeletons && (
        <div className="space-y-3" aria-live="polite">
          {Array.from({ length: 3 }).map((_, i) => (
            <Skeleton key={i} className="h-28 w-full rounded-2xl" />
          ))}
        </div>
      )}

      {/* القائمة */}
      {showList && orders && savedPhone && (
        <>
          {orders.length === 0 ? (
            <EmptyState
              icon="🌿"
              title="لا طلبات لهذا الرقم بعد"
              description="اطلب أول دفعة قات من المتجر وتابعها هنا من الدفع حتى التسليم."
              action={
                <Button onClick={onBack} className="h-11 rounded-xl px-6 font-bold">
                  تصفح قات اليوم
                </Button>
              }
            />
          ) : (
            <ul className="space-y-3">
              {orders.map((o) => (
                <li key={o.id}>
                  <button
                    type="button"
                    onClick={() => onTrack(o.orderCode, savedPhone)}
                    className="w-full cursor-pointer rounded-2xl border bg-card p-4 text-start shadow-sm outline-none transition-all hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-md focus-visible:ring-2 focus-visible:ring-ring"
                    aria-label={`تفاصيل الطلب ${o.orderCode}`}
                  >
                    <div className="flex items-center justify-between gap-2">
                      <span dir="ltr" className="font-mono text-sm font-black">
                        {o.orderCode}
                      </span>
                      <span
                        className={cn(
                          "inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-bold",
                          ORDER_STATUS_STYLE[o.status]
                        )}
                      >
                        {ORDER_STATUSES[o.status]}
                      </span>
                    </div>

                    <div className="mt-1.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-[11px] text-muted-foreground">
                      <span>{formatArabicDate(o.createdAt)}</span>
                      {o.payment && (
                        <span
                          className={cn(
                            "rounded-full border px-2 py-0.5 font-bold",
                            PAYMENT_STATUS_STYLE[o.payment.status]
                          )}
                        >
                          {PAYMENT_STATUSES[o.payment.status]}
                        </span>
                      )}
                      <span>{o.items.reduce((a, i) => a + i.qty, 0)} حزمة</span>
                    </div>

                    <div className="mt-3 flex items-center justify-between gap-3">
                      <div className="flex min-w-0 items-center gap-2">
                        <div className="flex -space-x-2 space-x-reverse">
                          {o.items.slice(0, 3).map((it) => (
                            <span
                              key={it.id}
                              className="grid size-9 place-items-center overflow-hidden rounded-lg border-2 border-card bg-muted"
                            >
                              {it.mainImage ? (
                                <img
                                  src={it.mainImage}
                                  alt=""
                                  loading="lazy"
                                  className="size-full object-cover"
                                />
                              ) : (
                                <span aria-hidden>🌿</span>
                              )}
                            </span>
                          ))}
                        </div>
                        <span className="truncate text-xs text-muted-foreground">
                          {o.items.map((i) => `قات ${i.productName} ×${i.qty}`).join("، ")}
                        </span>
                      </div>
                      <div className="flex shrink-0 items-center gap-1.5">
                        <span className="text-sm font-black text-primary">{formatYER(o.total)}</span>
                        <ChevronLeft className="size-4 text-muted-foreground" aria-hidden />
                      </div>
                    </div>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </>
      )}
    </section>
  );
}
