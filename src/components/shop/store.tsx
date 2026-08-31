"use client";

// ============================================================
// GREEN GOLD | منسّق واجهة العميل — يجمع كل شيء
// حالة عرض واحدة (home | orders) + السلة + الدفع + التتبع
// ============================================================
import { useCallback, useEffect, useState, useSyncExternalStore, type ReactNode } from "react";
import { MessageCircle } from "lucide-react";

import {
  fetchCatalog,
  fetchCheckoutData,
  fetchPublicSettings,
} from "@/components/shop/api";
import { BatchDetailsDialog } from "@/components/shop/batch-details";
import { CartSheet } from "@/components/shop/cart-sheet";
import { CheckoutSheet } from "@/components/shop/checkout-sheet";
import { Header } from "@/components/shop/header";
import { Hero } from "@/components/shop/hero";
import { OrderTrackerDialog } from "@/components/shop/order-tracker";
import { OrdersView } from "@/components/shop/orders-view";
import { Sections } from "@/components/shop/sections";
import { LS_KEYS, lsGet, lsSet, setSavedPhone, waLink } from "@/components/shop/utils";
import { toast } from "@/hooks/use-toast";
import { cartCount, useCartStore } from "@/lib/cart-store";
import type { BatchCardDTO, PaymentMethodDTO, ZoneDTO } from "@/lib/contracts";

export interface StoreProps {
  /** العرض الابتدائي — يفيد للروابط المباشرة */
  initialTab?: "home" | "orders";
  /** فوتر اختياري يُلصق أسفل الصفحة تلقائيًا (sticky footer) */
  footer?: ReactNode;
}

const emptySubscribe = () => () => {};

export function Store({ initialTab = "home", footer }: StoreProps) {
  const [view, setView] = useState<"home" | "orders">(initialTab);
  // كشف اكتمال الترطيب بأمان (بلا setState داخل تأثير)
  const mounted = useSyncExternalStore(
    emptySubscribe,
    () => true,
    () => false
  );

  // الكتالوج
  const [catalog, setCatalog] = useState<BatchCardDTO[]>([]);
  const [catalogLoading, setCatalogLoading] = useState(true);
  const [catalogError, setCatalogError] = useState(false);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  // الإعدادات وبيانات الشراء
  const [storeName, setStoreName] = useState("ذهب أخضر");
  const [whatsapp, setWhatsapp] = useState("967771234567");
  const [zones, setZones] = useState<ZoneDTO[]>([]);
  const [methods, setMethods] = useState<PaymentMethodDTO[]>([]);
  // منطقة محفوظة (تُقرأ كسلسلة داخل أعمدة مغلقة فقط — آمن للترطيب)
  const [zoneId, setZoneId] = useState(() => lsGet(LS_KEYS.zone) ?? "");

  // النوافذ + مفاتيح إعادة التركيب (تصفير حالة نظيف عند كل فتح)
  const [cartOpen, setCartOpen] = useState(false);
  const [checkoutOpen, setCheckoutOpen] = useState(false);
  const [checkoutSession, setCheckoutSession] = useState(0);
  const [detailsId, setDetailsId] = useState<string | null>(null);
  const [detailsSession, setDetailsSession] = useState(0);
  const [track, setTrack] = useState<{ code: string; phone: string } | null>(null);
  const [trackSession, setTrackSession] = useState(0);
  const [ordersNonce, setOrdersNonce] = useState(0);

  const items = useCartStore((s) => s.items);
  const validateCart = useCartStore((s) => s.validateAgainstCatalog);

  // ───────── جلب البيانات ─────────

  // جلب الكتالوج — كل تحديثات الحالة بعد await (بلا setState متزامن داخل تأثيرات)
  const refreshCatalog = useCallback(async () => {
    const list = await fetchCatalog();
    if (list) {
      setCatalog(list);
      setCatalogError(false);
      setLastUpdated(new Date());
    } else {
      setCatalogError(true);
    }
    setCatalogLoading(false);
  }, []);

  // للتحديث اليدوي (من معالج حدث — يجوز فيه setState متزامن)
  const manualRefresh = useCallback(() => {
    setCatalogLoading(true);
    refreshCatalog();
  }, [refreshCatalog]);

  // تحميل أولي — كل تحديثات الحالة بعد await (متوافق مع قواعد التأثيرات)
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const [catalogList, checkout, settings] = await Promise.all([
        fetchCatalog(),
        fetchCheckoutData(),
        fetchPublicSettings(),
      ]);
      if (cancelled) return;
      if (catalogList) {
        setCatalog(catalogList);
        setCatalogError(false);
        setLastUpdated(new Date());
      } else {
        setCatalogError(true);
      }
      setCatalogLoading(false);
      if (checkout) {
        setZones(checkout.zones ?? []);
        setMethods(checkout.methods ?? []);
        if (checkout.storeName) setStoreName(checkout.storeName);
        if (checkout.whatsapp) setWhatsapp(checkout.whatsapp);
      }
      if (settings) {
        if (settings.storeName) setStoreName(settings.storeName);
        if (settings.whatsapp) setWhatsapp(settings.whatsapp);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  // حفظ المنطقة المختارة
  useEffect(() => {
    if (zoneId) lsSet(LS_KEYS.zone, zoneId);
  }, [zoneId]);

  // التحقق من السلة ضد الكتالوج (خطة §24: "الدفعة انتهت")
  useEffect(() => {
    if (catalogLoading || catalog.length === 0) return;
    const res = validateCart(catalog);
    if (res.removed.length > 0) {
      toast({
        title: "تحديث السلة ⚠️",
        description: `الدفعة انتهت وتمت إزالتها: ${res.removed.join("، ")}`,
        variant: "destructive",
      });
    } else if (res.adjusted.length > 0) {
      toast({
        title: "تحديث السلة",
        description: `نقصت الكمية المتاحة وتم تصحيحها لـ: ${res.adjusted.join("، ")}`,
      });
    }
  }, [catalog, catalogLoading, validateCart]);

  // ───────── إجراءات مشتركة ─────────

  const openDetails = useCallback((id: string) => {
    setDetailsId(id);
    setDetailsSession((k) => k + 1);
  }, []);

  const openTrack = useCallback((code: string, phone: string) => {
    setSavedPhone(phone);
    setTrack({ code, phone });
    setTrackSession((k) => k + 1);
  }, []);

  const cartTotal = mounted ? cartCount(items) : 0;

  return (
    <div className="flex min-h-[100dvh] flex-col bg-background">
      <Header
        storeName={storeName}
        whatsapp={whatsapp}
        cartCount={cartTotal}
        view={view}
        onNavHome={() => setView("home")}
        onNavOrders={() => setView("orders")}
        onCartOpen={() => setCartOpen(true)}
      />

      <main className="flex-1">
        {view === "home" ? (
          <>
            <Hero
              availableCount={catalog.filter((b) => b.availableQty > 0).length}
              lastUpdated={lastUpdated}
              loading={catalogLoading}
              onOrders={() => setView("orders")}
            />
            <Sections
              batches={catalog}
              loading={catalogLoading}
              error={catalogError}
              onRefresh={manualRefresh}
              onOpenBatch={openDetails}
            />
          </>
        ) : (
          <OrdersView
            onBack={() => setView("home")}
            onTrack={openTrack}
            refreshKey={ordersNonce}
          />
        )}
      </main>

      {/* زر واتساب عائم */}
      <a
        href={waLink(whatsapp, "السلام عليكم، أريد الاستفسار عن دفعات قات اليوم 🌿")}
        target="_blank"
        rel="noopener noreferrer"
        aria-label="تواصل معنا عبر واتساب"
        className="fixed bottom-5 left-5 z-40 grid size-14 place-items-center rounded-full bg-[#20a354] text-white shadow-lg transition-transform hover:scale-105 focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-hidden"
      >
        <MessageCircle className="size-6" aria-hidden />
      </a>

      {/* النوافذ — تُعاد تركيبها بمفتاح جلسة عند كل فتح (تصفير نظيف + حركة إغلاق سليمة) */}
      <BatchDetailsDialog
        key={detailsSession}
        open={detailsId != null}
        batchId={detailsId}
        onOpenChange={(o) => {
          if (!o) setDetailsId(null);
        }}
        onViewCart={() => setCartOpen(true)}
      />

      <CartSheet
        open={cartOpen}
        onOpenChange={setCartOpen}
        zones={zones}
        zoneId={zoneId}
        onZoneChange={setZoneId}
        onCheckout={() => {
          setCartOpen(false);
          setCheckoutSession((s) => s + 1);
          setCheckoutOpen(true);
        }}
      />

      <CheckoutSheet
        key={checkoutSession}
        open={checkoutOpen}
        onOpenChange={setCheckoutOpen}
        zones={zones}
        methods={methods}
        zoneId={zoneId}
        onZoneChange={setZoneId}
        whatsapp={whatsapp}
        onTrack={(code, phone) => {
          setCheckoutOpen(false);
          setView("orders");
          setOrdersNonce((n) => n + 1);
          openTrack(code, phone);
        }}
      />

      <OrderTrackerDialog
        key={trackSession}
        open={track != null}
        onOpenChange={(o) => {
          if (!o) setTrack(null);
        }}
        code={track?.code ?? ""}
        phone={track?.phone ?? ""}
        methods={methods}
        whatsapp={whatsapp}
        onChanged={() => setOrdersNonce((n) => n + 1)}
      />

      {/* فوتر لاصق اختياري (يمرّره page.tsx) */}
      {footer && <div className="mt-auto">{footer}</div>}
    </div>
  );
}
