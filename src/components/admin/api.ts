"use client";

// ============================================================
// GREEN GOLD | واجهة الإدارة — طبقة الاتصال بالخادم
// fetch موحدة: ترفق x-staff-pin من جلسة gg-staff (localStorage)
// + معالجة 401 (خروج تلقائي) + toast أخطاء عربية
// ============================================================

import { toast } from "@/hooks/use-toast";
import {
  STAFF_ROLES,
  timeAgoAr,
  type BatchCardDTO,
  type DeliveryStatus,
  type OrderDTO,
  type StaffRole,
} from "@/lib/contracts";

// ───────── جلسة الموظف (gg-staff) ─────────

export interface StaffSession {
  name: string;
  role: StaffRole;
  pin: string;
}

const STAFF_KEY = "gg-staff";

/** نسخة آمنة من timeAgoAr للترطيب (تعيد نصًا ثابتًا على الخادم) */
export function timeAgoArSafe(d: string | Date | null | undefined): string {
  if (typeof window === "undefined") return "";
  if (!d) return "—";
  return timeAgoAr(d);
}

/** حدث يُبث عند انتهاء الصلاحية (401) ليستمع له admin-app ويخرج تلقائيًا */
export const STAFF_UNAUTHORIZED_EVENT = "gg-staff-unauthorized";
/** حدث يُبث بعد أي عملية حساسة لتحديث لوحة المعلومات فورًا */
export const ADMIN_REFRESH_EVENT = "gg-admin-refresh";

export function getStaff(): StaffSession | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(STAFF_KEY);
    if (!raw) return null;
    const s = JSON.parse(raw) as Partial<StaffSession> | null;
    if (!s || typeof s.pin !== "string" || typeof s.name !== "string" || !s.role) return null;
    if (!(Object.keys(STAFF_ROLES) as string[]).includes(s.role)) return null;
    return { name: s.name, role: s.role as StaffRole, pin: s.pin };
  } catch {
    return null;
  }
}

export function saveStaff(session: StaffSession): void {
  try {
    window.localStorage.setItem(STAFF_KEY, JSON.stringify(session));
  } catch {
    // تجاهل أخطاء التخزين
  }
}

export function clearStaff(): void {
  try {
    window.localStorage.removeItem(STAFF_KEY);
  } catch {
    // تجاهل
  }
}

/** يطلب من admin-app إعادة جلب لوحة المعلومات والإشعارات فورًا */
export function broadcastAdminRefresh(): void {
  window.dispatchEvent(new Event(ADMIN_REFRESH_EVENT));
}

// ───────── الأخطاء ─────────

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

// ───────── fetch الموحدة ─────────

interface RequestOpts {
  /** true = لا تعرض toast للأخطاء (للـ polling) */
  silent?: boolean;
}

async function request<T>(path: string, init?: RequestInit, opts?: RequestOpts): Promise<T> {
  const staff = getStaff();
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  const isLogin = path.startsWith("/api/admin/login");
  if (staff?.pin && !isLogin) headers["x-staff-pin"] = staff.pin;

  let res: Response;
  try {
    res = await fetch(path, { ...init, headers });
  } catch {
    if (!opts?.silent) {
      toast({
        title: "تعذر الاتصال بالخادم",
        description: "تحقق من الاتصال ثم حاول مجددًا",
        variant: "destructive",
      });
    }
    throw new ApiError("تعذر الاتصال بالخادم", 0);
  }

  if (!res.ok) {
    let msg = "حدث خطأ غير متوقع";
    try {
      const data = (await res.json()) as { error?: string } | null;
      if (data && typeof data.error === "string" && data.error) msg = data.error;
    } catch {
      // لا يوجد جسم للخطأ
    }
    // 401 خاص بالجلسة (رمز PIN غير صالح) → خروج تلقائي.
    // ملاحظة: الخادم يستخدم 401 أيضًا لرمز تسليم خاطئ — نميّزه عبر نص الرسالة.
    const isAuthExpiry =
      res.status === 401 && !isLogin && (msg.includes("PIN") || msg.includes("تسجيل دخول"));
    if (isAuthExpiry) {
      clearStaff();
      window.dispatchEvent(new Event(STAFF_UNAUTHORIZED_EVENT));
      if (!opts?.silent) {
        toast({
          title: "انتهت الجلسة",
          description: "رمز الدخول غير صالح — سجّل الدخول من جديد",
          variant: "destructive",
        });
      }
      throw new ApiError(msg || "انتهت الجلسة", 401);
    }
    if (!opts?.silent) {
      toast({ title: "تعذّر تنفيذ العملية", description: msg, variant: "destructive" });
    }
    throw new ApiError(msg, res.status);
  }

  try {
    return (await res.json()) as T;
  } catch {
    return {} as T;
  }
}

export const adminApi = {
  get: <T>(path: string, opts?: RequestOpts) => request<T>(path, { method: "GET" }, opts),
  post: <T>(path: string, body?: unknown, opts?: RequestOpts) =>
    request<T>(path, { method: "POST", body: JSON.stringify(body ?? {}) }, opts),
  patch: <T>(path: string, body?: unknown, opts?: RequestOpts) =>
    request<T>(path, { method: "PATCH", body: JSON.stringify(body ?? {}) }, opts),
};

/** دخول الموظف بالرمز — يعيد الجلسة ويحفظها في gg-staff */
export async function loginWithPin(pin: string): Promise<StaffSession> {
  const data = await adminApi.post<{ name?: string; role?: string }>(
    "/api/admin/login",
    { pin },
    { silent: true }
  );
  const role = (Object.keys(STAFF_ROLES) as string[]).includes(data.role ?? "")
    ? (data.role as StaffRole)
    : null;
  if (!data.name || !role) {
    throw new ApiError("استجابة دخول غير صالحة من الخادم", 500);
  }
  const session: StaffSession = { name: data.name, role, pin };
  saveStaff(session);
  return session;
}

// ───────── أدوات تطبيع الاستجابات (دفاعية ضد اختلاف أشكال الخادم) ─────────

export function listOf<T>(data: unknown, key: string): T[] {
  if (Array.isArray(data)) return data as T[];
  if (data && typeof data === "object") {
    const v = (data as Record<string, unknown>)[key];
    if (Array.isArray(v)) return v as T[];
  }
  return [];
}

function asStr(v: unknown): string | null {
  return typeof v === "string" && v ? v : null;
}

function asNum(v: unknown): number | null {
  return typeof v === "number" && Number.isFinite(v) ? v : null;
}

// ───────── أشكال خاصة بواجهة الإدارة ─────────

/** دفعة بانتظار التحقق (من لوحة المعلومات) */
export interface PendingPaymentDTO {
  paymentId: string;
  orderCode: string;
  customerName: string;
  phone?: string | null;
  amount: number;
  submittedAt: string | null;
  proofUrl: string | null;
  transactionRef: string | null;
  methodName?: string | null;
}

export interface DashboardDTO {
  today: {
    sales: number;
    orders: number;
    paidCount: number;
    pendingVerify: number;
    outForDelivery: number;
  };
  inventory: { activeBatches: number; lowStock: number; soldOut: number };
  recentOrders: OrderDTO[];
  pendingPayments: PendingPaymentDTO[];
}

export function normalizeDashboard(data: unknown): DashboardDTO | null {
  if (!data || typeof data !== "object") return null;
  const d = data as Record<string, unknown>;
  const today = (d.today ?? {}) as Record<string, unknown>;
  const inventory = (d.inventory ?? {}) as Record<string, unknown>;
  return {
    today: {
      sales: asNum(today.sales) ?? 0,
      orders: asNum(today.orders) ?? 0,
      paidCount: asNum(today.paidCount) ?? 0,
      pendingVerify: asNum(today.pendingVerify) ?? 0,
      outForDelivery: asNum(today.outForDelivery) ?? 0,
    },
    inventory: {
      activeBatches: asNum(inventory.activeBatches) ?? 0,
      lowStock: asNum(inventory.lowStock) ?? 0,
      soldOut: asNum(inventory.soldOut) ?? 0,
    },
    recentOrders: listOf<OrderDTO>(d.recentOrders, "recentOrders"),
    pendingPayments: listOf<unknown>(d.pendingPayments, "pendingPayments").map((p) => {
      const r = (p ?? {}) as Record<string, unknown>;
      return {
        paymentId: asStr(r.paymentId) ?? asStr(r.id) ?? "",
        orderCode: asStr(r.orderCode) ?? "",
        customerName: asStr(r.customerName) ?? "عميل",
        phone: asStr(r.phone),
        amount: asNum(r.amount) ?? 0,
        submittedAt: asStr(r.submittedAt),
        proofUrl: asStr(r.proofUrl) ?? asStr(r.proofDataUrl),
        transactionRef: asStr(r.transactionRef),
        methodName: asStr(r.methodName) ?? asStr(r.method),
      };
    }),
  };
}

/** دفعة قات ببيانات المخزون الكاملة (للإدارة) */
export interface AdminBatchDTO extends BatchCardDTO {
  totalQty?: number;
  reservedQty?: number;
  soldQty?: number;
  description?: string | null;
}

/** حركة مخزون */
export interface MovementDTO {
  id: string;
  type: "ADD" | "RESERVE" | "RELEASE" | "SOLD" | "ADJUST" | "CANCEL" | string;
  qty: number;
  batchCode?: string | null;
  productName?: string | null;
  note?: string | null;
  actor?: string | null;
  createdAt: string;
}

export function normalizeMovements(data: unknown): MovementDTO[] {
  return listOf<unknown>(data, "movements").map((m) => {
    const r = (m ?? {}) as Record<string, unknown>;
    const batch = (r.batch && typeof r.batch === "object" ? r.batch : {}) as Record<string, unknown>;
    return {
      id: asStr(r.id) ?? "",
      type: asStr(r.type) ?? "",
      qty: asNum(r.qty) ?? 0,
      batchCode: asStr(r.batchCode) ?? asStr(batch.batchCode),
      productName: asStr(r.productName) ?? asStr(batch.productName),
      note: asStr(r.note),
      actor: asStr(r.actor),
      createdAt: asStr(r.createdAt) ?? new Date().toISOString(),
    };
  });
}

/** مهمة توصيل موسعة ببيانات العميل والطلب */
export interface DeliveryTaskDTO {
  id: string;
  status: DeliveryStatus;
  driverName: string | null;
  otp: string | null;
  assignedAt: string | null;
  deliveredAt: string | null;
  failReason: string | null;
  orderCode: string;
  orderStatus: string | null;
  customerName: string;
  phone: string;
  zoneName: string | null;
  addressText: string;
  total: number;
  paymentStatus: string | null;
  createdAt: string | null;
}

export function normalizeDeliveryTasks(data: unknown): DeliveryTaskDTO[] {
  return listOf<unknown>(data, "deliveries")
    .map((t) => {
      const r = (t ?? {}) as Record<string, unknown>;
      const order = (r.order && typeof r.order === "object" ? r.order : {}) as Record<string, unknown>;
      return {
        id: asStr(r.id) ?? "",
        status: (asStr(r.status) ?? "WAITING") as DeliveryStatus,
        driverName: asStr(r.driverName),
        otp: asStr(r.otp),
        assignedAt: asStr(r.assignedAt),
        deliveredAt: asStr(r.deliveredAt),
        failReason: asStr(r.failReason),
        orderCode: asStr(r.orderCode) ?? asStr(order.orderCode) ?? "",
        orderStatus: asStr(r.orderStatus) ?? asStr(order.status),
        customerName: asStr(r.customerName) ?? asStr(order.customerName) ?? "عميل",
        phone: asStr(r.phone) ?? asStr(order.phone) ?? "",
        zoneName: asStr(r.zoneName) ?? asStr(order.zoneName),
        addressText: asStr(r.addressText) ?? asStr(order.addressText) ?? "",
        total: asNum(r.total) ?? asNum(order.total) ?? 0,
        paymentStatus: asStr(r.paymentStatus) ?? asStr(order.paymentStatus),
        createdAt: asStr(r.createdAt),
      };
    })
    .filter((t) => t.id);
}

/** عميل في القائمة */
export interface CustomerRowDTO {
  id: string;
  name: string;
  phone: string;
  ordersCount: number;
  totalSpent: number;
  lastOrderAt: string | null;
}

export function normalizeCustomers(data: unknown): CustomerRowDTO[] {
  return listOf<unknown>(data, "customers").map((c) => {
    const r = (c ?? {}) as Record<string, unknown>;
    return {
      id: asStr(r.id) ?? "",
      name: asStr(r.name) ?? "عميل",
      phone: asStr(r.phone) ?? "",
      ordersCount: asNum(r.ordersCount) ?? asNum(r.orders) ?? 0,
      totalSpent: asNum(r.totalSpent) ?? 0,
      lastOrderAt: asStr(r.lastOrderAt),
    };
  });
}

/** سجل تدقيق */
export interface AuditRowDTO {
  id: string;
  actorName: string;
  actorRole: string;
  action: string;
  entityType: string;
  entityId: string;
  before: string | null;
  after: string | null;
  createdAt: string;
}

export function normalizeAudit(data: unknown): AuditRowDTO[] {
  return listOf<unknown>(data, "logs").map((l) => {
    const r = (l ?? {}) as Record<string, unknown>;
    return {
      id: asStr(r.id) ?? "",
      actorName: asStr(r.actorName) ?? "غير معروف",
      actorRole: asStr(r.actorRole) ?? "",
      action: asStr(r.action) ?? "",
      entityType: asStr(r.entityType) ?? "",
      entityId: asStr(r.entityId) ?? "",
      before: asStr(r.before),
      after: asStr(r.after),
      createdAt: asStr(r.createdAt) ?? new Date().toISOString(),
    };
  });
}

/** تقارير */
export interface ReportsDTO {
  salesByDay: { date: string; total: number; orders: number }[];
  topBatches: {
    batchCode: string;
    productName: string;
    soldQty: number;
    revenue: number;
    avgRating: number | null;
  }[];
  gradeDistribution: { grade: string; count: number }[];
  repeatCustomers: number;
  totalCustomers: number;
  avgDeliveryMinutes: number | null;
}

export function normalizeReports(data: unknown): ReportsDTO | null {
  if (!data || typeof data !== "object") return null;
  const r = data as Record<string, unknown>;
  return {
    salesByDay: listOf<unknown>(r.salesByDay, "salesByDay").map((s) => {
      const x = (s ?? {}) as Record<string, unknown>;
      return {
        date: asStr(x.date) ?? "",
        total: asNum(x.total) ?? 0,
        orders: asNum(x.orders) ?? 0,
      };
    }),
    topBatches: listOf<unknown>(r.topBatches, "topBatches").map((b) => {
      const x = (b ?? {}) as Record<string, unknown>;
      return {
        batchCode: asStr(x.batchCode) ?? "",
        productName: asStr(x.productName) ?? "",
        soldQty: asNum(x.soldQty) ?? 0,
        revenue: asNum(x.revenue) ?? 0,
        avgRating: asNum(x.avgRating),
      };
    }),
    gradeDistribution: listOf<unknown>(r.gradeDistribution, "gradeDistribution").map((g) => {
      const x = (g ?? {}) as Record<string, unknown>;
      return { grade: asStr(x.grade) ?? "", count: asNum(x.count) ?? 0 };
    }),
    repeatCustomers: asNum(r.repeatCustomers) ?? 0,
    totalCustomers: asNum(r.totalCustomers) ?? 0,
    avgDeliveryMinutes: asNum(r.avgDeliveryMinutes),
  };
}

/** إشعار إدارة */
export interface AdminNotificationDTO {
  id: string;
  title: string;
  body: string;
  orderCode: string | null;
  read: boolean;
  createdAt: string;
}

export function normalizeNotifications(data: unknown): AdminNotificationDTO[] {
  return listOf<unknown>(data, "notifications").map((n) => {
    const r = (n ?? {}) as Record<string, unknown>;
    return {
      id: asStr(r.id) ?? "",
      title: asStr(r.title) ?? "",
      body: asStr(r.body) ?? "",
      orderCode: asStr(r.orderCode),
      read: r.read === true,
      createdAt: asStr(r.createdAt) ?? new Date().toISOString(),
    };
  });
}

// ───────── دوال مساعدة صغيرة ─────────

/** أرقام لاتينية مفصولة بفواصل */
export function formatNum(n: number): string {
  return new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 }).format(n);
}

/** رابط واتساب برسالة جاهزة (بدون رقم = مشاركة حرة) */
export function whatsappUrl(phone: string | null | undefined, text: string): string {
  const digits = (phone ?? "").replace(/[^0-9]/g, "").replace(/^0+/, "");
  const num = digits.length >= 9 ? `967${digits}`.slice(0, 15) : "";
  return num
    ? `https://wa.me/${num}?text=${encodeURIComponent(text)}`
    : `https://wa.me/?text=${encodeURIComponent(text)}`;
}

/** نسخ نص إلى الحافظة مع toast */
export async function copyText(text: string, label = "تم النسخ"): Promise<void> {
  try {
    await navigator.clipboard.writeText(text);
    toast({ title: label, description: text });
  } catch {
    toast({ title: "تعذر النسخ", description: "انسخ يدويًا: " + text, variant: "destructive" });
  }
}
