"use client";

// ============================================================
// GREEN GOLD | شاشة دخول الإدارة بالرمز (PIN)
// ============================================================

import { useEffect, useState } from "react";
import { Leaf, LogIn, Loader2, ArrowRight, ShieldCheck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { toast } from "@/hooks/use-toast";
import { PinInput } from "./pin-input";
import { ApiError, loginWithPin, type StaffSession } from "./api";
import { STAFF_ROLES } from "@/lib/contracts";

interface LoginScreenProps {
  onSuccess: (session: StaffSession) => void;
  /** العودة لواجهة العميل */
  onExit: () => void;
}

export function LoginScreen({ onSuccess, onExit }: LoginScreenProps) {
  const [pin, setPin] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (value: string) => {
    if (loading || value.length !== 4) return;
    setLoading(true);
    setError(null);
    try {
      const session = await loginWithPin(value);
      toast({
        title: `أهلًا ${session.name} 👋`,
        description: `تم الدخول بصفة: ${STAFF_ROLES[session.role]}`,
      });
      onSuccess(session);
    } catch (e) {
      const msg = e instanceof ApiError ? e.message : "تعذر تسجيل الدخول";
      setError(msg);
      setPin("");
    } finally {
      setLoading(false);
    }
  };

  // إرسال تلقائي عند اكتمال 4 خانات
  useEffect(() => {
    if (pin.length === 4 && !loading) {
      void submit(pin);
    }
  }, [pin]);

  return (
    <div
      className="fixed inset-0 z-50 flex flex-col items-center justify-center overflow-y-auto bg-gradient-to-b from-primary/95 via-primary to-emerald-950 p-4"
      dir="rtl"
    >
      <button
        onClick={onExit}
        className="absolute top-4 left-4 inline-flex items-center gap-1.5 rounded-lg bg-white/10 px-3 py-2 text-sm font-medium text-white/90 transition hover:bg-white/20"
        aria-label="العودة إلى واجهة العميل"
      >
        <ArrowRight className="size-4" aria-hidden="true" />
        واجهة العميل
      </button>

      <div className="w-full max-w-sm">
        <div className="mb-6 flex flex-col items-center gap-3 text-center">
          <div className="gold-glow flex size-16 items-center justify-center rounded-2xl bg-white/95">
            <Leaf className="size-8 text-primary" aria-hidden="true" />
          </div>
          <div>
            <h1 className="text-2xl font-extrabold text-white">
              ذهب <span className="gold-text">أخضر</span>
            </h1>
            <p className="mt-1 text-sm font-medium text-emerald-100">لوحة الإدارة — قات اليوم في عدن</p>
          </div>
        </div>

        <div className="gold-glow rounded-2xl bg-card p-6 shadow-xl">
          <div className="mb-5 flex flex-col items-center gap-1.5 text-center">
            <ShieldCheck className="text-primary size-6" aria-hidden="true" />
            <h2 className="text-base font-bold">تسجيل دخول الموظفين</h2>
            <p className="text-muted-foreground text-xs">أدخل رمز الدخول المكوّن من 4 أرقام</p>
          </div>

          <div className="flex justify-center">
            <PinInput
              value={pin}
              onChange={setPin}
              disabled={loading}
              autoFocus
              aria-label="رمز الدخول"
            />
          </div>

          {error ? (
            <p className="mt-3 text-center text-sm font-semibold text-red-600" role="alert">
              ✗ {error}
            </p>
          ) : null}

          <Button
            className="mt-5 h-11 w-full rounded-xl text-base font-bold"
            onClick={() => void submit(pin)}
            disabled={loading || pin.length !== 4}
          >
            {loading ? (
              <>
                <Loader2 className="size-4 animate-spin" aria-hidden="true" /> جارٍ التحقق…
              </>
            ) : (
              <>
                <LogIn className="size-4" aria-hidden="true" /> دخول
              </>
            )}
          </Button>

          <p className="text-muted-foreground mt-4 text-center text-[11px] leading-relaxed">
            الجلسة محفوظة على هذا الجهاز فقط. عند انتهاء صلاحية الرمز ستُطلب إعادة الدخول تلقائيًا.
          </p>
        </div>
      </div>
    </div>
  );
}
