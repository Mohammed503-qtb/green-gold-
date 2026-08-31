"use client";

// ============================================================
// GREEN GOLD | التحقق من الدفعات — القلب المالي للنظام
// بطاقات بانتظار التحقق: إثبات + مرجع + تأكيد/رفض (سبب إجباري)
// ============================================================

import { useState } from "react";
import {
  CheckCircle2,
  XCircle,
  BadgeCheck,
  Hash,
  Clock,
  Loader2,
  ImageIcon,
  MessageCircle,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { toast } from "@/hooks/use-toast";
import { cn } from "@/lib/utils";
import {
  adminApi,
  broadcastAdminRefresh,
  whatsappUrl,
  type PendingPaymentDTO,
} from "./api";
import { EmptyState, LoadingRows, Money } from "./bits";
import { timeAgoArSafe } from "./dashboard";

interface PaymentsVerifierProps {
  payments: PendingPaymentDTO[];
  loading: boolean;
  onRefresh: () => void;
}

export function PaymentsVerifier({ payments, loading, onRefresh }: PaymentsVerifierProps) {
  const [approving, setApproving] = useState<PendingPaymentDTO | null>(null);
  const [rejecting, setRejecting] = useState<PendingPaymentDTO | null>(null);
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [proofUrl, setProofUrl] = useState<string | null>(null);

  const approve = async () => {
    if (!approving) return;
    setBusy(true);
    try {
      await adminApi.post(`/api/admin/payments/${approving.paymentId}/verify`, { approved: true });
      toast({
        title: "تم تأكيد الدفع ✅",
        description: `${approving.orderCode} — تحولت الكمية من محجوز إلى مباع وتأكد الطلب`,
      });
      setApproving(null);
      broadcastAdminRefresh();
      onRefresh();
    } catch {
      // toast من api.ts
    } finally {
      setBusy(false);
    }
  };

  const reject = async () => {
    if (!rejecting) return;
    if (reason.trim().length < 3) {
      setError("سبب الرفض إجباري (3 أحرف على الأقل)");
      return;
    }
    setBusy(true);
    try {
      await adminApi.post(`/api/admin/payments/${rejecting.paymentId}/verify`, {
        approved: false,
        reason: reason.trim(),
      });
      toast({
        title: "تم رفض الدفع",
        description: `${rejecting.orderCode} — حُررت الكميات المحجوزة وأُعيد الطلب لرفض الدفع`,
      });
      setRejecting(null);
      setReason("");
      setError(null);
      broadcastAdminRefresh();
      onRefresh();
    } catch {
      // toast من api.ts
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-extrabold">التحقق من الدفعات</h2>
          <p className="text-muted-foreground text-xs">
            كل تأكيد يحوّل الكمية من «محجوز» إلى «مباع» ويؤكد الطلب تلقائيًا — تُحدَّث القائمة كل 15 ثانية.
          </p>
        </div>
        <Badge variant="outline" className="border-amber-200 bg-amber-100 text-amber-800 dark:border-amber-900 dark:bg-amber-500/15">
          {payments.length} بانتظار التحقق
        </Badge>
      </div>

      {loading && payments.length === 0 ? (
        <LoadingRows rows={3} />
      ) : payments.length === 0 ? (
        <EmptyState
          title="لا توجد دفعات بانتظار التحقق ✅"
          sub="ستظهر هنا فورًا كل إثباتات الدفع التي يرسلها العملاء"
          icon={BadgeCheck}
        />
      ) : (
        <ul className="grid gap-3 lg:grid-cols-2" aria-label="دفعات بانتظار التحقق">
          {payments.map((p) => (
            <li
              key={p.paymentId}
              className="space-y-3 rounded-xl border p-4 shadow-sm"
            >
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="truncate text-sm font-extrabold">{p.customerName}</p>
                  <p className="font-mono text-xs text-muted-foreground" dir="ltr">
                    {p.orderCode}
                  </p>
                </div>
                <Money amount={p.amount} className="text-primary shrink-0 text-lg" />
              </div>

              <div className="flex flex-wrap gap-1.5">
                {p.methodName ? (
                  <Badge variant="secondary" className="text-[11px]">{p.methodName}</Badge>
                ) : null}
                {p.transactionRef ? (
                  <Badge variant="outline" className="gap-1 font-mono text-[11px]" dir="ltr">
                    <Hash className="size-3" aria-hidden="true" />
                    {p.transactionRef}
                  </Badge>
                ) : null}
                <Badge variant="outline" className="gap-1 text-[11px] text-muted-foreground">
                  <Clock className="size-3" aria-hidden="true" />
                  {p.submittedAt ? timeAgoArSafe(p.submittedAt) : "—"}
                </Badge>
                {p.phone ? (
                  <Badge variant="outline" className="gap-1 font-mono text-[11px]" dir="ltr">
                    <MessageCircle className="size-3" aria-hidden="true" />
                    {p.phone}
                  </Badge>
                ) : null}
              </div>

              {p.proofUrl ? (
                <button
                  onClick={() => setProofUrl(p.proofUrl)}
                  className="block w-full overflow-hidden rounded-lg border transition hover:shadow-md"
                  aria-label={`تكبير إثبات الدفع للطلب ${p.orderCode}`}
                >
                  <img
                    src={p.proofUrl}
                    alt={`إثبات دفع ${p.customerName} — ${p.orderCode}`}
                    loading="lazy"
                    className="h-32 w-full object-cover"
                  />
                </button>
              ) : (
                <div className="text-muted-foreground flex h-20 items-center justify-center gap-2 rounded-lg border border-dashed text-xs">
                  <ImageIcon className="size-4" aria-hidden="true" />
                  لا توجد صورة إثبات — تحقق من رقم العملية
                </div>
              )}

              <div className="flex gap-2">
                <Button
                  className="flex-1 bg-emerald-700 font-bold hover:bg-emerald-800 dark:bg-emerald-600 dark:hover:bg-emerald-700"
                  onClick={() => setApproving(p)}
                >
                  <CheckCircle2 className="size-4" aria-hidden="true" />
                  تأكيد الدفع
                </Button>
                <Button
                  variant="outline"
                  className="flex-1 border-red-200 font-bold text-red-600 hover:bg-red-50 hover:text-red-700 dark:border-red-900 dark:text-red-400"
                  onClick={() => {
                    setReason("");
                    setError(null);
                    setRejecting(p);
                  }}
                >
                  <XCircle className="size-4" aria-hidden="true" />
                  رفض
                </Button>
              </div>
            </li>
          ))}
        </ul>
      )}

      {/* تأكيد القبول */}
      <AlertDialog open={!!approving} onOpenChange={(o) => !o && setApproving(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>تأكيد استلام الدفع؟</AlertDialogTitle>
            <AlertDialogDescription asChild>
              <div className="space-y-1.5 pt-1 leading-relaxed">
                <p>
                  الطلب <span className="font-mono font-bold" dir="ltr">{approving?.orderCode}</span> —{" "}
                  {approving?.customerName} بمبلغ{" "}
                  {approving ? <Money amount={approving.amount} className="text-primary" /> : null}.
                </p>
                <p className="rounded-lg border border-amber-200 bg-amber-50 p-2 text-xs font-semibold text-amber-800 dark:border-amber-900 dark:bg-amber-500/10 dark:text-amber-400">
                  ⚠️ سيتم تحويل الكمية من «محجوز» إلى «مباع» نهائيًا، وتأكيد الطلب، وإخطار العميل. يُسجَّل التحقق باسمك في سجل التدقيق.
                </p>
              </div>
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={busy}>تراجع</AlertDialogCancel>
            <AlertDialogAction
              disabled={busy}
              className="bg-emerald-700 text-white hover:bg-emerald-800 dark:bg-emerald-600"
              onClick={(e) => {
                e.preventDefault();
                void approve();
              }}
            >
              {busy ? <Loader2 className="size-4 animate-spin" aria-hidden="true" /> : <CheckCircle2 className="size-4" aria-hidden="true" />}
              نعم، تأكيد الدفع
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* الرفض بسبب إجباري */}
      <Dialog open={!!rejecting} onOpenChange={(o) => !o && setRejecting(null)}>
        <DialogContent className="max-w-md sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="text-red-600">رفض الدفع</DialogTitle>
            <DialogDescription>
              الطلب <span className="font-mono font-bold" dir="ltr">{rejecting?.orderCode}</span> — {rejecting?.customerName}.
              سيتم تحرير الكميات المحجوزة وإعادة الطلب إلى «مرفوض الدفع» مع إخطار العميل بالسبب.
            </DialogDescription>
          </DialogHeader>
          <div>
            <label htmlFor="reject-reason" className="mb-1.5 block text-sm font-bold">
              سبب الرفض <span className="text-red-600">*</span>
            </label>
            <Textarea
              id="reject-reason"
              value={reason}
              onChange={(e) => {
                setReason(e.target.value);
                if (error) setError(null);
              }}
              placeholder="مثال: رقم العملية غير مطابق للمبلغ المحوَّل…"
              rows={3}
              aria-invalid={!!error}
              className={cn(error && "border-red-400 focus-visible:ring-red-300")}
            />
            {error ? (
              <p className="mt-1.5 text-xs font-bold text-red-600" role="alert">
                {error}
              </p>
            ) : null}
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" disabled={busy} onClick={() => setRejecting(null)}>
              تراجع
            </Button>
            <Button variant="destructive" disabled={busy} onClick={() => void reject()}>
              {busy ? <Loader2 className="size-4 animate-spin" aria-hidden="true" /> : <XCircle className="size-4" aria-hidden="true" />}
              رفض نهائي
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* تكبير الإثبات */}
      <Dialog open={!!proofUrl} onOpenChange={(o) => !o && setProofUrl(null)}>
        <DialogContent className="max-w-lg sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>إثبات الدفع (مكبرة)</DialogTitle>
          </DialogHeader>
          {proofUrl ? (
            <img
              src={proofUrl}
              alt="صورة إثبات الدفع مكبرة"
              className="max-h-[70vh] w-full rounded-xl border object-contain bg-muted"
            />
          ) : null}
          {rejecting?.phone ? (
            <Button variant="outline" asChild>
              <a
                href={whatsappUrl(
                  rejecting.phone,
                  `مرحبًا ${rejecting.customerName}، بخصوص دفع طلبك ${rejecting.orderCode} من ذهب أخضر 🌿`
                )}
                target="_blank"
                rel="noreferrer"
              >
                <MessageCircle className="size-4" aria-hidden="true" /> تواصل مع العميل
              </a>
            </Button>
          ) : null}
        </DialogContent>
      </Dialog>
    </div>
  );
}
