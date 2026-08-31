"use client";

// ============================================================
// GREEN GOLD | العملاء — قائمة + ملف كامل (طلبات + تقييمات)
// ============================================================

import { useCallback, useEffect, useState } from "react";
import {
  Search,
  Users,
  Phone,
  MessageCircle,
  ShoppingBag,
  Star,
  RefreshCw,
  ChevronLeft,
  Heart,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Separator } from "@/components/ui/separator";
import { toast } from "@/hooks/use-toast";
import {
  SMILEYS,
  type OrderDTO,
  type Smiley,
} from "@/lib/contracts";
import {
  adminApi,
  formatNum,
  normalizeCustomers,
  whatsappUrl,
  type CustomerRowDTO,
} from "./api";
import { EmptyState, LoadingRows, Money, OrderStatusBadge, useDebounce } from "./bits";
import { timeAgoArSafe } from "./dashboard";

interface CustomerReview {
  id?: string;
  rating: number;
  smiley: string;
  comment: string | null;
  matchedPhotos: boolean | null;
  createdAt: string;
  productName?: string | null;
  batchCode?: string | null;
}

interface CustomerProfile {
  customer: CustomerRowDTO & { createdAt?: string };
  orders: OrderDTO[];
  reviews: CustomerReview[];
}

export function Customers() {
  const [rows, setRows] = useState<CustomerRowDTO[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState("");
  const debouncedQ = useDebounce(q, 400);

  const [profile, setProfile] = useState<CustomerProfile | null>(null);
  const [profileOpen, setProfileOpen] = useState(false);
  const [profileLoading, setProfileLoading] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await adminApi.get<unknown>(
        `/api/admin/customers?q=${encodeURIComponent(debouncedQ)}`,
        { silent: true }
      );
      setRows(normalizeCustomers(data));
    } catch {
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [debouncedQ]);

  useEffect(() => {
    void load();
  }, [load]);

  const openProfile = async (row: CustomerRowDTO) => {
    setProfile({
      customer: row,
      orders: [],
      reviews: [],
    });
    setProfileOpen(true);
    setProfileLoading(true);
    try {
      const data = await adminApi.get<unknown>(`/api/admin/customers/${row.id}`, { silent: true });
      const d = (data ?? {}) as Record<string, unknown>;
      // الخادم يعيد { customer: { ...orders, ...reviews } } — ندعم الشكلين
      const cRaw = (d.customer ?? d) as Record<string, unknown>;
      const profile = normalizeCustomers({ customers: [cRaw] })[0] ?? row;
      const orders = (Array.isArray(d.orders) ? d.orders : cRaw.orders) as OrderDTO[];
      const reviews = (Array.isArray(d.reviews) ? d.reviews : cRaw.reviews) as CustomerReview[];
      setProfile({
        customer: { ...profile, createdAt: (cRaw.createdAt as string) ?? undefined },
        orders: Array.isArray(orders) ? orders : [],
        reviews: Array.isArray(reviews) ? reviews : [],
      });
    } catch {
      toast({ title: "تعذر تحميل ملف العميل", variant: "destructive" });
    } finally {
      setProfileLoading(false);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-lg font-extrabold">العملاء</h2>
          <p className="text-muted-foreground text-xs">ابحث بالاسم أو رقم الهاتف وافتح الملف الكامل.</p>
        </div>
        <div className="flex gap-2">
          <div className="relative flex-1 sm:w-72">
            <Search className="text-muted-foreground absolute top-1/2 right-3 size-4 -translate-y-1/2" aria-hidden="true" />
            <Input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="اسم أو هاتف العميل…"
              className="pr-9"
              aria-label="بحث في العملاء"
            />
          </div>
          <Button variant="outline" size="icon" onClick={() => void load()} aria-label="تحديث القائمة">
            <RefreshCw className="size-4" aria-hidden="true" />
          </Button>
        </div>
      </div>

      {loading && !rows ? (
        <LoadingRows rows={4} />
      ) : !rows || rows.length === 0 ? (
        <EmptyState title="لا يوجد عملاء مطابقون" icon={Users} />
      ) : (
        <ul className="grid max-h-[68vh] gap-2.5 overflow-y-auto pl-1 md:grid-cols-2" aria-label="قائمة العملاء">
          {rows.map((c) => (
            <li key={c.id}>
              <button
                onClick={() => void openProfile(c)}
                className="hover:bg-accent/50 flex w-full items-center gap-3 rounded-xl border p-3.5 text-start shadow-sm transition hover:shadow"
                aria-label={`ملف العميل ${c.name}`}
              >
                <div className="bg-primary/10 text-primary flex size-11 shrink-0 items-center justify-center rounded-full text-sm font-extrabold">
                  {c.name.slice(0, 2)}
                </div>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-extrabold">{c.name}</p>
                  <p className="text-muted-foreground font-mono text-xs" dir="ltr">{c.phone}</p>
                </div>
                <div className="shrink-0 text-left">
                  <p className="text-muted-foreground text-[10px]">
                    {formatNum(c.ordersCount)} طلب • {c.lastOrderAt ? timeAgoArSafe(c.lastOrderAt) : "—"}
                  </p>
                  <Money amount={c.totalSpent} className="text-primary text-sm" />
                </div>
                <ChevronLeft className="text-muted-foreground size-4 shrink-0" aria-hidden="true" />
              </button>
            </li>
          ))}
        </ul>
      )}

      {/* ملف العميل */}
      <Dialog open={profileOpen} onOpenChange={setProfileOpen}>
        <DialogContent className="max-h-[90vh] max-w-2xl overflow-y-auto sm:max-w-2xl">
          {profile ? (
            <>
              <DialogHeader>
                <div className="flex flex-wrap items-center gap-2">
                  <DialogTitle className="text-lg">{profile.customer.name}</DialogTitle>
                  <Badge variant="secondary">
                    {formatNum(profile.customer.ordersCount)} طلب
                  </Badge>
                  <Badge variant="outline" className="border-emerald-200 bg-emerald-50 text-emerald-800 dark:border-emerald-900 dark:bg-emerald-500/10">
                    إجمالي الشراء: {profile.customer.totalSpent > 0 ? <Money amount={profile.customer.totalSpent} /> : "0"}
                  </Badge>
                  {profileLoading ? (
                    <RefreshCw className="text-muted-foreground size-4 animate-spin" aria-hidden="true" />
                  ) : null}
                </div>
                <DialogDescription className="flex flex-wrap items-center gap-2">
                  <span className="font-mono" dir="ltr">{profile.customer.phone}</span>
                  {profile.customer.lastOrderAt ? (
                    <span>• آخر طلب {timeAgoArSafe(profile.customer.lastOrderAt)}</span>
                  ) : null}
                  <Button variant="ghost" size="sm" className="h-7 gap-1 px-2 text-xs" asChild>
                    <a
                      href={whatsappUrl(
                        profile.customer.phone,
                        `مرحبًا ${profile.customer.name}، من متجر ذهب أخضر 🌿`
                      )}
                      target="_blank"
                      rel="noreferrer"
                    >
                      <MessageCircle className="size-3.5" aria-hidden="true" /> واتساب
                    </a>
                  </Button>
                  <Button variant="ghost" size="sm" className="h-7 gap-1 px-2 text-xs" asChild>
                    <a href={`tel:${profile.customer.phone}`}>
                      <Phone className="size-3.5" aria-hidden="true" /> اتصال
                    </a>
                  </Button>
                </DialogDescription>
              </DialogHeader>

              <div className="space-y-4">
                {/* الطلبات */}
                <section aria-label="طلبات العميل">
                  <h3 className="mb-2 flex items-center gap-1.5 text-sm font-bold">
                    <ShoppingBag className="size-4" aria-hidden="true" /> الطلبات
                  </h3>
                  {profile.orders.length === 0 ? (
                    <EmptyState title="لا توجد طلبات" icon={ShoppingBag} />
                  ) : (
                    <ul className="max-h-64 space-y-2 overflow-y-auto pl-1" aria-label="قائمة طلبات العميل">
                      {profile.orders.map((o) => (
                        <li key={o.id} className="flex items-center justify-between gap-2 rounded-xl border p-2.5">
                          <div className="min-w-0">
                            <div className="flex flex-wrap items-center gap-1.5">
                              <span className="font-mono text-xs font-bold" dir="ltr">{o.orderCode}</span>
                              <OrderStatusBadge status={o.status} />
                            </div>
                            <p className="text-muted-foreground mt-0.5 text-[11px]">
                              {timeAgoArSafe(o.createdAt)} • {formatNum(o.items.length)} صنف
                            </p>
                          </div>
                          <Money amount={o.total} className="shrink-0 text-sm" />
                        </li>
                      ))}
                    </ul>
                  )}
                </section>

                <Separator />

                {/* التقييمات */}
                <section aria-label="تقييمات العميل">
                  <h3 className="mb-2 flex items-center gap-1.5 text-sm font-bold">
                    <Heart className="size-4" aria-hidden="true" /> التقييمات
                  </h3>
                  {profile.reviews.length === 0 ? (
                    <EmptyState title="لا توجد تقييمات بعد" icon={Star} />
                  ) : (
                    <ul className="max-h-64 space-y-2 overflow-y-auto pl-1" aria-label="قائمة تقييمات العميل">
                      {profile.reviews.map((r, idx) => (
                        <li key={r.id ?? idx} className="rounded-xl border p-3">
                          <div className="flex flex-wrap items-center gap-2">
                            <span className="text-sm" aria-label={`تقييم ${r.rating} من 5`}>
                              {Array.from({ length: 5 }).map((_, i) => (
                                <Star
                                  key={i}
                                  className={cnStar(i < r.rating)}
                                  aria-hidden="true"
                                />
                              ))}
                            </span>
                            <span className="text-lg" role="img" aria-label="وجه التقييم">
                              {SMILEYS[r.smiley as Smiley] ?? r.smiley}
                            </span>
                            {r.matchedPhotos === true ? (
                              <Badge variant="outline" className="border-emerald-200 bg-emerald-50 text-[10px] text-emerald-700 dark:border-emerald-900 dark:bg-emerald-500/10">
                                📸 مطابق للصور
                              </Badge>
                            ) : r.matchedPhotos === false ? (
                              <Badge variant="outline" className="border-red-200 bg-red-50 text-[10px] text-red-700 dark:border-red-900 dark:bg-red-500/10">
                                غير مطابق للصور
                              </Badge>
                            ) : null}
                            <span className="text-muted-foreground ms-auto text-[10px]">
                              {timeAgoArSafe(r.createdAt)}
                            </span>
                          </div>
                          {r.comment ? (
                            <p className="mt-1.5 text-xs leading-relaxed">« {r.comment} »</p>
                          ) : null}
                          {r.productName ? (
                            <p className="text-muted-foreground mt-1 text-[10px]">
                              {r.productName}
                              {r.batchCode ? <span className="font-mono" dir="ltr"> {r.batchCode}</span> : null}
                            </p>
                          ) : null}
                        </li>
                      ))}
                    </ul>
                  )}
                </section>
              </div>
            </>
          ) : null}
        </DialogContent>
      </Dialog>
    </div>
  );
}

function cnStar(filled: boolean): string {
  return `inline size-3.5 ${filled ? "fill-amber-400 text-amber-400" : "text-muted-foreground/40"}`;
}
