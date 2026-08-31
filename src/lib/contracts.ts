// ============================================================
// GREEN GOLD | ذهب أخضر — العقود المشتركة (مصدر الحقيقة الواحد)
// يستخدمها الخادم والعميل والإدارة — لا يجوز تعريف حالات خارجها
// ============================================================

// ───────── حالات الطلب (State Machine) ─────────
export const ORDER_STATUSES = {
  PENDING_PAYMENT: "بانتظار الدفع",
  PAYMENT_SUBMITTED: "تم إرسال إثبات الدفع",
  CONFIRMED: "تم تأكيد الطلب",
  PREPARING: "جاري التجهيز",
  READY_FOR_DELIVERY: "جاهز للتوصيل",
  OUT_FOR_DELIVERY: "خرج للتوصيل",
  DELIVERED: "تم التسليم",
  CANCELLED: "ملغي",
  PAYMENT_REJECTED: "مرفوض الدفع",
  REFUNDED: "مسترجع",
  FAILED_DELIVERY: "تعذر التوصيل",
} as const;
export type OrderStatus = keyof typeof ORDER_STATUSES;

// المسار الطبيعي للطلب
export const ORDER_FLOW: OrderStatus[] = [
  "PENDING_PAYMENT",
  "PAYMENT_SUBMITTED",
  "CONFIRMED",
  "PREPARING",
  "READY_FOR_DELIVERY",
  "OUT_FOR_DELIVERY",
  "DELIVERED",
];

// خطوات شريط التتبع للعميل
export const CUSTOMER_TRACK_STEPS: { key: OrderStatus; label: string }[] = [
  { key: "CONFIRMED", label: "تم التأكيد" },
  { key: "PREPARING", label: "جاري التجهيز" },
  { key: "OUT_FOR_DELIVERY", label: "التوصيل" },
  { key: "DELIVERED", label: "التسليم" },
];

// ألوان شارات حالات الطلب (فئات tailwind ثابتة)
export const ORDER_STATUS_STYLE: Record<OrderStatus, string> = {
  PENDING_PAYMENT: "bg-amber-100 text-amber-800 border-amber-200",
  PAYMENT_SUBMITTED: "bg-violet-100 text-violet-800 border-violet-200",
  CONFIRMED: "bg-emerald-100 text-emerald-800 border-emerald-200",
  PREPARING: "bg-lime-100 text-lime-800 border-lime-200",
  READY_FOR_DELIVERY: "bg-teal-100 text-teal-800 border-teal-200",
  OUT_FOR_DELIVERY: "bg-cyan-100 text-cyan-800 border-cyan-200",
  DELIVERED: "bg-green-100 text-green-800 border-green-200",
  CANCELLED: "bg-stone-200 text-stone-600 border-stone-300",
  PAYMENT_REJECTED: "bg-red-100 text-red-700 border-red-200",
  REFUNDED: "bg-orange-100 text-orange-800 border-orange-200",
  FAILED_DELIVERY: "bg-red-100 text-red-700 border-red-200",
};

// ───────── حالات الدفع ─────────
export const PAYMENT_STATUSES = {
  UNPAID: "غير مدفوع",
  PENDING_VERIFICATION: "بانتظار التحقق",
  PAID: "مدفوع",
  REJECTED: "مرفوض",
  REFUNDED: "مسترجع",
} as const;
export type PaymentStatus = keyof typeof PAYMENT_STATUSES;

export const PAYMENT_STATUS_STYLE: Record<PaymentStatus, string> = {
  UNPAID: "bg-stone-100 text-stone-700 border-stone-200",
  PENDING_VERIFICATION: "bg-amber-100 text-amber-800 border-amber-200",
  PAID: "bg-emerald-100 text-emerald-800 border-emerald-200",
  REJECTED: "bg-red-100 text-red-700 border-red-200",
  REFUNDED: "bg-orange-100 text-orange-800 border-orange-200",
};

// ───────── التصنيفات ─────────
export const GRADES = {
  PREMIUM: "فاخر",
  EXCELLENT: "ممتاز",
  ECONOMIC: "اقتصادي",
} as const;
export type Grade = keyof typeof GRADES;

export const GRADE_STYLE: Record<Grade, string> = {
  PREMIUM: "bg-gradient-to-l from-amber-200 to-yellow-100 text-amber-900 border-amber-300",
  EXCELLENT: "bg-emerald-100 text-emerald-800 border-emerald-200",
  ECONOMIC: "bg-stone-100 text-stone-700 border-stone-200",
};

export const GRADE_EMOJI: Record<Grade, string> = {
  PREMIUM: "💎",
  EXCELLENT: "⭐",
  ECONOMIC: "💰",
};

// ───────── حالات التوصيل ─────────
export const DELIVERY_STATUSES = {
  WAITING: "بانتظار التعيين",
  ASSIGNED: "تم تعيين سائق",
  PICKED_UP: "تم الاستلام من المحل",
  OUT_FOR_DELIVERY: "في الطريق إليك",
  DELIVERED: "تم التسليم",
  FAILED: "تعذر التسليم",
} as const;
export type DeliveryStatus = keyof typeof DELIVERY_STATUSES;

// ───────── أنواع طرق الدفع ─────────
export const PAYMENT_TYPES = {
  BANK: "تحويل بنكي",
  WALLET: "محفظة إلكترونية",
  COD: "الدفع عند الاستلام",
} as const;
export type PaymentType = keyof typeof PAYMENT_TYPES;

// ───────── الصلاحيات ─────────
export const STAFF_ROLES = {
  OWNER: "المالك",
  MANAGER: "مدير",
  STAFF: "موظف",
  DELIVERY: "سائق",
} as const;
export type StaffRole = keyof typeof STAFF_ROLES;

// صلاحيات مبسطة: من يستطيع فعل ماذا
export const CAN = {
  verifyPayment: ["OWNER", "MANAGER"],
  manageBatches: ["OWNER", "MANAGER", "STAFF"],
  changePrice: ["OWNER", "MANAGER"],
  advanceOrder: ["OWNER", "MANAGER", "STAFF"],
  manageDelivery: ["OWNER", "MANAGER", "STAFF", "DELIVERY"],
  viewReports: ["OWNER", "MANAGER"],
  viewAudit: ["OWNER", "MANAGER"],
} as const;

// ───────── التقييم ─────────
export const SMILEYS = {
  LOVE: "😍",
  GOOD: "🙂",
  OK: "😐",
  BAD: "☹️",
} as const;
export type Smiley = keyof typeof SMILEYS;

// ───────── أدوات مساعدة ─────────

// تنسيق المبلغ بالريال اليمني (أرقام لاتينية)
export function formatYER(amount: number): string {
  return new Intl.NumberFormat("ar-YE", { maximumFractionDigits: 0, numberingSystem: "latn" }).format(amount) + " ريال";
}

// تنسيق التاريخ عربيًا
export function formatArabicDate(d: string | Date, withTime = true): string {
  const date = typeof d === "string" ? new Date(d) : d;
  return new Intl.DateTimeFormat("ar", {
    day: "numeric",
    month: "short",
    ...(withTime ? { hour: "2-digit", minute: "2-digit" } : {}),
    numberingSystem: "latn",
  }).format(date);
}

// "منذ كذا" عربي
export function timeAgoAr(d: string | Date): string {
  const date = typeof d === "string" ? new Date(d) : d;
  const diff = Date.now() - date.getTime();
  const m = Math.floor(diff / 60000);
  if (m < 1) return "الآن";
  if (m < 60) return `منذ ${m} دقيقة`;
  const h = Math.floor(m / 60);
  if (h < 24) return `منذ ${h} ساعة`;
  const days = Math.floor(h / 24);
  if (days === 1) return "أمس";
  if (days < 7) return `منذ ${days} أيام`;
  return formatArabicDate(date, false);
}

// عتبة "مخزون منخفض"
export const LOW_STOCK_THRESHOLD = 5;

// مهلة حجز المخزون (دقائق)
export const RESERVATION_MINUTES = 30;

// ───────── أشكال الـ API (TypeScript) ─────────

export interface BatchCardDTO {
  id: string;
  batchCode: string;
  productId: string;
  productName: string;
  grade: Grade;
  price: number;
  availableQty: number;
  status: "ACTIVE" | "HIDDEN" | "CLOSED" | "SOLD_OUT";
  capturedAt: string;
  mainImage: string | null;
  images: string[];
  video: string | null;
  quality: { freshness: number; density: number; fullness: number; appearance: number } | null;
  soldCount: number;
  avgRating: number | null;
  reviewsCount: number;
}

export interface PaymentMethodDTO {
  id: string;
  name: string;
  type: PaymentType;
  accountName: string | null;
  institution: string | null;
  accountNumber: string | null;
  instructions: string | null;
}

export interface ZoneDTO {
  id: string;
  name: string;
  fee: number;
}

export interface OrderItemDTO {
  id: string;
  batchId: string;
  productName: string;
  batchCode: string;
  grade: Grade;
  unitPrice: number;
  qty: number;
  lineTotal: number;
  mainImage: string | null;
}

export interface PaymentDTO {
  id: string;
  status: PaymentStatus;
  amount: number;
  methodSnapshot: { name: string; type: PaymentType } | null;
  transactionRef: string | null;
  proofUrl: string | null;
  submittedAt: string | null;
  verifiedAt: string | null;
  rejectReason: string | null;
}

export interface DeliveryDTO {
  id: string;
  status: DeliveryStatus;
  driverName: string | null;
  otp: string | null;
  assignedAt: string | null;
  deliveredAt: string | null;
}

export interface OrderDTO {
  id: string;
  orderCode: string;
  status: OrderStatus;
  itemsTotal: number;
  deliveryFee: number;
  discount: number;
  total: number;
  customerName: string;
  phone: string;
  addressText: string;
  zoneName: string | null;
  note: string | null;
  createdAt: string;
  items: OrderItemDTO[];
  payment: PaymentDTO | null;
  delivery: DeliveryDTO | null;
  history: { fromStatus: string | null; toStatus: string; actor: string; note: string | null; createdAt: string }[];
  reviewed: boolean;
}
