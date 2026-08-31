// ============================================================
// GREEN GOLD | سلة المشتريات — Zustand + persist (gg-cart)
// كل عنصر يحمل snapshot وقت الإضافة + تحقق ضد الكتالوج
// ============================================================
import { create } from "zustand";
import { createJSONStorage, persist, type StateStorage } from "zustand/middleware";
import type { BatchCardDTO, Grade } from "@/lib/contracts";

export interface CartItemSnapshot {
  name: string;
  grade: Grade;
  price: number;
  image: string | null;
  batchCode: string;
  availableQty: number;
}

export interface CartItem {
  batchId: string;
  qty: number;
  snapshot: CartItemSnapshot;
  addedAt: number;
}

export interface CartValidationResult {
  /** أسماء أصناف أُزيلت لأن دفعتها انتهت/نفدت */
  removed: string[];
  /** أسماء أصناف صُحّحت كميتها لتطابق المتاح */
  adjusted: string[];
}

interface CartState {
  items: CartItem[];
  add: (batchId: string, qty: number, snapshot: CartItemSnapshot) => void;
  remove: (batchId: string) => void;
  setQty: (batchId: string, qty: number) => void;
  clear: () => void;
  /** يزيل ما انتهى دفعه ويصحح الكميات الزائدة — خطة §24 */
  validateAgainstCatalog: (batches: BatchCardDTO[]) => CartValidationResult;
}

const noopStorage: StateStorage = {
  getItem: () => null,
  setItem: () => undefined,
  removeItem: () => undefined,
};

const safeStorage: StateStorage = {
  getItem: (name) => {
    if (typeof window === "undefined") return null;
    try {
      return window.localStorage.getItem(name);
    } catch {
      return null;
    }
  },
  setItem: (name, value) => {
    if (typeof window === "undefined") return;
    try {
      window.localStorage.setItem(name, value);
    } catch {
      /* ignore */
    }
  },
  removeItem: (name) => {
    if (typeof window === "undefined") return;
    try {
      window.localStorage.removeItem(name);
    } catch {
      /* ignore */
    }
  },
};

export const useCartStore = create<CartState>()(
  persist(
    (set, get) => ({
      items: [],

      add: (batchId, qty, snapshot) =>
        set((state) => {
          const capped = Math.max(1, Math.min(qty, Math.max(1, snapshot.availableQty)));
          const existing = state.items.find((i) => i.batchId === batchId);
          if (existing) {
            return {
              items: state.items.map((i) =>
                i.batchId === batchId
                  ? { ...i, qty: Math.min(i.qty + capped, snapshot.availableQty), snapshot }
                  : i
              ),
            };
          }
          return {
            items: [
              ...state.items,
              { batchId, qty: capped, snapshot, addedAt: Date.now() },
            ],
          };
        }),

      remove: (batchId) => set((state) => ({ items: state.items.filter((i) => i.batchId !== batchId) })),

      setQty: (batchId, qty) =>
        set((state) => ({
          items: state.items.map((i) => {
            if (i.batchId !== batchId) return i;
            const max = Math.max(1, i.snapshot.availableQty);
            return { ...i, qty: Math.max(1, Math.min(qty, max)) };
          }),
        })),

      clear: () => set({ items: [] }),

      validateAgainstCatalog: (batches) => {
        const byId = new Map(batches.map((b) => [b.id, b]));
        const removed: string[] = [];
        const adjusted: string[] = [];
        const items: CartItem[] = [];
        for (const it of get().items) {
          const b = byId.get(it.batchId);
          // الدفعة انتهت: غير موجودة أو ليست ACTIVE أو المتاح صفر
          if (!b || b.status !== "ACTIVE" || b.availableQty <= 0) {
            removed.push(it.snapshot.name);
            continue;
          }
          let next: CartItem = {
            ...it,
            snapshot: { ...it.snapshot, price: b.price, availableQty: b.availableQty },
          };
          if (next.qty > b.availableQty) {
            adjusted.push(next.snapshot.name);
            next = { ...next, qty: b.availableQty };
          }
          items.push(next);
        }
        const changed =
          removed.length > 0 ||
          adjusted.length > 0 ||
          items.length !== get().items.length ||
          items.some((n, idx) => n.qty !== get().items[idx]?.qty);
        if (changed) set({ items });
        return { removed, adjusted };
      },
    }),
    {
      name: "gg-cart",
      version: 1,
      storage: createJSONStorage(() =>
        typeof window === "undefined" ? noopStorage : safeStorage
      ),
    }
  )
);

// ───────── محددات جاهزة ─────────

export const cartCount = (items: CartItem[]): number => items.reduce((a, i) => a + i.qty, 0);

export const cartSubtotal = (items: CartItem[]): number =>
  items.reduce((a, i) => a + i.qty * i.snapshot.price, 0);
