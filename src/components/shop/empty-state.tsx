"use client";

// ============================================================
// GREEN GOLD | حالة فارغة عربية جميلة 🌿
// ============================================================
import type { ReactNode } from "react";

export interface EmptyStateProps {
  icon?: string;
  title: string;
  description?: string;
  action?: ReactNode;
  className?: string;
}

export function EmptyState({
  icon = "🌿",
  title,
  description,
  action,
  className = "",
}: EmptyStateProps) {
  return (
    <div
      className={`flex flex-col items-center justify-center gap-3 rounded-2xl border border-dashed px-6 py-14 text-center ${className}`}
      role="status"
    >
      <span className="text-5xl" aria-hidden>
        {icon}
      </span>
      <h3 className="text-lg font-bold">{title}</h3>
      {description && <p className="max-w-sm text-sm leading-relaxed text-muted-foreground">{description}</p>}
      {action && <div className="mt-2">{action}</div>}
    </div>
  );
}
