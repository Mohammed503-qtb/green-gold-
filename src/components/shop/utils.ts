// ============================================================
// GREEN GOLD | واجهة العميل — أدوات مساعدة مشتركة
// (لا تكرر تعريفات contracts.ts — استوردها فقط)
// ============================================================
import type { Smiley } from "@/lib/contracts";

// ───────── روابط واتساب ─────────

export function waLink(whatsapp: string, text: string): string {
  const num = (whatsapp || "").replace(/[^\d]/g, "");
  return `https://wa.me/${num}?text=${encodeURIComponent(text)}`;
}

/** الرسالة الجاهزة الرسمية لمتابعة الطلب */
export const orderWaMessage = (code: string) =>
  `السلام عليكم، لدي طلب ذهب أخضر رقم ${code} وأريد متابعة طلبي.`;

// ───────── وقت التصوير: "تصوير اليوم 12:40" ─────────

const hmFmt = new Intl.DateTimeFormat("ar", {
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
  numberingSystem: "latn",
});

const dayFmt = new Intl.DateTimeFormat("ar", {
  day: "numeric",
  month: "short",
  numberingSystem: "latn",
});

function startOfDay(x: Date) {
  return new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
}

export function capturedLabel(iso: string | null | undefined): string {
  if (!iso) return "وقت التصوير غير معروف";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "وقت التصوير غير معروف";
  const diffDays = Math.round((startOfDay(new Date()) - startOfDay(d)) / 86_400_000);
  if (diffDays <= 0) return `تصوير اليوم ${hmFmt.format(d)}`;
  if (diffDays === 1) return `تصوير أمس ${hmFmt.format(d)}`;
  return `تصوير ${dayFmt.format(d)}`;
}

// ───────── الهاتف اليمني ─────────

/** يحوّل المدخلات إلى 7xxxxxxxx أو يعيد null إن كان غير صالح */
export function normalizePhone(raw: string): string | null {
  let p = (raw || "").replace(/[\s\-()]/g, "");
  if (p.startsWith("+967")) p = p.slice(4);
  else if (p.startsWith("00967")) p = p.slice(5);
  else if (p.startsWith("967") && p.length === 12) p = p.slice(3);
  return /^7\d{8}$/.test(p) ? p : null;
}

// ───────── الحافظة (نسخ) ─────────

export async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    try {
      const ta = document.createElement("textarea");
      ta.value = text;
      ta.style.position = "fixed";
      ta.style.opacity = "0";
      document.body.appendChild(ta);
      ta.select();
      const ok = document.execCommand("copy");
      document.body.removeChild(ta);
      return ok;
    } catch {
      return false;
    }
  }
}

// ───────── ضغط صورة الإثبات إلى dataURL ─────────

/** يضغط الصورة إلى أقصى ضلع 600px بجودة 0.7 ويعيدها dataURL (jpeg) */
export function compressImageToDataUrl(file: File, maxSide = 600, quality = 0.7): Promise<string> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      try {
        const scale = Math.min(1, maxSide / Math.max(img.width, img.height));
        const w = Math.max(1, Math.round(img.width * scale));
        const h = Math.max(1, Math.round(img.height * scale));
        const canvas = document.createElement("canvas");
        canvas.width = w;
        canvas.height = h;
        const ctx = canvas.getContext("2d");
        if (!ctx) throw new Error("canvas unsupported");
        ctx.drawImage(img, 0, 0, w, h);
        URL.revokeObjectURL(url);
        resolve(canvas.toDataURL("image/jpeg", quality));
      } catch (e) {
        URL.revokeObjectURL(url);
        reject(e);
      }
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("failed to load image"));
    };
    img.src = url;
  });
}

// ───────── التقييم: وجه ← نجوم ─────────

export const SMILEY_RATING: Record<Smiley, number> = {
  LOVE: 5,
  GOOD: 4,
  OK: 3,
  BAD: 2,
};

// ───────── localStorage آمن ─────────

export const LS_KEYS = {
  phone: "gg-phone",
  name: "gg-name",
  zone: "gg-zone",
} as const;

export function lsGet(key: string): string | null {
  if (typeof window === "undefined") return null;
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

export function lsSet(key: string, value: string): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(key, value);
  } catch {
    /* ignore */
  }
}

// ───────── هاتف العميل كمخزن خارجي متفاعل (useSyncExternalStore) ─────────

const phoneListeners = new Set<() => void>();

export function subscribeSavedPhone(cb: () => void): () => void {
  phoneListeners.add(cb);
  return () => {
    phoneListeners.delete(cb);
  };
}

export function getSavedPhoneSnapshot(): string | null {
  return lsGet(LS_KEYS.phone);
}

export function setSavedPhone(value: string): void {
  lsSet(LS_KEYS.phone, value);
  phoneListeners.forEach((l) => l());
}
