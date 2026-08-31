"use client";

// ============================================================
// GREEN GOLD | سلة المشتريات — Sheet جانبي بالعناصر والتوصيل
// ============================================================
import { useState } from "react";
import { Minus, Plus, ShoppingCart, Trash2 } from "lucide-react";

import { EmptyState } from "@/components/shop/empty-state";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Separator } from "@/components/ui/separator";
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { GRADE_STYLE, GRADES, formatYER, type ZoneDTO } from "@/lib/contracts";
import { cartSubtotal, useCartStore } from "@/lib/cart-store";
import { cn } from "@/lib/utils";

export interface CartSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  zones: ZoneDTO[];
  zoneId: string;
  onZoneChange: (zoneId: string) => void;
  onCheckout: () => void;
}

export function CartSheet({ open, onOpenChange, zones, zoneId, onZoneChange, onCheckout }: CartSheetProps) {
  const items = useCartStore((s) => s.items);
  const setQty = useCartStore((s) => s.setQty);
  const remove = useCartStore((s) => s.remove);
  const clear = useCartStore((s) => s.clear);

  const subtotal = cartSubtotal(items);
  const zone = zones.find((z) => z.id === zoneId) ?? null;
  const total = subtotal + (zone ? zone.fee : 0);

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="left" className="flex w-full flex-col gap-0 p-0 sm:max-w-md">
        <SheetHeader className="border-b ps-12 pe-4">
          <SheetTitle className="flex items-center gap-2 text-lg font-black">
            <ShoppingCart className="size-5 text-primary" aria-hidden />
            سلة المشتريات
            {items.length > 0 && (
              <Badge variant="secondary" className="font-bold">
                {items.length} صنف
              </Badge>
            )}
          </SheetTitle>
          <SheetDescription>راجع طلبك قبل إتمام الشراء</SheetDescription>
        </SheetHeader>

        {items.length === 0 ? (
          <div className="flex flex-1 items-center justify-center p-4">
            <EmptyState
              icon="🛒"
              title="سلتك فارغة"
              description="تصفح دفعات قات اليوم وأضف ما يعجبك — الصور حقيقية والسعر واضح 🌿"
              action={
                <Button variant="outline" className="h-11 rounded-xl px-6 font-bold" onClick={() => onOpenChange(false)}>
                  تصفح الدفعات
                </Button>
              }
            />
          </div>
        ) : (
          <>
            {/* الأصناف */}
            <div className="flex-1 space-y-3 overflow-y-auto p-4">
              {items.map((it) => {
                const dead = it.snapshot.availableQty <= 0;
                return (
                  <div
                    key={it.batchId}
                    className={cn(
                      "flex gap-3 rounded-xl border bg-card p-2.5 transition-opacity",
                      dead && "opacity-60"
                    )}
                  >
                    <div className="size-16 shrink-0 overflow-hidden rounded-lg bg-muted sm:size-20">
                      {it.snapshot.image ? (
                        <img
                          src={it.snapshot.image}
                          alt={`قات ${it.snapshot.name}`}
                          loading="lazy"
                          className="size-full object-cover"
                        />
                      ) : (
                        <span className="grid size-full place-items-center text-2xl" aria-hidden>🌿</span>
                      )}
                    </div>

                    <div className="flex min-w-0 flex-1 flex-col justify-between gap-1.5">
                      <div className="flex items-start justify-between gap-2">
                        <div className="min-w-0">
                          <p className="truncate text-sm font-bold">قات {it.snapshot.name}</p>
                          <div className="mt-1 flex flex-wrap items-center gap-1.5">
                            <span
                              className={`rounded-full border px-2 py-0.5 text-[10px] font-bold ${GRADE_STYLE[it.snapshot.grade]}`}
                            >
                              {GRADES[it.snapshot.grade]}
                            </span>
                            <span className="text-[11px] text-muted-foreground">
                              {formatYER(it.snapshot.price)} / حزمة
                            </span>
                          </div>
                        </div>
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-11 shrink-0 rounded-lg text-muted-foreground hover:text-destructive"
                          onClick={() => remove(it.batchId)}
                          aria-label={`حذف قات ${it.snapshot.name} من السلة`}
                        >
                          <Trash2 className="size-4" aria-hidden />
                        </Button>
                      </div>

                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-0.5 rounded-lg border p-0.5" role="group" aria-label={`كمية قات ${it.snapshot.name}`}>
                          <Button
                            variant="ghost"
                            size="icon"
                            className="size-11 rounded-md"
                            onClick={() => setQty(it.batchId, it.qty - 1)}
                            disabled={it.qty <= 1}
                            aria-label="تقليل الكمية"
                          >
                            <Minus className="size-3.5" aria-hidden />
                          </Button>
                          <span className="w-9 text-center text-sm font-black" aria-live="polite">
                            {it.qty}
                          </span>
                          <Button
                            variant="ghost"
                            size="icon"
                            className="size-11 rounded-md"
                            onClick={() => setQty(it.batchId, it.qty + 1)}
                            disabled={it.qty >= it.snapshot.availableQty}
                            aria-label="زيادة الكمية"
                          >
                            <Plus className="size-3.5" aria-hidden />
                          </Button>
                        </div>
                        <div className="flex flex-col items-end">
                          <span className="text-sm font-black text-primary">
                            {formatYER(it.snapshot.price * it.qty)}
                          </span>
                          <span className="text-[10px] text-muted-foreground">
                            {dead ? "انتهت الدفعة" : `المتاح ${it.snapshot.availableQty}`}
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>

            {/* التذييل: التوصيل + الإجماليات */}
            <div className="space-y-3 border-t bg-muted/30 p-4">
              <div className="flex items-center gap-2">
                <span className="text-sm font-semibold">🚚 التوصيل:</span>
                <Select value={zoneId} onValueChange={onZoneChange}>
                  <SelectTrigger className="h-11 flex-1 rounded-xl" aria-label="منطقة التوصيل">
                    <SelectValue placeholder="اختر منطقة التوصيل" />
                  </SelectTrigger>
                  <SelectContent>
                    {zones.map((z) => (
                      <SelectItem key={z.id} value={z.id} className="py-2.5">
                        {z.name} — {formatYER(z.fee)}
                      </SelectItem>
                    ))}
                    {zones.length === 0 && (
                      <div className="p-3 text-center text-xs text-muted-foreground">
                        لا مناطق متاحة حاليًا
                      </div>
                    )}
                  </SelectContent>
                </Select>
              </div>

              <Separator />

              <div className="space-y-1.5 text-sm">
                <div className="flex justify-between text-muted-foreground">
                  <span>المجموع الفرعي</span>
                  <span className="font-semibold text-foreground">{formatYER(subtotal)}</span>
                </div>
                <div className="flex justify-between text-muted-foreground">
                  <span>التوصيل</span>
                  {zone ? (
                    <span className="font-semibold text-foreground">
                      {zone.name} — {formatYER(zone.fee)}
                    </span>
                  ) : (
                    <span className="text-xs">اختر المنطقة أعلاه</span>
                  )}
                </div>
                <div className="flex justify-between pt-1 text-base font-black">
                  <span>الإجمالي</span>
                  <span className="text-primary">{formatYER(total)}</span>
                </div>
              </div>

              <div className="flex gap-2">
                <AlertDialog>
                  <AlertDialogTrigger asChild>
                    <Button
                      variant="outline"
                      size="icon"
                      className="size-11 shrink-0 rounded-xl text-muted-foreground hover:text-destructive"
                      aria-label="تفريغ السلة"
                    >
                      <Trash2 className="size-4" aria-hidden />
                    </Button>
                  </AlertDialogTrigger>
                  <AlertDialogContent>
                    <AlertDialogHeader>
                      <AlertDialogTitle>تفريغ السلة؟</AlertDialogTitle>
                      <AlertDialogDescription>
                        سيتم حذف جميع الأصناف من سلتك. يمكنك إضافتها مرة أخرى من المتجر.
                      </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                      <AlertDialogCancel className="h-11">تراجع</AlertDialogCancel>
                      <AlertDialogAction
                        className="h-11 bg-destructive text-white hover:bg-destructive/90"
                        onClick={() => clear()}
                      >
                        نعم، فرّغ السلة
                      </AlertDialogAction>
                    </AlertDialogFooter>
                  </AlertDialogContent>
                </AlertDialog>

                <Button
                  onClick={onCheckout}
                  className="h-11 flex-1 rounded-xl text-base font-black"
                >
                  متابعة الطلب
                </Button>
              </div>
            </div>
          </>
        )}
      </SheetContent>
    </Sheet>
  );
}
