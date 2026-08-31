// ============================================================
// GREEN GOLD | التوصيل — مهام حسب الحالة + تعيين سائق + تسليم بـ OTP
// تحديث دوري كل 15 ثانية عندما تكون تبويب التوصيل ظاهرًا
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/admin.dart';
import '../../services/admin_service.dart';
import '../../state/staff.dart';
import '../../shared/widgets.dart';
import 'admin_common.dart';

final _deliveryStatusProvider = StateProvider<String?>((ref) => null);

final _deliveryProvider =
    FutureProvider.autoDispose<List<DeliveryTask>>((ref) async {
  ref.watch(adminDataVersionProvider);
  final status = ref.watch(_deliveryStatusProvider);
  return ref.watch(adminServiceProvider).fetchDeliveryTasks(status: status);
});

class _DeliveryFilter {
  final String? value;
  final String label;
  const _DeliveryFilter(this.value, this.label);
}

const List<_DeliveryFilter> _deliveryFilters = [
  _DeliveryFilter(null, 'الكل'),
  _DeliveryFilter('WAITING', 'بانتظار التعيين'),
  _DeliveryFilter('ASSIGNED', 'معيّن'),
  _DeliveryFilter('PICKED_UP', 'مستلم من المحل'),
  _DeliveryFilter('OUT_FOR_DELIVERY', 'في الطريق'),
  _DeliveryFilter('DELIVERED', 'مسلّم'),
  _DeliveryFilter('FAILED', 'تعذر'),
];

class AdminDeliveryScreen extends ConsumerWidget {
  const AdminDeliveryScreen({super.key});

  Future<void> _refresh(WidgetRef ref) =>
      swallowRefresh(ref.refresh(_deliveryProvider.future));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // المواصفة: الشاشة لمن يملك صلاحية manageDelivery فقط
    final staff = ref.watch(staffSessionProvider);
    if (!canRole(staff?.role, 'manageDelivery')) {
      return const EmptyState(
        emoji: '🚚',
        title: 'لا تملك صلاحية التوصيل',
        subtitle: 'إدارة مهام التوصيل متاحة للموظفين المخوّلين فقط',
      );
    }

    // التحديث الحي كل 15 ثانية عندما تكون تبويب التوصيل ظاهرة
    ref.listen(autoRefreshTickerProvider, (prev, next) {
      if (next.isLoading || !next.hasValue) return;
      if (ref.read(adminShellTabProvider) != 3) return;
      ref.invalidate(_deliveryProvider);
    });

    final status = ref.watch(_deliveryStatusProvider);
    final tasks = ref.watch(_deliveryProvider);

    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionTitle(
                    title: 'التوصيل', icon: Icons.local_shipping_rounded),
              ),
              IconButton(
                tooltip: 'تحديث',
                onPressed: () => _refresh(ref),
                icon: const Icon(Icons.refresh_rounded,
                    color: AppPalette.green),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'لا يكتمل التسليم إلا برمز العميل (OTP) — الرمز يظهر للمهمة بعد الخروج للتوصيل. تحديث تلقائي كل 15 ثانية.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _deliveryFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _deliveryFilters[i];
                final selected = status == f.value;
                return ChoiceChip(
                  label: Text(f.label),
                  selected: selected,
                  onSelected: (_) =>
                      ref.read(_deliveryStatusProvider.notifier).state = f.value,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF1B241E),
                  ),
                  selectedColor: AppPalette.green,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected
                        ? AppPalette.green
                        : const Color(0xFFD8E2DA),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          tasks.when(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => ErrorRetryView(
              message: e is ApiException
                  ? e.message
                  : 'تعذر تحميل مهام التوصيل، تحقق من الاتصال',
              onRetry: () => _refresh(ref),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  emoji: '🚚',
                  title: 'لا توجد مهام توصيل',
                  subtitle: 'تظهر المهام هنا فور خروج الطلبات للتوصيل',
                );
              }
              return Column(
                children: [
                  for (final t in list) _DeliveryTaskCard(task: t),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ───────── بطاقة مهمة توصيل ─────────

class _DeliveryTaskCard extends ConsumerWidget {
  final DeliveryTask task;
  const _DeliveryTaskCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = task;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الرأس
          Row(
            children: [
              Expanded(
                child: Text(
                  t.orderCode,
                  textDirection: TextDirection.ltr,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5),
                ),
              ),
              Text(
                formatYER(t.total),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (t.orderStatus != null) OrderStatusChip(status: t.orderStatus!),
              const SizedBox(width: 6),
              if (t.paymentStatus != null)
                PaymentStatusChip(status: t.paymentStatus!),
              const Spacer(),
              StatusChip(
                status: t.status,
                labels: kDeliveryStatusLabels,
                colors: _deliveryStatusColors,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // العميل
          Row(
            children: [
              Icon(Icons.person_rounded, size: 15, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  t.customerName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              Icon(Icons.call_rounded, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 3),
              Text(
                t.phone,
                textDirection: TextDirection.ltr,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined,
                  size: 15, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  [
                    if (t.zoneName != null && t.zoneName!.isNotEmpty) t.zoneName!,
                    if (t.addressText.isNotEmpty) t.addressText,
                  ].join(' — '),
                  style: TextStyle(
                      fontSize: 12, height: 1.4, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          if (t.driverName != null) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.badge_outlined,
                    size: 15, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'السائق: ${t.driverName}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
          if (t.status == 'FAILED' &&
              t.failReason != null &&
              t.failReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'تعذر التسليم: ${t.failReason}',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF991B1B)),
              ),
            ),
          ],
          // رمز العميل عند الخروج للتوصيل
          if (t.status == 'OUT_FOR_DELIVERY' &&
              t.otp != null &&
              t.otp!.isNotEmpty) ...[
            const SizedBox(height: 10),
            OtpGoldCard(otp: t.otp!),
          ],
          // أزرار الإجراء
          const SizedBox(height: 12),
          _actions(context, ref, t),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, WidgetRef ref, DeliveryTask t) {
    switch (t.status) {
      case 'WAITING':
        return FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppPalette.greenDeep),
          onPressed: () => _assign(context, ref, t),
          icon: const Icon(Icons.person_add_alt_rounded, size: 19),
          label: const Text('تعيين سائق'),
        );
      case 'ASSIGNED':
        return FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppPalette.greenDeep),
          onPressed: () => _confirmAndRun(
            context,
            ref,
            t,
            action: 'picked_up',
            title: 'تم استلام الطلب من المحل؟',
            message: 'تأكيد أن السائق استلم طلب ${t.orderCode} من المحل.',
            confirmLabel: 'تم الاستلام',
            successMsg: 'تم تسجيل استلام ${t.orderCode} من المحل',
          ),
          icon: const Icon(Icons.storefront_rounded, size: 19),
          label: const Text('تم الاستلام من المحل'),
        );
      case 'PICKED_UP':
        return FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppPalette.greenDeep),
          onPressed: () => _confirmAndRun(
            context,
            ref,
            t,
            action: 'out',
            title: 'خروج الطلب للتوصيل؟',
            message:
                'الطلب ${t.orderCode} خرج مع السائق إلى العميل ${t.customerName}.',
            confirmLabel: 'خرج للتوصيل',
            successMsg: 'خرج الطلب ${t.orderCode} للتوصيل',
          ),
          icon: const Icon(Icons.local_shipping_rounded, size: 19),
          label: const Text('خرج للتوصيل'),
        );
      case 'OUT_FOR_DELIVERY':
        return Column(
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.goldDark),
              onPressed: () => _deliver(context, ref, t),
              icon: const Icon(Icons.key_rounded, size: 19),
              label: const Text('تم التسليم — برمز العميل'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB91C1C),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
              ),
              onPressed: () => _fail(context, ref, t),
              icon: const Icon(Icons.cancel_outlined, size: 19),
              label: const Text('تعذر التسليم'),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ───────── الإجراءات ─────────

  Future<void> _assign(BuildContext context, WidgetRef ref, DeliveryTask t) async {
    final name = await textDialog(
      context,
      title: 'تعيين سائق',
      label: 'اسم السائق (إجباري)',
      hint: 'مثال: فهد',
      confirmLabel: 'تعيين',
    );
    if (name == null || name.trim().length < 2 || !context.mounted) return;
    final done = await guardedRun(
      ref,
      context,
      () => ref.read(adminServiceProvider).deliveryAction(
            t.id,
            'assign',
            driverName: name.trim(),
          ),
    );
    if (done && context.mounted) {
      showAppSnackBar(context, 'عُيّن ${name.trim()} لمهمة ${t.orderCode}');
      bumpAdminData(ref);
    }
  }

  Future<void> _confirmAndRun(
    BuildContext context,
    WidgetRef ref,
    DeliveryTask t, {
    required String action,
    required String title,
    required String message,
    required String confirmLabel,
    required String successMsg,
  }) async {
    final ok = await confirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    );
    if (!ok || !context.mounted) return;
    final done = await guardedRun(
      ref,
      context,
      () => ref.read(adminServiceProvider).deliveryAction(t.id, action),
    );
    if (done && context.mounted) {
      showAppSnackBar(context, successMsg);
      bumpAdminData(ref);
    }
  }

  Future<void> _deliver(BuildContext context, WidgetRef ref, DeliveryTask t) async {
    var otp = '';
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.key_rounded, color: AppPalette.gold, size: 22),
              SizedBox(width: 8),
              Text('رمز تسليم العميل',
                  style: TextStyle(fontSize: 16.5)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'اطلب من العميل ${t.customerName} رمز التسليم المكوّن من 4 أرقام للطلب ${t.orderCode}.',
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 16),
              OtpBoxes(
                onChanged: (v) {
                  otp = v;
                  if (error != null) setDialog(() => error = null);
                },
                invalid: error != null,
                errorText: error,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('تراجع'),
            ),
            FilledButton(
              onPressed: () {
                if (otp.length != 4) {
                  setDialog(() => error = 'أدخل الرمز المكوّن من 4 أرقام');
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('تأكيد التسليم'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = await guardedRun(
      ref,
      context,
      () => ref.read(adminServiceProvider).deliveryAction(
            t.id,
            'delivered',
            otp: otp,
          ),
    );
    if (done && context.mounted) {
      showAppSnackBar(context, 'تم التسليم بنجاح ✅ — ${t.orderCode}');
      bumpAdminData(ref);
    }
  }

  Future<void> _fail(BuildContext context, WidgetRef ref, DeliveryTask t) async {
    final reason = await textDialog(
      context,
      title: 'تعذر التسليم',
      label: 'سبب تعذر التسليم (إجباري)',
      hint: 'مثال: العميل لم يستجب، العنوان غير واضح…',
      confirmLabel: 'تسجيل التعذر',
      danger: true,
      minLen: 3,
    );
    if (reason == null || !context.mounted) return;
    final done = await guardedRun(
      ref,
      context,
      () => ref.read(adminServiceProvider).deliveryAction(
            t.id,
            'failed',
            failReason: reason,
          ),
    );
    if (done && context.mounted) {
      showAppSnackBar(context, 'سُجّل تعذر تسليم ${t.orderCode}');
      bumpAdminData(ref);
    }
  }
}

// ───────── ألوان حالات التوصيل ─────────

(Color, Color) _deliveryStatusColors(String status) {
  switch (status) {
    case 'WAITING':
      return (const Color(0xFFFEF3C7), const Color(0xFF92400E));
    case 'ASSIGNED':
      return (const Color(0xFFEDF3EE), AppPalette.greenDeep);
    case 'PICKED_UP':
      return (const Color(0xFFDCF5E4), const Color(0xFF115E59));
    case 'OUT_FOR_DELIVERY':
      return (AppPalette.goldLight, AppPalette.goldDark);
    case 'DELIVERED':
      return (AppPalette.greenLight, const Color(0xFF14532D));
    case 'FAILED':
      return (const Color(0xFFFEE2E2), const Color(0xFF991B1B));
    default:
      return (Colors.grey.shade200, Colors.grey.shade700);
  }
}
