"use client";

// ============================================================
// GREEN GOLD | غلاف الإدارة
// شريط تنقل بأيقونات + إشعارات (polling 15s) + لوحة معلومات حية
// + إخفاء الأقسام حسب صلاحيات الدور (CAN) + خروج وجلسة PIN
// ============================================================

import { useCallback, useEffect, useRef, useState } from "react";
import {
  LayoutDashboard,
  ClipboardList,
  BadgeDollarSign,
  Package,
  Truck,
  Users,
  BarChart3,
  ScrollText,
  Bell,
  LogOut,
  Leaf,
  Store,
  BellRing,
  Loader2,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { cn } from "@/lib/utils";
import {
  CAN,
  STAFF_ROLES,
  type OrderStatus,
} from "@/lib/contracts";
import {
  ADMIN_REFRESH_EVENT,
  STAFF_UNAUTHORIZED_EVENT,
  adminApi,
  clearStaff,
  formatNum,
  getStaff,
  normalizeDashboard,
  normalizeNotifications,
  type AdminNotificationDTO,
  type DashboardDTO,
  type StaffSession,
} from "./api";
import { LoginScreen } from "./login";
import { Dashboard, timeAgoArSafe, type AdminSection } from "./dashboard";
import { OrdersManager } from "./orders-manager";
import { PaymentsVerifier } from "./payments-verifier";
import { BatchesManager } from "./batches-manager";
import { Inventory } from "./inventory";
import { Delivery } from "./delivery";
import { Customers } from "./customers";
import { Reports } from "./reports";
import { AuditLog } from "./audit-log";

interface AdminAppProps {
  /** العودة إلى واجهة العميل */
  onExit: () => void;
}

export function AdminApp({ onExit }: AdminAppProps) {
  const [session, setSession] = useState<StaffSession | null>(null);
  const [ready, setReady] = useState(false);

  const [section, setSection] = useState<AdminSection>("dashboard");
  const [ordersStatus, setOrdersStatus] = useState<OrderStatus | "ALL">("ALL");

  // لوحة المعلومات + الإشعارات (polling)
  const [dash, setDash] = useState<DashboardDTO | null>(null);
  const [dashLoading, setDashLoading] = useState(true);
  const [notifications, setNotifications] = useState<AdminNotificationDTO[]>([]);
  const [notifOpen, setNotifOpen] = useState(false);
  const pollsRef = useRef<{ dash?: boolean; notif?: boolean }>({});

  // ── تحميل الجلسة ──
  useEffect(() => {
    setSession(getStaff());
    setReady(true);
  }, []);

  // ── خروج تلقائي عند 401 ──
  useEffect(() => {
    const handler = () => setSession(null);
    window.addEventListener(STAFF_UNAUTHORIZED_EVENT, handler);
    return () => window.removeEventListener(STAFF_UNAUTHORIZED_EVENT, handler);
  }, []);

  const canDashboard = (s: StaffSession) =>
    ["OWNER", "MANAGER", "STAFF"].includes(s.role);

  const loadDashboard = useCallback(async () => {
    if (pollsRef.current.dash) return;
    pollsRef.current.dash = true;
    setDashLoading(true);
    try {
      const data = await adminApi.get<unknown>("/api/admin/dashboard", { silent: true });
      setDash(normalizeDashboard(data));
    } catch {
      setDash((d) => d); // أبقِ آخر بيانات ناجحة
    } finally {
      pollsRef.current.dash = false;
      setDashLoading(false);
    }
  }, []);

  const loadNotifications = useCallback(async () => {
    if (pollsRef.current.notif) return;
    pollsRef.current.notif = true;
    try {
      const data = await adminApi.get<unknown>("/api/notifications?audience=ADMIN", {
        silent: true,
      });
      setNotifications(normalizeNotifications(data));
    } catch {
      // إشعارات غير حرجة
    } finally {
      pollsRef.current.notif = false;
    }
  }, []);

  // ── polling كل 15 ثانية + استجابة فورية لحدث التحديث ──
  useEffect(() => {
    if (!session || !canDashboard(session)) return;
    void loadDashboard();
    void loadNotifications();
    const interval = setInterval(() => {
      void loadDashboard();
      void loadNotifications();
    }, 15000);
    const onRefresh = () => {
      void loadDashboard();
      void loadNotifications();
    };
    window.addEventListener(ADMIN_REFRESH_EVENT, onRefresh);
    return () => {
      clearInterval(interval);
      window.removeEventListener(ADMIN_REFRESH_EVENT, onRefresh);
    };
  }, [session, loadDashboard, loadNotifications]);

  if (!ready) {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-background" aria-busy="true">
        <Loader2 className="text-primary size-8 animate-spin" aria-hidden="true" />
      </div>
    );
  }

  if (!session) {
    return <LoginScreen onSuccess={setSession} onExit={onExit} />;
  }

  // ── الأقسام المتاحة حسب الدور ──
  const role = session.role;
  const can = {
    orders: (CAN.advanceOrder as readonly string[]).includes(role),
    payments: (CAN.verifyPayment as readonly string[]).includes(role),
    batches: (CAN.manageBatches as readonly string[]).includes(role),
    delivery: (CAN.manageDelivery as readonly string[]).includes(role),
    customers: ["OWNER", "MANAGER", "STAFF"].includes(role),
    reports: (CAN.viewReports as readonly string[]).includes(role),
    audit: (CAN.viewAudit as readonly string[]).includes(role),
  };

  type NavItem = { key: AdminSection; label: string; icon: typeof LayoutDashboard; show: boolean };
  const ALL_NAV: NavItem[] = [
    { key: "dashboard", label: "الرئيسية", icon: LayoutDashboard, show: canDashboard(session) },
    { key: "orders", label: "الطلبات", icon: ClipboardList, show: can.orders },
    { key: "payments", label: "الدفعات", icon: BadgeDollarSign, show: can.payments },
    { key: "inventory", label: "المخزون", icon: Package, show: can.batches },
    { key: "delivery", label: "التوصيل", icon: Truck, show: can.delivery },
    { key: "customers", label: "العملاء", icon: Users, show: can.customers },
    { key: "reports", label: "التقارير", icon: BarChart3, show: can.reports },
    { key: "audit", label: "السجل", icon: ScrollText, show: can.audit },
  ];
  const NAV = ALL_NAV.filter((n) => n.show);

  const active =
    NAV.some((n) => n.key === section) ? section : (NAV[0]?.key ?? "delivery");

  const navigate = (s: AdminSection, status?: OrderStatus) => {
    if (status !== undefined) setOrdersStatus(status);
    setSection(s);
  };

  const unread = notifications.filter((n) => !n.read).length;
  const pendingVerify = dash?.today.pendingVerify ?? 0;

  const logout = () => {
    clearStaff();
    setSession(null);
    setDash(null);
    setNotifications([]);
    setSection("dashboard");
  };

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-background" dir="rtl" role="application" aria-label="واجهة إدارة ذهب أخضر">
      {/* الشريط العلوي */}
      <header className="sticky top-0 z-20 border-b bg-gradient-to-l from-primary to-emerald-800 text-white shadow-md">
        <div className="mx-auto flex h-14 w-full max-w-7xl items-center gap-2 px-3 sm:px-4">
          <div className="flex items-center gap-2">
            <span className="gold-glow flex size-9 items-center justify-center rounded-xl bg-white/95">
              <Leaf className="text-primary size-5" aria-hidden="true" />
            </span>
            <div className="leading-tight">
              <p className="text-sm font-extrabold">
                ذهب <span className="gold-text">أخضر</span> — الإدارة
              </p>
              <p className="text-[10px] text-emerald-100/90">قات اليوم في عدن</p>
            </div>
          </div>

          <div className="ms-auto flex items-center gap-1.5 sm:gap-2">
            {/* الإشعارات */}
            <Popover open={notifOpen} onOpenChange={setNotifOpen}>
              <PopoverTrigger asChild>
                <Button
                  variant="ghost"
                  size="icon"
                  className="relative text-white hover:bg-white/15"
                  aria-label={`الإشعارات${unread ? ` — ${unread} غير مقروء` : ""}`}
                >
                  {unread > 0 ? <BellRing className="size-5" aria-hidden="true" /> : <Bell className="size-5" aria-hidden="true" />}
                  {unread > 0 ? (
                    <span className="absolute top-1 left-1 flex min-w-4 items-center justify-center rounded-full bg-amber-400 px-1 text-[10px] font-black text-amber-950 tabular-nums">
                      {formatNum(Math.min(unread, 99))}
                    </span>
                  ) : null}
                </Button>
              </PopoverTrigger>
              <PopoverContent align="end" className="w-80 p-0" dir="rtl">
                <div className="border-b p-3">
                  <p className="flex items-center gap-1.5 text-sm font-extrabold">
                    <Bell className="text-primary size-4" aria-hidden="true" /> إشعارات الإدارة
                    {unread > 0 ? (
                      <Badge variant="outline" className="border-amber-300 bg-amber-50 text-[10px] text-amber-800 dark:border-amber-900 dark:bg-amber-500/15">
                        {formatNum(unread)} جديد
                      </Badge>
                    ) : null}
                  </p>
                </div>
                {notifications.length === 0 ? (
                  <p className="text-muted-foreground p-4 text-center text-xs">لا توجد إشعارات بعد</p>
                ) : (
                  <ul className="max-h-96 overflow-y-auto" aria-label="قائمة الإشعارات">
                    {notifications.map((n) => (
                      <li key={n.id} className={cn("border-b p-3 last:border-b-0", !n.read && "bg-amber-50/60 dark:bg-amber-500/5")}>
                        <div className="flex items-start justify-between gap-2">
                          <p className="text-xs font-extrabold">{n.title}</p>
                          <span className="text-muted-foreground shrink-0 text-[10px]">{timeAgoArSafe(n.createdAt)}</span>
                        </div>
                        <p className="text-muted-foreground mt-0.5 text-[11px] leading-relaxed">{n.body}</p>
                        {n.orderCode ? (
                          <Badge variant="secondary" className="mt-1 font-mono text-[10px]" dir="ltr">
                            {n.orderCode}
                          </Badge>
                        ) : null}
                      </li>
                    ))}
                  </ul>
                )}
              </PopoverContent>
            </Popover>

            {/* الموظف */}
            <div className="hidden items-center gap-2 rounded-xl bg-white/10 px-3 py-1.5 sm:flex">
              <div className="text-left leading-tight">
                <p className="text-xs font-extrabold">{session.name}</p>
                <p className="text-[10px] text-emerald-100/90">{STAFF_ROLES[session.role]}</p>
              </div>
              <span className="flex size-7 items-center justify-center rounded-full bg-amber-400 text-xs font-black text-amber-950">
                {session.name.slice(0, 1)}
              </span>
            </div>

            {/* خروج */}
            <Button
              variant="ghost"
              size="icon"
              className="text-white hover:bg-white/15"
              onClick={logout}
              aria-label="تسجيل الخروج من الإدارة"
              title="تسجيل الخروج"
            >
              <LogOut className="size-5" aria-hidden="true" />
            </Button>

            {/* العودة للمتجر */}
            <Button
              variant="ghost"
              className="h-9 gap-1.5 rounded-xl bg-white/10 px-2.5 text-xs font-bold text-white hover:bg-white/20"
              onClick={onExit}
              aria-label="العودة إلى واجهة العميل"
            >
              <Store className="size-4" aria-hidden="true" />
              <span className="hidden sm:inline">المتجر</span>
            </Button>
          </div>
        </div>

        {/* شريط التنقل */}
        <nav className="mx-auto w-full max-w-7xl overflow-x-auto" aria-label="أقسام الإدارة">
          <div className="flex gap-1 px-2 pb-2 sm:px-3">
            {NAV.map((n) => {
              const Icon = n.icon;
              const isActive = active === n.key;
              const badge =
                n.key === "payments" ? pendingVerify : n.key === "orders" ? 0 : 0;
              return (
                <button
                  key={n.key}
                  onClick={() => navigate(n.key)}
                  className={cn(
                    "relative flex shrink-0 items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-bold transition",
                    isActive
                      ? "bg-white text-primary shadow"
                      : "text-emerald-50 hover:bg-white/15"
                  )}
                  aria-current={isActive ? "page" : undefined}
                >
                  <Icon className="size-4" aria-hidden="true" />
                  {n.label}
                  {badge > 0 ? (
                    <span className="flex min-w-4 items-center justify-center rounded-full bg-amber-400 px-1 text-[10px] font-black text-amber-950 tabular-nums">
                      {formatNum(badge)}
                    </span>
                  ) : null}
                </button>
              );
            })}
          </div>
        </nav>
      </header>

      {/* المحتوى */}
      <main className="flex-1 overflow-y-auto">
        <div className="mx-auto w-full max-w-7xl p-3 pb-10 sm:p-4">
          {active === "dashboard" ? (
            <Dashboard
              data={dash}
              loading={dashLoading && !dash}
              session={session}
              onNavigate={navigate}
            />
          ) : null}

          {active === "orders" ? (
            <OrdersManager session={session} initialStatus={ordersStatus} />
          ) : null}

          {active === "payments" ? (
            <PaymentsVerifier
              payments={dash?.pendingPayments ?? []}
              loading={dashLoading && !dash}
              onRefresh={() => {
                void loadDashboard();
                void loadNotifications();
              }}
            />
          ) : null}

          {active === "inventory" ? (
            <Tabs defaultValue="batches">
              <TabsList className="mb-3 bg-muted/60">
                <TabsTrigger value="batches" className="gap-1.5 text-xs font-bold">
                  <Package className="size-4" aria-hidden="true" /> إدارة الدفعات
                </TabsTrigger>
                <TabsTrigger value="table" className="gap-1.5 text-xs font-bold">
                  <LayoutDashboard className="size-4" aria-hidden="true" /> جدول المخزون والحركات
                </TabsTrigger>
              </TabsList>
              <TabsContent value="batches">
                <BatchesManager session={session} />
              </TabsContent>
              <TabsContent value="table">
                <Inventory session={session} />
              </TabsContent>
            </Tabs>
          ) : null}

          {active === "delivery" ? <Delivery /> : null}
          {active === "customers" ? <Customers /> : null}
          {active === "reports" ? <Reports /> : null}
          {active === "audit" ? <AuditLog /> : null}
        </div>
      </main>

      {/* شريط سفلي صغير للموبايل — دور الموظف */}
      <footer className="border-t bg-muted/40 px-3 py-1.5 text-center sm:hidden">
        <p className="text-muted-foreground text-[10px]">
          {session.name} • {STAFF_ROLES[session.role]}
        </p>
      </footer>
    </div>
  );
}
