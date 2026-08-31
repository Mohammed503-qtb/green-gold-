// ============================================================
// GREEN GOLD | لوحة معلومات الإدارة — KPI + التحقق المالي + الإشعارات
// تحديث دوري كل 15 ثانية (autoRefreshTickerProvider) + سحب للتحديث
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/admin.dart';
import '../../models/order.dart';
import '../../services/admin_service.dart';
import '../../state/staff.dart';
import '../../shared/widgets.dart';
import 'admin_common.dart';
import 'admin_order_details_screen.dart';

final _dashboardProvider =
    FutureProvider.autoDispose<DashboardData>((ref) async {
  ref.watch(adminDataVersionProvider);
  return ref.watch(adminServiceProvider).fetchDashboard();
});

final _notificationsProvider =
    FutureProvider.autoDispose<List<AdminNotification>>((ref) async {
  ref.watch(adminDataVersionProvider);
  return ref.watch(adminServiceProvider).fetchNotifications();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // التحديث الحي كل 15 ثانية عندما تكون اللوحة هي الوجهة الظاهرة
    ref.listen(autoRefreshTickerProvider, (prev, next) {
      if (next.isLoading || !next.hasValue) return;
      if (ref.read(adminShellTabProvider) != 0) return;
      ref.invalidate(_dashboardProvider);
      ref.invalidate(_notificationsProvider);
    });

    final dash = ref.watch(_dashboardProvider);
    final notifs = ref.watch(_notificationsProvider);
    final staff = ref.watch(staffSessionProvider);
    final canVerify = canRole(staff?.role, 'verifyPayment');
    final unread = (notifs.value ?? []).where((n) => !n.read).length;

    return RefreshIndicator(
      onRefresh: () => _refreshAll(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionTitle(
                    title: 'لوحة المعلومات',
                    icon: Icons.dashboard_rounded),
              ),
              // جرس الإشعارات
              Badge(
                isLabelVisible: unread > 0,
                backgroundColor: const Color(0xFFC9A227),
                label: Text('$unread',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800)),
                child: IconButton(
                  tooltip: 'الإشعارات',
                  onPressed: () => _showNotifications(context, ref),
                  icon: const Icon(Icons.notifications_outlined,
                      color: AppPalette.green),
                ),
              ),
              IconButton(
                tooltip: 'تحديث',
                onPressed: () => _refreshAll(ref),
                icon: const Icon(Icons.refresh_rounded,
                    color: AppPalette.green),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'تحديث تلقائي كل 15 ثانية',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 14),
          ...dash.when(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            loading: () => const [_DashboardSkeleton()],
            error: (e, _) => [
              ErrorRetryView(
                message: e is ApiException
                    ? e.message
                    : 'تعذر تحميل لوحة المعلومات، تحقق من الاتصال',
                onRetry: () => _refreshAll(ref),
              ),
            ],
            data: (d) => [
              _kpiGrid(d),
              const SizedBox(height: 16),
              if (canVerify) ..._pendingPaymentsSection(context, ref, d),
              const SizedBox(height: 16),
              ..._recentOrdersSection(context, d),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAll(WidgetRef ref) async {
    try {
      await Future.wait([
        ref.refresh(_dashboardProvider.future),
        ref.refresh(_notificationsProvider.future),
      ]);
    } catch (_) {
      // الأخطاء تظهر في حالة الـ provider
    }
  }

  // ───────── صف بطاقات KPI ─────────

  Widget _kpiGrid(DashboardData d) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: KpiCard(
                icon: Icons.payments_outlined,
                label: 'مبيعات اليوم',
                value: formatYER(d.todaySales),
                tone: KpiTone.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KpiCard(
                icon: Icons.receipt_long_outlined,
                label: 'طلبات اليوم',
                value: formatNum(d.todayOrders),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: KpiCard(
                icon: Icons.verified_outlined,
                label: 'مدفوع اليوم',
                value: formatNum(d.paidCount),
                tone: KpiTone.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KpiCard(
                icon: Icons.hourglass_top_rounded,
                label: 'بانتظار التحقق',
                value: formatNum(d.pendingVerify),
                tone: d.pendingVerify > 0 ? KpiTone.gold : KpiTone.normal,
                sub: d.pendingVerify > 0 ? 'اضغط للمعالجة الآن ←' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        KpiCard(
          icon: Icons.local_shipping_outlined,
          label: 'خرج للتوصيل اليوم',
          value: formatNum(d.outForDelivery),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: KpiCard(
                icon: Icons.grass_outlined,
                label: 'دفعات نشطة',
                value: formatNum(d.activeBatches),
                tone: KpiTone.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KpiCard(
                icon: Icons.warning_amber_rounded,
                label: 'مخزون منخفض',
                value: formatNum(d.lowStock),
                tone: d.lowStock > 0 ? KpiTone.warning : KpiTone.normal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KpiCard(
                icon: Icons.block_outlined,
                label: 'دفعات نافدة',
                value: formatNum(d.soldOut),
                tone: d.soldOut > 0 ? KpiTone.danger : KpiTone.normal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ───────── بانتظار التحقق — القلب المالي ─────────

  List<Widget> _pendingPaymentsSection(
      BuildContext context, WidgetRef ref, DashboardData d) {
    return [
      SectionTitle(
        title: 'دفعات بانتظار التحقق',
        icon: Icons.hourglass_top_rounded,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppPalette.goldLight,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${formatNum(d.pendingPayments.length)} بانتظار',
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppPalette.goldDark),
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (d.pendingPayments.isEmpty)
        _infoBox('✅ لا توجد دفعات بانتظار التحقق',
            'ستظهر هنا فورًا كل إثباتات الدفع التي يرسلها العملاء')
      else
        for (final p in d.pendingPayments) _PendingPaymentCard(payment: p),
    ];
  }

  Widget _infoBox(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.greenLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.greenLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ───────── آخر الطلبات ─────────

  List<Widget> _recentOrdersSection(BuildContext context, DashboardData d) {
    return [
      const SectionTitle(
          title: 'آخر الطلبات', icon: Icons.receipt_long_rounded),
      const SizedBox(height: 10),
      if (d.recentOrders.isEmpty)
        _infoBox('لا توجد طلبات بعد', 'ستظهر الطلبات الجديدة هنا فورًا')
      else
        ...d.recentOrders.take(8).map((o) => _RecentOrderTile(order: o)),
    ];
  }

  // ───────── الإشعارات ─────────

  void _showNotifications(BuildContext context, WidgetRef ref) {
    final notifs = ref.read(_notificationsProvider).value ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final list = notifs.take(10).toList();
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.92,
          expand: false,
          builder: (ctx, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              const SectionTitle(
                  title: 'الإشعارات', icon: Icons.notifications_active_outlined),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const EmptyState(
                    emoji: '🔔',
                    title: 'لا توجد إشعارات',
                    subtitle: 'ستظهر هنا الطلبات الجديدة وإثباتات الدفع وتنبيهات المخزون')
              else
                for (final n in list) _NotificationTile(notification: n),
            ],
          ),
        );
      },
    );
  }
}

// ───────── بطاقة دفعة بانتظار التحقق ─────────

class _PendingPaymentCard extends ConsumerWidget {
  final PendingPayment payment;
  const _PendingPaymentCard({required this.payment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = payment;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.gold.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.customerName,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      p.orderCode,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Text(
                formatYER(p.amount),
                style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (p.methodName != null)
                MiniChip(
                  text: p.methodName!,
                  bg: const Color(0xFFEDF3EE),
                  fg: AppPalette.greenDeep,
                ),
              if (p.transactionRef != null)
                MiniChip(
                  text: 'مرجع: ${p.transactionRef!}',
                  bg: Colors.grey.shade100,
                  fg: Colors.grey.shade700,
                ),
              MiniChip(
                text: timeAgoAr(p.submittedAt),
                bg: Colors.grey.shade100,
                fg: Colors.grey.shade700,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (p.proofUrl != null && p.proofUrl!.isNotEmpty)
            GestureDetector(
              onTap: () => showProofZoom(context, p.proofUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: ProofImage(url: p.proofUrl!),
                ),
              ),
            )
          else
            Container(
              height: 60,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid),
              ),
              child: Text(
                'لا توجد صورة إثبات — تحقق من رقم العملية',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.greenDeep),
                  onPressed: () => _approve(context, ref),
                  icon: const Icon(Icons.check_circle_outline, size: 19),
                  label: const Text('تأكيد الدفع'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                  ),
                  onPressed: () => _reject(context, ref),
                  icon: const Icon(Icons.cancel_outlined, size: 19),
                  label: const Text('رفض'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'تأكيد استلام الدفع؟',
      message:
          'الطلب ${payment.orderCode} — ${payment.customerName} بمبلغ ${formatYER(payment.amount)}.\n\n'
          'سيتم تحويل الكمية من «محجوز» إلى «مباع» نهائيًا وتأكيد الطلب وإخطار العميل.',
      confirmLabel: 'نعم، تأكيد الدفع',
    );
    if (!ok || !context.mounted) return;
    final done = await guardedRun(ref, context, () => ref
        .read(adminServiceProvider)
        .verifyPayment(payment.paymentId, approved: true));
    if (done && context.mounted) {
      showAppSnackBar(context, 'تم تأكيد الدفع ✅ — ${payment.orderCode}');
      bumpAdminData(ref);
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await textDialog(
      context,
      title: 'رفض الدفع',
      label: 'سبب الرفض (إجباري — يُرسل للعميل)',
      hint: 'مثال: رقم العملية غير مطابق للمبلغ المحوَّل…',
      confirmLabel: 'رفض نهائي',
      danger: true,
      minLen: 3,
    );
    if (reason == null || !context.mounted) return;
    final done = await guardedRun(
      ref,
      context,
      () => ref
          .read(adminServiceProvider)
          .verifyPayment(payment.paymentId, approved: false, reason: reason),
    );
    if (done && context.mounted) {
      showAppSnackBar(context, 'تم رفض الدفع — ${payment.orderCode}');
      bumpAdminData(ref);
    }
  }
}

// ───────── بطاقة طلب مختصرة ─────────

class _RecentOrderTile extends StatelessWidget {
  final Order order;
  const _RecentOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAE4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AdminOrderDetailsScreen(orderId: order.id))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              order.orderCode,
                              textDirection: TextDirection.ltr,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 6),
                          OrderStatusChip(status: order.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.customerName} • ${formatNum(order.items.length)} صنف • ${timeAgoAr(order.createdAt)}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatYER(order.total),
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.green),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────── إشعار ─────────

class _NotificationTile extends StatelessWidget {
  final AdminNotification notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: n.read
            ? Theme.of(context).colorScheme.surface
            : AppPalette.greenLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: n.read ? const Color(0xFFE3EAE4) : AppPalette.greenLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppPalette.greenLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.campaign_rounded,
                size: 18, color: AppPalette.greenDeep),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: n.read ? FontWeight.w700 : FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!n.read)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppPalette.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  n.body,
                  style: TextStyle(
                      fontSize: 12, height: 1.5, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (n.orderCode != null && n.orderCode!.isNotEmpty)
                      Text(
                        n.orderCode!,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600),
                      ),
                    const Spacer(),
                    Text(
                      timeAgoAr(n.createdAt),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────── هيكل تحميل ─────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box() => const _SkeletonBox(height: 74);
    return Column(
      children: [
        Row(
          children: [box(), const SizedBox(width: 10), box()],
        ),
        const SizedBox(height: 10),
        Row(
          children: [box(), const SizedBox(width: 10), box()],
        ),
        const SizedBox(height: 10),
        box(),
        const SizedBox(height: 16),
        const _SkeletonBox(height: 120),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  const _SkeletonBox({required this.height});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFEDF3EE),
          borderRadius: BorderRadius.circular(16),
        ),
      );
}
