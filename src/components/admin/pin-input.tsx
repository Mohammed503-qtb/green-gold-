"use client";

import { cn } from "@/lib/utils";

// ============================================================
// GREEN GOLD | مُدخل رمز رقمي (PIN / OTP)
// بديل موثوق لـ input-otp — يعمل باللمس والكيبورد وقارئات الشاشة
// ============================================================

interface PinInputProps {
  value: string;
  onChange: (v: string) => void;
  length?: number;
  disabled?: boolean;
  invalid?: boolean;
  autoFocus?: boolean;
  "aria-label"?: string;
  className?: string;
  boxClassName?: string;
}

export function PinInput({
  value,
  onChange,
  length = 4,
  disabled,
  invalid,
  autoFocus,
  className,
  boxClassName,
  ...aria
}: PinInputProps) {
  const chars = Array.from({ length }, (_, i) => value[i] ?? "");

  return (
    <div dir="ltr" className={cn("relative inline-flex select-none", className)}>
      {/* الإدخال الحقيقي: شفاف يغطي الصناديق */}
      <input
        type="text"
        inputMode="numeric"
        autoComplete="one-time-code"
        maxLength={length}
        value={value}
        disabled={disabled}
        autoFocus={autoFocus}
        onChange={(e) => onChange(e.target.value.replace(/\D/g, "").slice(0, length))}
        aria-label={aria["aria-label"] ?? "رمز رقمي"}
        className="absolute inset-0 z-10 h-full w-full cursor-text bg-transparent text-transparent caret-transparent opacity-0"
      />
      {/* الصناديق المرئية */}
      <div className="pointer-events-none flex gap-2">
        {chars.map((c, i) => (
          <div
            key={i}
            data-filled={c !== ""}
            className={cn(
              "border-input bg-background flex h-14 w-12 items-center justify-center border-2 text-2xl font-black tabular-nums transition-all",
              "focus-within:border-ring data-[filled=true]:border-primary data-[filled=true]:text-foreground",
              i === 0 && "rounded-l-xl border-l",
              i === chars.length - 1 && "rounded-r-xl",
              invalid && "border-red-400 data-[filled=true]:border-red-500",
              disabled && "opacity-60",
              boxClassName
            )}
          >
            {c || <span className="text-muted-foreground/40">•</span>}
          </div>
        ))}
      </div>
    </div>
  );
}
