// ============================================================
// GREEN GOLD | ذهب أخضر — منطق الخادم المشترك
// يُستخدم من كل route handlers تحت src/app/api/**
// ============================================================
import { NextRequest, NextResponse } from "next/server";
import { Prisma, PrismaClient, Payment, DeliveryOrder } from "@prisma/client";
import { db } from "@/lib/db";
import {
  CAN,
  LOW_STOCK_THRESHOLD,
  RESERVATION_MINUTES,
  type BatchCardDTO,
  type DeliveryDTO,
  type Grade,
  type OrderDTO,
  type OrderItemDTO,
  type OrderStatus,
  type PaymentDTO,
  type PaymentType,
} from "@/lib/contracts";

// ───────────────────────── هوية الموظف ─────────────────────────

export interface StaffIdentity {
  name: string;
  role: string;
}

/** يقرأ x-staff-pin ويتحقق منه مقابل StaffUser — يعيد {name, role} أو null */
export async function getStaffFromRequest(req: NextRequest): Promise<StaffIdentity | null> {
  const pin = req.headers.get("x-staff-pin")?.trim();
  if (!pin) return null;
  const staff = await db.staffUser.findFirst({ where: { pin, active: true } });
  if (!staff) return null;
  return { name: staff.name, role: staff.role };
}

/**
 * يفرض وجود موظف + صلاحية معينة وفق CAN في contracts.ts
 * يرمي ApiError(401/403) عند الفشل.
 */
export async function requireStaff(
  req: NextRequest,
  permissionKey?: keyof typeof CAN
): Promise<StaffIdentity> {
  const staff = await getStaffFromRequest(req);
  if (!staff) throw new ApiError("يلزم تسجيل دخول الموظف (PIN)", 401);
  if (permissionKey) {
    const allowed = CAN[permissionKey] as readonly string[];
    if (!allowed.includes(staff.role)) {
      throw new ApiError("لا تملك صلاحية تنفيذ هذا الإجراء", 403);
    }
  }
  return staff;
}

// ───────────────────────── الأخطاء الموحدة ─────────────────────────

export class ApiError extends Error {
  status: number;
  constructor(message: string, status = 400) {
    super(message);
    this.status = status;
  }
}

/** يحوّل أي خطأ إلى استجابة {error:"رسالة عربية"} مع status مناسب */
export function fail(e: unknown): NextResponse {
  if (e instanceof ApiError) {
    return NextResponse.json({ error: e.message }, { status: e.status });
  }
  const message = e instanceof Error ? e.message : "حدث خطأ غير متوقع";
  return NextResponse.json({ error: `حدث خطأ: ${message}` }, { status: 500 });
}

export function ok(data: unknown, status = 200): NextResponse {
  return NextResponse.json(data, { status });
}

// ───────────────────────── المخزون ─────────────────────────

export function computeAvailable(batch: {
  totalQty: number;
  reservedQty: number;
  soldQty: number;
}): number {
  return Math.max(0, batch.totalQty - batch.reservedQty - batch.soldQty);
}

/**
 * تحرير الحجوزات المنتهية (مهلة الدفع 30 دقيقة) — تُستدعى "lazy"
 * عند إنشاء طلب جديد أو فتح الكاتالوج أو تفاصيل دفعة.
 *
 * ملاحظة معمارية: InventoryReservation مرتبطة بالطلب (orderId فريد)
 * لكن الطلب قد يحوي أصنافًا من عدة دفعات — لذلك صف الحجز هو "علامة"
 * على الطلب كاملًا (batchId = أول صنف، qty = مجموع الكميات)
 * بينما محاسبة reservedQty لكل دفعة تُشتق من order.items الفعلية.
 */
export async function releaseExpiredReservations(actor = "SYSTEM"): Promise<number> {
  const now = new Date();
  const expired = await db.inventoryReservation.findMany({
    where: { status: "ACTIVE", expiresAt: { lt: now } },
    include: { order: { include: { items: true } } },
  });
  for (const r of expired) {
    await db.$transaction(async (tx) => {
      await tx.inventoryReservation.update({
        where: { id: r.id },
        data: { status: "RELEASED" },
      });
      for (const item of r.order.items) {
        await tx.productBatch.update({
          where: { id: item.batchId },
          data: { reservedQty: { decrement: item.qty } },
        });
        await tx.inventoryMovement.create({
          data: {
            batchId: item.batchId,
            qty: -item.qty,
            type: "RELEASE",
            orderId: r.orderId,
            note: "انتهت مهلة الدفع وتحرر الحجز",
            actor,
          },
        });
      }
      if (r.order.status === "PENDING_PAYMENT" || r.order.status === "PAYMENT_SUBMITTED") {
        await tx.order.update({
          where: { id: r.orderId },
          data: { status: "CANCELLED" },
        });
        await tx.orderStatusHistory.create({
          data: {
            orderId: r.orderId,
            fromStatus: r.order.status,
            toStatus: "CANCELLED",
            actor,
            note: "أُلغي الطلب تلقائيًا لعدم إتمام الدفع في الوقت المحدد",
          },
        });
        await tx.notification.create({
          data: {
            audience: "CUSTOMER",
            title: "انتهت مهلة الدفع",
            body: `انتهت مهلة دفع الطلب ${r.order.orderCode} وأُلغي تلقائيًا. يمكنك إنشاء طلب جديد في أي وقت.`,
            orderCode: r.order.orderCode,
          },
        });
      }
    });
  }
  return expired.length;
}

/** الحالات التي تعني أن الطلب مدفوع فعلًا (بعد تحقق الإدارة) */
export const PAID_ORDER_STATUSES: OrderStatus[] = [
  "CONFIRMED",
  "PREPARING",
  "READY_FOR_DELIVERY",
  "OUT_FOR_DELIVERY",
  "DELIVERED",
  "FAILED_DELIVERY",
  "REFUNDED",
];

/**
 * بعد أي تغيير مخزون: SOLD_OUT تلقائي عند نفاد المتاح + إشعار،
 * وإشعار مخزون منخفض عند عبور العتبة.
 */
export async function syncBatchStockState(
  tx: Prisma.TransactionClient,
  batchId: string,
  opts?: { wasAvailable?: number; actor?: string }
): Promise<void> {
  const batch = await tx.productBatch.findUnique({ where: { id: batchId } });
  if (!batch) return;
  const available = computeAvailable(batch);
  if (available <= 0 && batch.status !== "SOLD_OUT" && batch.status !== "CLOSED") {
    await tx.productBatch.update({ where: { id: batchId }, data: { status: "SOLD_OUT" } });
    await tx.notification.create({
      data: {
        audience: "ADMIN",
        title: "انتهت الدفعة",
        body: `نفدت الكمية المتاحة للدفعة ${batch.batchCode} وحُوّلت تلقائيًا إلى "نافدة".`,
      },
    });
    return;
  }
  const wasAvailable = opts?.wasAvailable ?? available + 1;
  if (
    available > 0 &&
    available <= LOW_STOCK_THRESHOLD &&
    wasAvailable > LOW_STOCK_THRESHOLD &&
    batch.status === "ACTIVE"
  ) {
    await tx.notification.create({
      data: {
        audience: "ADMIN",
        title: "مخزون منخفض",
        body: `تبقت ${available} حزم فقط من الدفعة ${batch.batchCode}.`,
      },
    });
  }
}

// ───────────────────────── DTOs ─────────────────────────

export const BATCH_INCLUDE = {
  product: true,
  media: { orderBy: { sort: "asc" as const } },
  quality: true,
  orderItems: { select: { qty: true, order: { select: { status: true } } } },
  reviews: { select: { rating: true } },
} satisfies Prisma.ProductBatchInclude;

export type BatchWithRelations = Prisma.ProductBatchGetPayload<{ include: typeof BATCH_INCLUDE }>;

/** بطاقة دفعة للعرض — يحسب soldCount/avgRating من العلاقات */
export function batchToCardDTO(batch: BatchWithRelations): BatchCardDTO & {
  totalQty: number;
  reservedQty: number;
  soldQty: number;
  createdAt: string;
} {
  const images = batch.media.filter((m) => m.type === "IMAGE");
  const main = images.find((m) => m.isMain) ?? images[0] ?? null;
  const video = batch.media.find((m) => m.type === "VIDEO") ?? null;
  const soldCount = batch.orderItems
    .filter((i) => PAID_ORDER_STATUSES.includes(i.order.status as OrderStatus))
    .reduce((s, i) => s + i.qty, 0);
  const ratings = batch.reviews.map((r) => r.rating);
  const avgRating = ratings.length
    ? Math.round((ratings.reduce((s, r) => s + r, 0) / ratings.length) * 10) / 10
    : null;
  return {
    id: batch.id,
    batchCode: batch.batchCode,
    productId: batch.productId,
    productName: batch.product.name,
    grade: batch.grade as Grade,
    price: batch.price,
    availableQty: computeAvailable(batch),
    status: batch.status as BatchCardDTO["status"],
    capturedAt: batch.capturedAt.toISOString(),
    mainImage: main?.url ?? null,
    images: images.map((m) => m.url),
    video: video?.url ?? null,
    quality: batch.quality
      ? {
          freshness: batch.quality.freshness,
          density: batch.quality.density,
          fullness: batch.quality.fullness,
          appearance: batch.quality.appearance,
        }
      : null,
    soldCount,
    avgRating,
    reviewsCount: batch.reviews.length,
    // حقول إضافية للإدارة/المخزون
    totalQty: batch.totalQty,
    reservedQty: batch.reservedQty,
    soldQty: batch.soldQty,
    createdAt: batch.createdAt.toISOString(),
  };
}

export const ORDER_INCLUDE = {
  items: true,
  payments: true,
  delivery: true,
  history: { orderBy: { createdAt: "asc" as const } },
  zone: true,
} satisfies Prisma.OrderInclude;

export type OrderWithRelations = Prisma.OrderGetPayload<{ include: typeof ORDER_INCLUDE }>;

function paymentToDTO(payment: Payment): PaymentDTO | null {
  let snapshot: { name?: string; type?: string } = {};
  try {
    snapshot = JSON.parse(payment.methodSnapshot || "{}");
  } catch {
    snapshot = {};
  }
  return {
    id: payment.id,
    status: payment.status as PaymentDTO["status"],
    amount: payment.amount,
    methodSnapshot:
      snapshot && (snapshot.name || snapshot.type)
        ? { name: snapshot.name ?? "", type: (snapshot.type ?? "COD") as PaymentType }
        : null,
    transactionRef: payment.transactionRef,
    proofUrl: payment.proofUrl,
    submittedAt: payment.submittedAt?.toISOString() ?? null,
    verifiedAt: payment.verifiedAt?.toISOString() ?? null,
    rejectReason: payment.rejectReason,
  };
}

function deliveryToDTO(delivery: DeliveryOrder | null): DeliveryDTO | null {
  if (!delivery) return null;
  return {
    id: delivery.id,
    status: delivery.status as DeliveryDTO["status"],
    driverName: delivery.driverName,
    otp: delivery.otp,
    assignedAt: delivery.assignedAt?.toISOString() ?? null,
    deliveredAt: delivery.deliveredAt?.toISOString() ?? null,
  };
}

/** طلب واحد → OrderDTO (يتحقق من وجود تقييم) */
export async function orderToDTO(order: OrderWithRelations): Promise<OrderDTO> {
  const review = await db.review.findUnique({ where: { orderId: order.id } });
  return singleOrderToDTO(order, !!review);
}

/** قائمة طلبات → OrderDTO[] (تقييماتها تُجلب دفعة واحدة) */
export async function ordersToDTOs(orders: OrderWithRelations[]): Promise<OrderDTO[]> {
  if (orders.length === 0) return [];
  const reviews = await db.review.findMany({
    where: { orderId: { in: orders.map((o) => o.id) } },
    select: { orderId: true },
  });
  const reviewedIds = new Set(reviews.map((r) => r.orderId));
  return orders.map((o) => singleOrderToDTO(o, reviewedIds.has(o.id)));
}

function singleOrderToDTO(order: OrderWithRelations, reviewed: boolean): OrderDTO {
  const payment = order.payments.length ? order.payments[order.payments.length - 1] : null;
  return {
    id: order.id,
    orderCode: order.orderCode,
    status: order.status as OrderStatus,
    itemsTotal: order.itemsTotal,
    deliveryFee: order.deliveryFee,
    discount: order.discount,
    total: order.total,
    customerName: order.customerName,
    phone: order.phone,
    addressText: order.addressText,
    zoneName: order.zone?.name ?? null,
    note: order.note,
    createdAt: order.createdAt.toISOString(),
    items: order.items.map(
      (it): OrderItemDTO => ({
        id: it.id,
        batchId: it.batchId,
        productName: it.productName,
        batchCode: it.batchCode,
        grade: it.grade as Grade,
        unitPrice: it.unitPrice,
        qty: it.qty,
        lineTotal: it.lineTotal,
        mainImage: it.mainImage,
      })
    ),
    payment: payment ? paymentToDTO(payment) : null,
    delivery: deliveryToDTO(order.delivery),
    history: order.history.map((h) => ({
      fromStatus: h.fromStatus,
      toStatus: h.toStatus,
      actor: h.actor,
      note: h.note,
      createdAt: h.createdAt.toISOString(),
    })),
    reviewed,
  };
}

// ───────────────────────── أدوات توليد ─────────────────────────

/** كود طلب فريد: ZG- + 6 أرقام */
export async function generateOrderCode(tx: Prisma.TransactionClient): Promise<string> {
  for (let i = 0; i < 25; i++) {
    const code = `ZG-${Math.floor(100000 + Math.random() * 900000)}`;
    const exists = await tx.order.findUnique({ where: { orderCode: code } });
    if (!exists) return code;
  }
  throw new ApiError("تعذر توليد رقم الطلب، حاول مرة أخرى", 500);
}

/** OTP تسليم من 4 أرقام */
export function generateOtp(): string {
  return String(Math.floor(1000 + Math.random() * 9000));
}

/** حرفا رمز الدفعة حسب اسم المنتج (تحويل عربي→لاتيني) */
const PRODUCT_PREFIXES: Record<string, string> = {
  "حراز": "HZ",
  "حمادي": "HM",
  "العنسي": "AN",
  "جبل أرحب": "JA",
  "ويلة": "WL",
};

export function productPrefix(productName: string): string {
  return PRODUCT_PREFIXES[productName.trim()] ?? "XX";
}

/** رمز دفعة: {PREFIX}-YYYYMMDD-NN بتسلسل يومي */
export async function generateBatchCode(
  tx: Prisma.TransactionClient,
  productName: string,
  date = new Date()
): Promise<string> {
  const prefix = productPrefix(productName);
  const ymd = [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, "0"),
    String(date.getDate()).padStart(2, "0"),
  ].join("");
  const stem = `${prefix}-${ymd}-`;
  const count = await tx.productBatch.count({ where: { batchCode: { startsWith: stem } } });
  return `${stem}${String(count + 1).padStart(2, "0")}`;
}

// ───────────────────────── سجل التدقيق والإشعارات ─────────────────────────

export async function logAudit(
  actor: StaffIdentity | null,
  action: string,
  entityType: string,
  entityId: string,
  before?: unknown,
  after?: unknown
): Promise<void> {
  await db.auditLog.create({
    data: {
      actorName: actor?.name ?? "SYSTEM",
      actorRole: actor?.role ?? "SYSTEM",
      action,
      entityType,
      entityId,
      before: before === undefined ? null : JSON.stringify(before),
      after: after === undefined ? null : JSON.stringify(after),
    },
  });
}

export async function notify(
  audience: "ADMIN" | "CUSTOMER",
  title: string,
  body: string,
  orderCode?: string
): Promise<void> {
  await db.notification.create({
    data: { audience, title, body, orderCode: orderCode ?? null },
  });
}

// ───────────────────────── إعدادات ─────────────────────────

export async function getPublicSettings(): Promise<{ storeName: string; whatsapp: string }> {
  const rows = await db.setting.findMany({ where: { key: { in: ["storeName", "whatsapp"] } } });
  const map = new Map(rows.map((r) => [r.key, r.value]));
  return {
    storeName: map.get("storeName") ?? "ذهب أخضر",
    whatsapp: map.get("whatsapp") ?? "",
  };
}
