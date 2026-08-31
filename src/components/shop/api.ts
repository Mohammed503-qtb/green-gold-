// ============================================================
// GREEN GOLD | واجهة العميل — طبقة الـ API الموحدة
// كل الطلبات مسارات نسبية، مع معالجة أخطاء عربية + toast
// ============================================================
import { toast } from "@/hooks/use-toast";
import type {
  BatchCardDTO,
  Grade,
  OrderDTO,
  PaymentMethodDTO,
  Smiley,
  ZoneDTO,
} from "@/lib/contracts";

// ───────── الأنواع ─────────

export interface BatchReviewDTO {
  rating: number;
  smiley: Smiley;
  matchedPhotos: boolean | null;
  comment: string | null;
  createdAt: string;
  customerName: string | null;
}

export interface BatchDetailDTO extends BatchCardDTO {
  description: string | null;
  productOrigin: string | null;
  reviews: BatchReviewDTO[];
}

export interface CheckoutDataDTO {
  zones: ZoneDTO[];
  methods: PaymentMethodDTO[];
  storeName: string | null;
  whatsapp: string | null;
}

export interface PublicSettingsDTO {
  storeName: string | null;
  whatsapp: string | null;
}

export interface CreateOrderPayload {
  customer: { name: string; phone: string };
  address: { zoneId: string; addressText: string; notes?: string; label?: string };
  items: { batchId: string; qty: number }[];
  note?: string;
}

export interface SubmitPaymentPayload {
  phone: string;
  methodId: string;
  transactionRef?: string;
  proofDataUrl?: string;
}

export interface SubmitReviewPayload {
  orderCode: string;
  phone: string;
  rating: number;
  smiley: Smiley;
  matchedPhotos?: boolean;
  comment?: string;
}

export type CatalogSort = "newest" | "popular" | "price_asc" | "price_desc";

export type ApiResult<T> = { ok: true; data: T } | { ok: false; error: string };

// ───────── النواة ─────────

async function request<T>(
  path: string,
  init?: RequestInit & { silent?: boolean }
): Promise<ApiResult<T>> {
  const silent = init?.silent === true;
  try {
    const res = await fetch(path, {
      cache: "no-store",
      ...init,
      headers: { "Content-Type": "application/json", ...(init?.headers ?? {}) },
    });
    let body: unknown = null;
    try {
      body = await res.json();
    } catch {
      /* جسم فارغ */
    }
    if (!res.ok) {
      const error =
        (body as { error?: string } | null)?.error ?? "حدث خطأ غير متوقع، حاول مرة أخرى";
      if (!silent) {
        toast({
          title: res.status >= 500 ? "خطأ في الخادم" : "تنبيه",
          description: error,
          variant: res.status >= 400 ? "destructive" : "default",
        });
      }
      return { ok: false, error };
    }
    return { ok: true, data: body as T };
  } catch {
    const error = "تعذر الاتصال بالخادم، تحقق من اتصالك بالإنترنت";
    if (!silent) {
      toast({ title: "انقطاع الاتصال", description: error, variant: "destructive" });
    }
    return { ok: false, error };
  }
}

// ───────── الدفعات والكتالوج ─────────

export async function fetchCatalog(params?: {
  grade?: Grade;
  search?: string;
  sort?: CatalogSort;
}): Promise<BatchCardDTO[] | null> {
  const q = new URLSearchParams();
  if (params?.grade) q.set("grade", params.grade);
  if (params?.search?.trim()) q.set("search", params.search.trim());
  if (params?.sort) q.set("sort", params.sort);
  const qs = q.toString();
  const r = await request<{ batches: BatchCardDTO[] }>(`/api/catalog${qs ? `?${qs}` : ""}`);
  return r.ok ? (r.data.batches ?? []) : null;
}

export async function fetchBatch(id: string): Promise<BatchDetailDTO | null> {
  const r = await request<{ batch: BatchDetailDTO }>(`/api/batches/${encodeURIComponent(id)}`);
  return r.ok ? r.data.batch : null;
}

// ───────── بيانات الشراء والإعدادات ─────────

export async function fetchCheckoutData(): Promise<CheckoutDataDTO | null> {
  const r = await request<CheckoutDataDTO>("/api/checkout-data");
  return r.ok ? r.data : null;
}

export async function fetchPublicSettings(): Promise<PublicSettingsDTO | null> {
  const r = await request<PublicSettingsDTO>("/api/settings/public");
  return r.ok ? r.data : null;
}

// ───────── الطلبات ─────────

/** يعيد الطلب عند النجاح، أو null (مع toast عربي) عند الفشل (مثل نفاد الكمية 409) */
export async function createOrder(payload: CreateOrderPayload): Promise<OrderDTO | null> {
  const r = await request<{ order: OrderDTO }>("/api/orders", {
    method: "POST",
    body: JSON.stringify(payload),
  });
  return r.ok ? r.data.order : null;
}

export async function fetchOrdersByPhone(phone: string): Promise<OrderDTO[] | null> {
  const r = await request<{ orders: OrderDTO[] }>(
    `/api/orders?phone=${encodeURIComponent(phone)}`
  );
  return r.ok ? (r.data.orders ?? []) : null;
}

export async function fetchOrderByCode(code: string, phone: string): Promise<OrderDTO | null> {
  const r = await request<{ order: OrderDTO }>(
    `/api/orders/${encodeURIComponent(code)}?phone=${encodeURIComponent(phone)}`
  );
  return r.ok ? r.data.order : null;
}

/** إرسال/إرفاق إثبات الدفع — يعيد الطلب المحدّث */
export async function submitPayment(
  code: string,
  payload: SubmitPaymentPayload
): Promise<OrderDTO | null> {
  const r = await request<{ order: OrderDTO }>(
    `/api/orders/${encodeURIComponent(code)}/payment`,
    { method: "POST", body: JSON.stringify(payload) }
  );
  return r.ok ? r.data.order : null;
}

/** تقييم طلب مُسلَّم — يعيد true عند النجاح */
export async function submitReview(payload: SubmitReviewPayload): Promise<boolean> {
  const r = await request<{ ok: boolean }>("/api/reviews", {
    method: "POST",
    body: JSON.stringify(payload),
  });
  return r.ok;
}
