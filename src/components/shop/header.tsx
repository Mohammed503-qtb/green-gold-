"use client";

// ============================================================
// GREEN GOLD | رأس الصفحة: الشعار + طلباتي + السلة + واتساب
// ============================================================
import { Leaf, MapPin, MessageCircle, Package, ShoppingCart, Store } from "lucide-react";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

export interface HeaderProps {
  storeName: string;
  whatsapp: string;
  cartCount: number;
  view: "home" | "orders";
  onNavHome: () => void;
  onNavOrders: () => void;
  onCartOpen: () => void;
}

export function Header({
  storeName,
  whatsapp,
  cartCount,
  view,
  onNavHome,
  onNavOrders,
  onCartOpen,
}: HeaderProps) {
  return (
    <header className="sticky top-0 z-40 border-b bg-background/85 backdrop-blur supports-[backdrop-filter]:bg-background/70">
      <div className="mx-auto flex h-16 w-full max-w-7xl items-center justify-between gap-2 px-4 sm:px-6">
        {/* الشعار */}
        <button
          type="button"
          onClick={onNavHome}
          className="flex min-h-11 items-center gap-2.5 rounded-xl px-1 outline-none focus-visible:ring-2 focus-visible:ring-ring"
          aria-label={`${storeName} — الصفحة الرئيسية`}
        >
          <span className="grid size-10 place-items-center rounded-xl bg-gradient-to-br from-primary to-emerald-800 text-primary-foreground shadow-md">
            <Leaf className="size-5" aria-hidden />
          </span>
          <span className="flex flex-col items-start leading-tight">
            <span className="gold-text text-lg font-black">{storeName}</span>
            <span className="flex items-center gap-1 text-[11px] text-muted-foreground">
              <MapPin className="size-3" aria-hidden />
              قات اليوم • عدن
            </span>
          </span>
        </button>

        {/* الأزرار */}
        <nav className="flex items-center gap-1.5" aria-label="أزرار سريعة">
          {whatsapp && (
            <Button
              asChild
              variant="outline"
              size="icon"
              className="size-11 rounded-xl border-primary/30 text-primary hover:bg-primary/10 hover:text-primary"
            >
              <a
                href={`https://wa.me/${whatsapp.replace(/[^\d]/g, "")}`}
                target="_blank"
                rel="noopener noreferrer"
                aria-label="تواصل معنا عبر واتساب"
              >
                <MessageCircle className="size-5" aria-hidden />
              </a>
            </Button>
          )}

          {view === "home" ? (
            <Button
              variant="ghost"
              onClick={onNavOrders}
              className="h-11 gap-2 rounded-xl px-3 font-semibold"
              aria-label="طلباتي"
            >
              <Package className="size-5" aria-hidden />
              <span className="hidden md:inline">طلباتي</span>
            </Button>
          ) : (
            <Button
              variant="ghost"
              onClick={onNavHome}
              className="h-11 gap-2 rounded-xl px-3 font-semibold"
              aria-label="العودة للمتجر"
            >
              <Store className="size-5" aria-hidden />
              <span className="hidden md:inline">المتجر</span>
            </Button>
          )}

          <Button
            variant="secondary"
            onClick={onCartOpen}
            className="relative h-11 gap-2 rounded-xl px-3 font-semibold"
            aria-label={`السلة${cartCount > 0 ? ` — ${cartCount} صنف` : " — فارغة"}`}
          >
            <ShoppingCart className="size-5" aria-hidden />
            <span className="hidden sm:inline">السلة</span>
            <span
              className={cn(
                "absolute -start-1.5 -top-1.5 grid h-5 min-w-5 place-items-center rounded-full bg-gold px-1 text-[11px] font-black text-gold-foreground shadow transition-transform",
                cartCount > 0 ? "scale-100" : "scale-0"
              )}
              aria-hidden
            >
              {cartCount}
            </span>
          </Button>
        </nav>
      </div>
    </header>
  );
}
