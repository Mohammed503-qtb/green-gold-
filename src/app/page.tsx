"use client";

// ============================================================
// GREEN GOLD | ذهب أخضر — الصفحة الوحيدة (/)
// متجر العميل (Store) + وضع الإدارة (AdminApp) خلف زر الدخول
// ============================================================

import { useCallback, useEffect, useState } from "react";
import { Leaf, MessageCircle, ShieldCheck, Camera, Truck } from "lucide-react";
import { Store } from "@/components/shop/store";
import { AdminApp } from "@/components/admin/admin-app";
import { getStaff } from "@/components/admin/api";

const ADMIN_KEY = "gg-admin-open";

export default function GreenGoldPage() {
  const [mode, setMode] = useState<"boot" | "shop" | "admin">("boot");

  // استرجاع وضع الإدارة إذا كان مفتوحًا في نفس التبويب (مؤجل لتجنب setState متزامن)
  useEffect(() => {
    const t = window.setTimeout(() => {
      const wasAdmin =
        window.sessionStorage.getItem(ADMIN_KEY) === "1" && !!getStaff();
      setMode(wasAdmin ? "admin" : "shop");
    }, 0);
    return () => window.clearTimeout(t);
  }, []);

  const openAdmin = useCallback(() => {
    window.sessionStorage.setItem(ADMIN_KEY, "1");
    setMode("admin");
  }, []);

  const exitAdmin = useCallback(() => {
    window.sessionStorage.removeItem(ADMIN_KEY);
    setMode("shop");
  }, []);

  if (mode === "boot") {
    // شاشة إقلاع خفيفة حتى لا يومض المحتوى قبل معرفة الوضع
    return (
      <div className="flex min-h-[100dvh] items-center justify-center bg-background">
        <div className="gold-glow flex size-16 items-center justify-center rounded-2xl bg-primary/10">
          <Leaf className="size-8 text-primary" aria-hidden="true" />
        </div>
      </div>
    );
  }

  if (mode === "admin") {
    return <AdminApp onExit={exitAdmin} />;
  }

  return (
    <Store
      initialTab="home"
      footer={
        <footer className="mt-10 border-t bg-gradient-to-b from-transparent to-primary/5">
          <div className="mx-auto w-full max-w-6xl px-4 py-8 pb-[calc(2rem+env(safe-area-inset-bottom))]">
            <div className="grid gap-6 sm:grid-cols-3">
              {/* الهوية */}
              <div>
                <div className="flex items-center gap-2">
                  <span className="flex size-9 items-center justify-center rounded-xl bg-primary/10">
                    <Leaf className="size-5 text-primary" aria-hidden="true" />
                  </span>
                  <div>
                    <p className="gold-text text-lg font-black leading-tight">ذهب أخضر</p>
                    <p className="text-muted-foreground text-[11px]">قات اليوم في عدن</p>
                  </div>
                </div>
                <p className="text-muted-foreground mt-3 max-w-xs text-xs leading-5">
                  كل صورة وفيديو هنا مرتبط بدفعة حقيقية برمز ووقت تصوير —
                  ما تشوفه هو ما تستلمه.
                </p>
              </div>

              {/* الثقة */}
              <div className="space-y-2.5 text-xs">
                <p className="flex items-center gap-2">
                  <Camera className="size-4 text-primary" aria-hidden="true" />
                  تصوير حقيقي لكل دفعة
                </p>
                <p className="flex items-center gap-2">
                  <ShieldCheck className="size-4 text-primary" aria-hidden="true" />
                  تحقق بشري من كل دفعة مالية
                </p>
                <p className="flex items-center gap-2">
                  <Truck className="size-4 text-primary" aria-hidden="true" />
                  توصيل برمز تسليم OTP
                </p>
              </div>

              {/* تواصل */}
              <div className="flex flex-col items-start gap-3 sm:items-end">
                <a
                  href="https://wa.me/967771234567"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex h-11 items-center gap-2 rounded-full bg-primary px-5 text-sm font-bold text-primary-foreground shadow-sm transition hover:opacity-90 focus-visible:outline-2"
                >
                  <MessageCircle className="size-4" aria-hidden="true" />
                  تواصل عبر واتساب
                </a>
                <button
                  onClick={openAdmin}
                  className="text-muted-foreground hover:text-primary inline-flex h-11 items-center gap-1.5 rounded-full border px-4 text-[11px] font-medium transition"
                >
                  <ShieldCheck className="size-3.5" aria-hidden="true" />
                  دخول الإدارة
                </button>
              </div>
            </div>

            <div className="text-muted-foreground mt-6 flex flex-col items-center justify-between gap-2 border-t pt-4 text-[11px] sm:flex-row">
              <p>© {new Date().getFullYear()} ذهب أخضر — جميع الحقوق محفوظة</p>
              <p dir="ltr" className="font-mono opacity-70">GREEN GOLD • ADEN</p>
            </div>
          </div>
        </footer>
      }
    />
  );
}
