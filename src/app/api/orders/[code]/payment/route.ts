// POST /api/orders/[code]/payment — إرسال إثبات الدفع (العميل لا يجعل الدفع PAID أبدًا)
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { ApiError, ORDER_INCLUDE, fail, ok, orderToDTO } from "@/lib/server";

interface PaymentInput {
  phone?: string;
  methodId?: string;
  transactionRef?: string;
  proofDataUrl?: string;
}

export async function POST(req: NextRequest, { params }: { params: Promise<{ code: string }> }) {
  try {
    const { code } = await params;
    const body = (await req.json().catch(() => null)) as PaymentInput | null;
    if (!body) throw new ApiError("بيانات الدفع غير صحيحة", 400);

    const phone = (body.phone ?? "").trim();
    const transactionRef = body.transactionRef?.trim() || null;
    const proofDataUrl = body.proofDataUrl?.trim() || null;

    const order = await db.order.findUnique({
      where: { orderCode: code },
      include: { payments: true },
    });
    if (!order) throw new ApiError("الطلب غير موجود", 404);
    if (!phone || order.phone !== phone)
      throw new ApiError("رقم الهاتف لا يطابق هذا الطلب", 403);
    if (order.status === "PAYMENT_SUBMITTED")
      throw new ApiError("تم إرسال إثبات الدفع مسبقًا وهو قيد التحقق", 409);
    if (order.status !== "PENDING_PAYMENT")
      throw new ApiError("لا يمكن إرسال الدفع في حالة الطلب الحالية", 409);

    const method = await db.paymentMethod.findFirst({
      where: { id: body.methodId ?? "", active: true },
    });
    if (!method) throw new ApiError("طريقة الدفع غير متوفرة", 404);

    const isCod = method.type === "COD";
    if (!isCod && !transactionRef && !proofDataUrl) {
      throw new ApiError("أرفق رقم عملية التحويل أو صورة الإثبات", 400);
    }
    if (isCod && transactionRef) {
      throw new ApiError("الدفع عند الاستلام لا يتطلب رقم عملية", 400);
    }

    const methodSnapshot = JSON.stringify({
      id: method.id,
      name: method.name,
      type: method.type,
      accountName: method.accountName,
      institution: method.institution,
      accountNumber: method.accountNumber,
    });

    const payment = order.payments[order.payments.length - 1];

    await db.$transaction(async (tx) => {
      if (payment) {
        await tx.payment.update({
          where: { id: payment.id },
          data: {
            methodId: method.id,
            methodSnapshot,
            status: "PENDING_VERIFICATION",
            transactionRef,
            proofUrl: proofDataUrl,
            submittedAt: new Date(),
            rejectReason: null,
          },
        });
      } else {
        await tx.payment.create({
          data: {
            orderId: order.id,
            methodId: method.id,
            methodSnapshot,
            amount: order.total,
            status: "PENDING_VERIFICATION",
            transactionRef,
            proofUrl: proofDataUrl,
            submittedAt: new Date(),
          },
        });
      }
      await tx.order.update({
        where: { id: order.id },
        data: { status: "PAYMENT_SUBMITTED" },
      });
      await tx.orderStatusHistory.create({
        data: {
          orderId: order.id,
          fromStatus: "PENDING_PAYMENT",
          toStatus: "PAYMENT_SUBMITTED",
          actor: "CUSTOMER",
          note: isCod ? "الدفع عند الاستلام" : `إثبات دفع عبر ${method.name}`,
        },
      });
      await tx.notification.create({
        data: {
          audience: "ADMIN",
          title: "إثبات دفع بانتظار التحقق",
          body: `الطلب ${order.orderCode} من ${order.customerName} — بانتظار تحقق الإدارة${
            transactionRef ? ` (مرجع: ${transactionRef})` : ""
          }.`,
          orderCode: order.orderCode,
        },
      });
    });

    const fresh = await db.order.findUnique({
      where: { id: order.id },
      include: ORDER_INCLUDE,
    });
    return ok({ order: await orderToDTO(fresh!) });
  } catch (e) {
    return fail(e);
  }
}
