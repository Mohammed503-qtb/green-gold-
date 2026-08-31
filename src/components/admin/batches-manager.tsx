"use client";

// ============================================================
// GREEN GOLD | إدارة الدفعات (دفعات القات)
// قائمة بكل الحالات + إنشاء دفعة جديدة + إجراءات البطاقة
// ============================================================

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Plus,
  Star,
  Trash2,
  LinkIcon,
  Camera,
  Tag,
  Package,
  EyeOff,
  Eye,
  Archive,
  Loader2,
  RefreshCw,
  ImageIcon,
  Video,
  Sparkles,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Slider } from "@/components/ui/slider";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
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
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { toast } from "@/hooks/use-toast";
import { cn } from "@/lib/utils";
import {
  CAN,
  GRADES,
  GRADE_STYLE,
  GRADE_EMOJI,
  formatArabicDate,
  formatYER,
  type Grade,
} from "@/lib/contracts";
import {
  adminApi,
  broadcastAdminRefresh,
  formatNum,
  listOf,
  type AdminBatchDTO,
  type StaffSession,
} from "./api";
import {
  BatchStatusBadge,
  EmptyState,
  GradeBadge,
  LoadingRows,
  StockBadge,
  useDebounce,
} from "./bits";

// ───────── نموذج الدفعة الجديدة ─────────

interface ImageItem {
  url: string;
  isMain: boolean;
}

interface NewBatchForm {
  productMode: "existing" | "new";
  productId: string;
  productName: string;
  grade: Grade;
  price: string;
  totalQty: string;
  description: string;
  images: ImageItem[];
  video: string;
  withQuality: boolean;
  quality: { freshness: number; density: number; fullness: number; appearance: number };
  capturedAt: string;
}

function nowLocalInput(): string {
  const d = new Date();
  d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
  return d.toISOString().slice(0, 16);
}

function emptyForm(): NewBatchForm {
  return {
    productMode: "existing",
    productId: "",
    productName: "",
    grade: "EXCELLENT",
    price: "",
    totalQty: "",
    description: "",
    images: [],
    video: "",
    withQuality: true,
    quality: { freshness: 7, density: 7, fullness: 7, appearance: 7 },
    capturedAt: nowLocalInput(),
  };
}

const QUALITY_LABELS: { key: keyof NewBatchForm["quality"]; label: string }[] = [
  { key: "freshness", label: "النضارة" },
  { key: "density", label: "الكثافة" },
  { key: "fullness", label: "الامتلاء" },
  { key: "appearance", label: "المظهر العام" },
];

// ───────── المكوّن ─────────

interface BatchesManagerProps {
  session: StaffSession;
}

export function BatchesManager({ session }: BatchesManagerProps) {
  const [batches, setBatches] = useState<AdminBatchDTO[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<string>("ALL");
  const [search, setSearch] = useState("");
  const debouncedSearch = useDebounce(search, 350);

  // دفعة جديدة
  const [createOpen, setCreateOpen] = useState(false);
  const [form, setForm] = useState<NewBatchForm>(emptyForm);
  const [imageInput, setImageInput] = useState("");
  const [submitting, setSubmitting] = useState(false);

  // إجراءات البطاقة
  const [statusTarget, setStatusTarget] = useState<{ batch: AdminBatchDTO; status: string } | null>(null);
  const [priceTarget, setPriceTarget] = useState<AdminBatchDTO | null>(null);
  const [newPrice, setNewPrice] = useState("");
  const [qtyTarget, setQtyTarget] = useState<AdminBatchDTO | null>(null);
  const [addQty, setAddQty] = useState("");
  const [busy, setBusy] = useState(false);

  const canChangePrice = (CAN.changePrice as readonly string[]).includes(session.role);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await adminApi.get<unknown>("/api/admin/batches", { silent: true });
      setBatches(listOf<AdminBatchDTO>(data, "batches"));
    } catch {
      setBatches([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const products = useMemo(() => {
    const map = new Map<string, string>();
    for (const b of batches ?? []) {
      if (b.productId && b.productName) map.set(b.productId, b.productName);
    }
    return Array.from(map.entries()).map(([id, name]) => ({ id, name }));
  }, [batches]);

  const filtered = useMemo(() => {
    let list = batches ?? [];
    if (filter !== "ALL") list = list.filter((b) => b.status === filter);
    const q = debouncedSearch.trim();
    if (q) {
      list = list.filter(
        (b) =>
          b.productName.includes(q) ||
          b.batchCode.toLowerCase().includes(q.toLowerCase())
      );
    }
    return list;
  }, [batches, filter, debouncedSearch]);

  const statusCounts = useMemo(() => {
    const map = new Map<string, number>();
    for (const b of batches ?? []) map.set(b.status, (map.get(b.status) ?? 0) + 1);
    return map;
  }, [batches]);

  // ── نموذج الدفعة الجديدة ──

  const setF = <K extends keyof NewBatchForm>(key: K, value: NewBatchForm[K]) => {
    setForm((f) => ({ ...f, [key]: value }));
  };

  const addImage = () => {
    const url = imageInput.trim();
    if (!url) return;
    if (!/^https?:\/\/.+/i.test(url) && !url.startsWith("data:image")) {
      toast({ title: "رابط غير صالح", description: "أدخل رابط صورة يبدأ بـ http", variant: "destructive" });
      return;
    }
    if (form.images.some((i) => i.url === url)) {
      toast({ title: "الصورة مضافة بالفعل", variant: "destructive" });
      return;
    }
    const isFirst = form.images.length === 0;
    setF("images", [...form.images, { url, isMain: isFirst }]);
    setImageInput("");
  };

  const removeImage = (url: string) => {
    const next = form.images.filter((i) => i.url !== url);
    if (next.length > 0 && !next.some((i) => i.isMain)) next[0] = { ...next[0], isMain: true };
    setF("images", next);
  };

  const setMainImage = (url: string) => {
    setF(
      "images",
      form.images.map((i) => ({ ...i, isMain: i.url === url }))
    );
  };

  const canPublish =
    form.images.length >= 1 &&
    (form.productMode === "existing" ? !!form.productId : form.productName.trim().length >= 2) &&
    Number(form.price) > 0 &&
    Number(form.totalQty) > 0;

  const publish = async () => {
    if (!canPublish) return;
    setSubmitting(true);
    try {
      const body: Record<string, unknown> = {
        grade: form.grade,
        price: Number(form.price),
        totalQty: Number(form.totalQty),
        description: form.description.trim() || undefined,
        images: form.images.map((i) => ({ url: i.url, isMain: i.isMain })),
        video: form.video.trim() || undefined,
        capturedAt: new Date(form.capturedAt).toISOString(),
      };
      if (form.productMode === "existing") body.productId = form.productId;
      else body.productName = form.productName.trim();

      if (form.withQuality) body.quality = form.quality;

      await adminApi.post("/api/admin/batches", body);
      toast({
        title: "تم نشر الدفعة 🌿",
        description: "ظهرت الدفعة في المتجر وأُرسلت حركات المخزون",
      });
      setCreateOpen(false);
      setForm(emptyForm());
      broadcastAdminRefresh();
      void load();
    } catch {
      // toast من api.ts
    } finally {
      setSubmitting(false);
    }
  };

  // ── إجراءات البطاقة ──

  const patchBatch = async (id: string, body: Record<string, unknown>, okMsg: string) => {
    setBusy(true);
    try {
      await adminApi.patch(`/api/admin/batches/${id}`, body);
      toast({ title: okMsg });
      broadcastAdminRefresh();
      void load();
      return true;
    } catch {
      return false;
    } finally {
      setBusy(false);
    }
  };

  const statusFilters: { key: string; label: string }[] = [
    { key: "ALL", label: "الكل" },
    { key: "ACTIVE", label: "نشطة" },
    { key: "HIDDEN", label: "مخفية" },
    { key: "CLOSED", label: "مغلقة" },
    { key: "SOLD_OUT", label: "نافدة" },
  ];

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h2 className="text-lg font-extrabold">إدارة الدفعات</h2>
          <p className="text-muted-foreground text-xs">انشر دفعة جديدة بتصوير اليوم — النشر يتطلب صورة واحدة على الأقل.</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="icon" onClick={() => void load()} aria-label="تحديث القائمة">
            <RefreshCw className="size-4" aria-hidden="true" />
          </Button>
          <Button
            className="font-bold"
            onClick={() => {
              setForm({ ...emptyForm(), productId: products[0]?.id ?? "" });
              setCreateOpen(true);
            }}
          >
            <Plus className="size-4" aria-hidden="true" />
            دفعة جديدة
          </Button>
        </div>
      </div>

      {/* فلاتر الحالة + بحث */}
      <div className="flex flex-col gap-2.5 md:flex-row md:items-center">
        <div className="flex flex-1 flex-wrap gap-1.5" role="group" aria-label="فلتر حالة الدفعات">
          {statusFilters.map((f) => (
            <button
              key={f.key}
              onClick={() => setFilter(f.key)}
              className={cn(
                "rounded-lg border px-3 py-1.5 text-xs font-bold transition",
                filter === f.key
                  ? "border-primary bg-primary text-primary-foreground shadow-sm"
                  : "bg-card hover:bg-accent text-muted-foreground"
              )}
              aria-pressed={filter === f.key}
            >
              {f.label}
              {f.key !== "ALL" && statusCounts.get(f.key) ? (
                <span className="ms-1.5 tabular-nums opacity-80">{formatNum(statusCounts.get(f.key) ?? 0)}</span>
              ) : null}
            </button>
          ))}
        </div>
        <Input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="بحث باسم النوع أو رقم الدفعة…"
          className="md:w-64"
          aria-label="بحث في الدفعات"
        />
      </div>

      {/* القائمة */}
      {loading && !batches ? (
        <LoadingRows rows={4} />
      ) : filtered.length === 0 ? (
        <EmptyState title="لا توجد دفعات مطابقة" sub="أنشئ دفعة جديدة أو غيّر الفلتر" icon={Package} />
      ) : (
        <ul className="grid max-h-[64vh] gap-3 overflow-y-auto pl-1 sm:grid-cols-2 xl:grid-cols-3" aria-label="قائمة الدفعات">
          {filtered.map((b) => (
            <li key={b.id} className="overflow-hidden rounded-xl border shadow-sm">
              <div className="relative aspect-[4/3] bg-muted">
                {b.mainImage ? (
                  <img
                    src={b.mainImage}
                    alt={`${b.productName} — ${b.batchCode}`}
                    loading="lazy"
                    className="size-full object-cover"
                  />
                ) : (
                  <div className="text-muted-foreground flex size-full items-center justify-center">
                    <ImageIcon className="size-8 opacity-50" aria-hidden="true" />
                  </div>
                )}
                <div className="absolute top-2 right-2 flex flex-wrap gap-1">
                  <GradeBadge grade={b.grade} />
                  <BatchStatusBadge status={b.status} />
                </div>
                {b.video ? (
                  <span className="absolute bottom-2 left-2 flex items-center gap-1 rounded-md bg-black/60 px-1.5 py-0.5 text-[10px] font-bold text-white">
                    <Video className="size-3" aria-hidden="true" /> فيديو
                  </span>
                ) : null}
              </div>
              <div className="space-y-2 p-3">
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="truncate text-sm font-extrabold">{b.productName}</p>
                    <p className="text-muted-foreground font-mono text-[10px]" dir="ltr">{b.batchCode}</p>
                  </div>
                  <p className="text-primary shrink-0 text-sm font-extrabold">{formatYER(b.price)}</p>
                </div>
                <div className="flex flex-wrap items-center gap-1.5 text-[11px]">
                  <StockBadge available={b.availableQty} />
                  {typeof b.totalQty === "number" ? (
                    <Badge variant="secondary">إجمالي {formatNum(b.totalQty)}</Badge>
                  ) : null}
                  {b.soldCount > 0 ? (
                    <Badge variant="secondary">مباع {formatNum(b.soldCount)}</Badge>
                  ) : null}
                </div>
                <p className="text-muted-foreground flex items-center gap-1 text-[10px]">
                  <Camera className="size-3" aria-hidden="true" />
                  تصوير {formatArabicDate(b.capturedAt)}
                </p>
                {/* الأزرار */}
                <div className="flex flex-wrap gap-1.5 pt-1">
                  {b.status === "ACTIVE" ? (
                    <Button
                      variant="outline"
                      size="sm"
                      className="h-8 gap-1 text-xs"
                      onClick={() => setStatusTarget({ batch: b, status: "HIDDEN" })}
                    >
                      <EyeOff className="size-3.5" aria-hidden="true" /> إخفاء
                    </Button>
                  ) : b.status === "HIDDEN" ? (
                    <Button
                      variant="outline"
                      size="sm"
                      className="text-primary h-8 gap-1 text-xs"
                      onClick={() => setStatusTarget({ batch: b, status: "ACTIVE" })}
                    >
                      <Eye className="size-3.5" aria-hidden="true" /> تنشيط
                    </Button>
                  ) : null}
                  {b.status !== "CLOSED" && b.status !== "SOLD_OUT" ? (
                    <Button
                      variant="outline"
                      size="sm"
                      className="h-8 gap-1 border-orange-200 text-xs text-orange-700 hover:bg-orange-50 dark:border-orange-900 dark:text-orange-400"
                      onClick={() => setStatusTarget({ batch: b, status: "CLOSED" })}
                    >
                      <Archive className="size-3.5" aria-hidden="true" /> إغلاق
                    </Button>
                  ) : null}
                  {canChangePrice ? (
                    <Button
                      variant="outline"
                      size="sm"
                      className="h-8 gap-1 border-amber-200 text-xs text-amber-800 hover:bg-amber-50 dark:border-amber-900 dark:text-amber-400"
                      onClick={() => {
                        setNewPrice(String(b.price));
                        setPriceTarget(b);
                      }}
                    >
                      <Tag className="size-3.5" aria-hidden="true" /> السعر
                    </Button>
                  ) : null}
                  <Button
                    variant="outline"
                    size="sm"
                    className="h-8 gap-1 text-xs"
                    onClick={() => {
                      setAddQty("");
                      setQtyTarget(b);
                    }}
                  >
                    <Plus className="size-3.5" aria-hidden="true" /> كمية
                  </Button>
                </div>
              </div>
            </li>
          ))}
        </ul>
      )}

      {/* ══════════ Dialog دفعة جديدة ══════════ */}
      <Dialog open={createOpen} onOpenChange={(o) => !submitting && setCreateOpen(o)}>
        <DialogContent className="max-h-[92vh] max-w-2xl overflow-y-auto sm:max-w-2xl">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2 text-lg font-extrabold">
              <Sparkles className="text-amber-600 size-5" aria-hidden="true" />
              نشر دفعة جديدة
            </DialogTitle>
            <DialogDescription>
              الدفعة تظهر فورًا للعملاء بصورها وسعرها — تأكد من جودة التصوير قبل النشر.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-5">
            {/* المنتج */}
            <section className="space-y-2">
              <Label className="text-sm font-bold">المنتج (نوع القات)</Label>
              <RadioGroup
                value={form.productMode}
                onValueChange={(v) => setF("productMode", v as "existing" | "new")}
                className="flex flex-row gap-4"
              >
                <div className="flex items-center gap-1.5">
                  <RadioGroupItem value="existing" id="pm-existing" />
                  <Label htmlFor="pm-existing" className="cursor-pointer text-xs font-semibold">منتج موجود</Label>
                </div>
                <div className="flex items-center gap-1.5">
                  <RadioGroupItem value="new" id="pm-new" />
                  <Label htmlFor="pm-new" className="cursor-pointer text-xs font-semibold">اسم منتج جديد</Label>
                </div>
              </RadioGroup>
              {form.productMode === "existing" ? (
                products.length > 0 ? (
                  <Select value={form.productId} onValueChange={(v) => setF("productId", v)}>
                    <SelectTrigger className="w-full" aria-label="اختيار المنتج">
                      <SelectValue placeholder="اختر النوع…" />
                    </SelectTrigger>
                    <SelectContent className="max-h-72">
                      {products.map((p) => (
                        <SelectItem key={p.id} value={p.id}>{p.name}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                ) : (
                  <Input
                    placeholder="لا توجد منتجات بعد — اكتب اسم منتج جديد"
                    value={form.productName}
                    onChange={(e) => setF("productName", e.target.value)}
                  />
                )
              ) : (
                <Input
                  placeholder="مثال: حراز فحمة"
                  value={form.productName}
                  onChange={(e) => setF("productName", e.target.value)}
                />
              )}
            </section>

            {/* التصنيف */}
            <section className="space-y-2">
              <Label className="text-sm font-bold">التصنيف</Label>
              <RadioGroup
                value={form.grade}
                onValueChange={(v) => setF("grade", v as Grade)}
                className="grid grid-cols-3 gap-2"
              >
                {(Object.keys(GRADES) as Grade[]).map((g) => (
                  <label
                    key={g}
                    htmlFor={`grade-${g}`}
                    className={cn(
                      "flex cursor-pointer items-center justify-center gap-1.5 rounded-xl border-2 px-3 py-3 text-sm font-extrabold transition",
                      GRADE_STYLE[g],
                      form.grade === g ? "ring-primary ring-2 ring-offset-1" : "opacity-75 hover:opacity-100"
                    )}
                  >
                    <RadioGroupItem value={g} id={`grade-${g}`} className="sr-only" />
                    {GRADE_EMOJI[g]} {GRADES[g]}
                  </label>
                ))}
              </RadioGroup>
            </section>

            {/* السعر والكمية */}
            <section className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label htmlFor="batch-price" className="text-sm font-bold">السعر (ريال/حزمة)</Label>
                <Input
                  id="batch-price"
                  type="number"
                  inputMode="numeric"
                  min={1}
                  value={form.price}
                  onChange={(e) => setF("price", e.target.value)}
                  placeholder="مثال: 8500"
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="batch-qty" className="text-sm font-bold">الكمية (حزمة)</Label>
                <Input
                  id="batch-qty"
                  type="number"
                  inputMode="numeric"
                  min={1}
                  value={form.totalQty}
                  onChange={(e) => setF("totalQty", e.target.value)}
                  placeholder="مثال: 25"
                />
              </div>
            </section>

            {/* الوصف */}
            <div className="space-y-1.5">
              <Label htmlFor="batch-desc" className="text-sm font-bold">الوصف (اختياري)</Label>
              <Textarea
                id="batch-desc"
                value={form.description}
                onChange={(e) => setF("description", e.target.value)}
                placeholder="وصف قصير يظهر للعملاء: مصدر الدفعة، ملاحظات…"
                rows={2}
              />
            </div>

            {/* الصور */}
            <section className="space-y-2">
              <Label className="text-sm font-bold">
                روابط الصور <span className="text-amber-700 dark:text-amber-400">*</span>
                <span className="text-muted-foreground ms-1 text-[11px] font-normal">
                  (اضغط على صورة لجعلها الرئيسية — النجم)
                </span>
              </Label>
              <div className="flex gap-2">
                <div className="relative flex-1">
                  <LinkIcon className="text-muted-foreground absolute top-1/2 right-3 size-4 -translate-y-1/2" aria-hidden="true" />
                  <Input
                    value={imageInput}
                    onChange={(e) => setImageInput(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") {
                        e.preventDefault();
                        addImage();
                      }
                    }}
                    placeholder="https://… رابط صورة الدفعة"
                    className="pr-9"
                    dir="ltr"
                  />
                </div>
                <Button variant="secondary" onClick={addImage} className="font-bold">
                  <Plus className="size-4" aria-hidden="true" /> إضافة
                </Button>
              </div>
              {form.images.length > 0 ? (
                <ul className="grid grid-cols-3 gap-2 sm:grid-cols-4" aria-label="صور الدفعة">
                  {form.images.map((img) => (
                    <li key={img.url} className="group relative overflow-hidden rounded-lg border">
                      <button
                        type="button"
                        onClick={() => setMainImage(img.url)}
                        className="block w-full"
                        aria-label={img.isMain ? "الصورة الرئيسية (اضغط للإبقاء)" : "تعيين كصورة رئيسية"}
                      >
                        <img src={img.url} alt="صورة دفعة" loading="lazy" className="aspect-square w-full object-cover" />
                      </button>
                      <span
                        className={cn(
                          "pointer-events-none absolute top-1 right-1 rounded-md p-1",
                          img.isMain ? "bg-amber-400 text-amber-950" : "bg-black/50 text-white opacity-0 transition group-hover:opacity-100"
                        )}
                        aria-hidden="true"
                      >
                        <Star className={cn("size-3.5", img.isMain && "fill-amber-950")} />
                      </span>
                      <button
                        type="button"
                        onClick={() => removeImage(img.url)}
                        className="absolute bottom-1 left-1 rounded-md bg-red-600/90 p-1 text-white transition hover:bg-red-600"
                        aria-label={`حذف الصورة ${img.url}`}
                      >
                        <Trash2 className="size-3.5" aria-hidden="true" />
                      </button>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="rounded-lg border border-dashed border-amber-300 bg-amber-50 p-2.5 text-xs font-semibold text-amber-800 dark:border-amber-900 dark:bg-amber-500/10 dark:text-amber-400">
                  📸 لا توجد صور بعد — لا يمكن النشر دون صورة واحدة على الأقل (هذه هي ثقة العميل).
                </p>
              )}
            </section>

            {/* الفيديو */}
            <div className="space-y-1.5">
              <Label htmlFor="batch-video" className="text-sm font-bold">
                رابط فيديو (اختياري)
              </Label>
              <Input
                id="batch-video"
                value={form.video}
                onChange={(e) => setF("video", e.target.value)}
                placeholder="https://youtube.com/… أو رابط mp4"
                dir="ltr"
              />
            </div>

            {/* الجودة */}
            <section className="space-y-3 rounded-xl border p-3">
              <div className="flex items-center justify-between">
                <Label className="text-sm font-bold">تقييم الجودة (من 10)</Label>
                <div className="flex items-center gap-2">
                  <span className="text-muted-foreground text-xs">تفعيل</span>
                  <Switch
                    checked={form.withQuality}
                    onCheckedChange={(v) => setF("withQuality", v)}
                    aria-label="تفعيل مقاييس الجودة"
                  />
                </div>
              </div>
              {form.withQuality ? (
                <div className="grid gap-4 sm:grid-cols-2">
                  {QUALITY_LABELS.map(({ key, label }) => (
                    <div key={key} className="space-y-1.5">
                      <div className="flex items-center justify-between text-xs font-bold">
                        <span>{label}</span>
                        <span className="text-primary rounded-md bg-primary/10 px-1.5 py-0.5 tabular-nums">
                          {formatNum(form.quality[key])}
                        </span>
                      </div>
                      <Slider
                        value={[form.quality[key]]}
                        min={1}
                        max={10}
                        step={1}
                        onValueChange={([v]) =>
                          setF("quality", { ...form.quality, [key]: v })
                        }
                        aria-label={label}
                      />
                    </div>
                  ))}
                </div>
              ) : null}
            </section>

            {/* وقت التصوير */}
            <div className="space-y-1.5">
              <Label htmlFor="batch-captured" className="flex items-center gap-1.5 text-sm font-bold">
                <Camera className="size-4" aria-hidden="true" /> وقت التصوير
              </Label>
              <Input
                id="batch-captured"
                type="datetime-local"
                value={form.capturedAt}
                onChange={(e) => setF("capturedAt", e.target.value)}
              />
            </div>
          </div>

          <DialogFooter className="gap-2 border-t pt-4">
            <Button variant="outline" disabled={submitting} onClick={() => setCreateOpen(false)}>
              إلغاء
            </Button>
            <TooltipProvider delayDuration={200}>
              <Tooltip open={canPublish ? false : undefined}>
                <TooltipTrigger asChild>
                  <span tabIndex={canPublish ? -1 : 0} className="inline-flex">
                    <Button
                      className="font-extrabold"
                      disabled={!canPublish || submitting}
                      onClick={() => void publish()}
                    >
                      {submitting ? (
                        <>
                          <Loader2 className="size-4 animate-spin" aria-hidden="true" /> جارٍ النشر…
                        </>
                      ) : (
                        <>
                          <Sparkles className="size-4" aria-hidden="true" /> نشر الدفعة
                        </>
                      )}
                    </Button>
                  </span>
                </TooltipTrigger>
                {!canPublish ? (
                  <TooltipContent side="top" className="font-bold">
                    {form.images.length === 0
                      ? "أضف صورة واحدة على الأقل قبل النشر 📸"
                      : !Number(form.price || form.totalQty)
                        ? "أدخل سعرًا وكمية صحيحين"
                        : "اختر المنتج أو اكتب اسمًا جديدًا"}
                  </TooltipContent>
                ) : null}
              </Tooltip>
            </TooltipProvider>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* تأكيد تغيير الحالة */}
      <AlertDialog open={!!statusTarget} onOpenChange={(o) => !o && setStatusTarget(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>
              {statusTarget?.status === "HIDDEN"
                ? "إخفاء الدفعة من المتجر؟"
                : statusTarget?.status === "ACTIVE"
                  ? "تنشيط الدفعة وإظهارها للعملاء؟"
                  : "إغلاق الدفعة نهائيًا؟"}
            </AlertDialogTitle>
            <AlertDialogDescription>
              الدفعة{" "}
              <span className="font-mono font-bold" dir="ltr">{statusTarget?.batch.batchCode}</span> (
              {statusTarget?.batch.productName}) —{" "}
              {statusTarget?.status === "HIDDEN"
                ? "لن يراها العملاء لكنها تبقى في المخزون."
                : statusTarget?.status === "ACTIVE"
                  ? "ستظهر مباشرة في قسم «قات اليوم»."
                  : "لن تظهر ولن تقبل طلبات جديدة (الكميات المتبقية تبقى في المخزون)."}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={busy}>تراجع</AlertDialogCancel>
            <AlertDialogAction
              disabled={busy}
              onClick={(e) => {
                e.preventDefault();
                if (!statusTarget) return;
                void (async () => {
                  const ok = await patchBatch(
                    statusTarget.batch.id,
                    { status: statusTarget.status },
                    statusTarget.status === "HIDDEN"
                      ? "تم إخفاء الدفعة"
                      : statusTarget.status === "ACTIVE"
                        ? "تم تنشيط الدفعة"
                        : "تم إغلاق الدفعة"
                  );
                  if (ok) setStatusTarget(null);
                })();
              }}
            >
              {busy ? <Loader2 className="size-4 animate-spin" aria-hidden="true" /> : null}
              تأكيد
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* تعديل السعر */}
      <Dialog open={!!priceTarget} onOpenChange={(o) => !o && setPriceTarget(null)}>
        <DialogContent className="max-w-sm sm:max-w-sm">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Tag className="text-amber-600 size-5" aria-hidden="true" />
              تعديل سعر الدفعة
            </DialogTitle>
            <DialogDescription>
              {priceTarget?.productName} — <span className="font-mono" dir="ltr">{priceTarget?.batchCode}</span>
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-2">
            <p className="text-muted-foreground rounded-lg bg-muted/60 p-2 text-xs">
              السعر الحالي: <span className="text-foreground font-extrabold">{priceTarget ? formatYER(priceTarget.price) : ""}</span>
            </p>
            <label htmlFor="new-price" className="block text-sm font-bold">
              السعر الجديد (ريال/حزمة)
            </label>
            <Input
              id="new-price"
              type="number"
              inputMode="numeric"
              min={1}
              value={newPrice}
              onChange={(e) => setNewPrice(e.target.value)}
            />
            <p className="text-[11px] text-amber-700 dark:text-amber-400">
              ⚖️ يُسجَّل التغيير (قبل ← بعد) في سجل التدقيق باسمك.
            </p>
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" disabled={busy} onClick={() => setPriceTarget(null)}>
              إلغاء
            </Button>
            <Button
              disabled={busy || !newPrice || Number(newPrice) <= 0}
              onClick={() => {
                if (!priceTarget || !newPrice) return;
                void (async () => {
                  const ok = await patchBatch(priceTarget.id, { price: Number(newPrice) }, `تم تحديث السعر إلى ${formatYER(Number(newPrice))}`);
                  if (ok) setPriceTarget(null);
                })();
              }}
              className="font-bold"
            >
              {busy ? <Loader2 className="size-4 animate-spin" aria-hidden="true" /> : null}
              حفظ السعر
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* إضافة كمية */}
      <Dialog open={!!qtyTarget} onOpenChange={(o) => !o && setQtyTarget(null)}>
        <DialogContent className="max-w-sm sm:max-w-sm">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Plus className="text-primary size-5" aria-hidden="true" />
              إضافة كمية للدفعة
            </DialogTitle>
            <DialogDescription>
              {qtyTarget?.productName} — المتاح حاليًا {qtyTarget ? formatNum(qtyTarget.availableQty) : ""} حزمة
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-2">
            <label htmlFor="add-qty" className="block text-sm font-bold">
              الكمية المضافة (حزمة)
            </label>
            <Input
              id="add-qty"
              type="number"
              inputMode="numeric"
              min={1}
              value={addQty}
              onChange={(e) => setAddQty(e.target.value)}
              placeholder="مثال: 15"
            />
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" disabled={busy} onClick={() => setQtyTarget(null)}>
              إلغاء
            </Button>
            <Button
              disabled={busy || !addQty || Number(addQty) <= 0}
              onClick={() => {
                if (!qtyTarget || !addQty) return;
                void (async () => {
                  const ok = await patchBatch(qtyTarget.id, { addQty: Number(addQty) }, `أُضيفت ${formatNum(Number(addQty))} حزمة للمخزون`);
                  if (ok) setQtyTarget(null);
                })();
              }}
              className="font-bold"
            >
              {busy ? <Loader2 className="size-4 animate-spin" aria-hidden="true" /> : null}
              إضافة
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
