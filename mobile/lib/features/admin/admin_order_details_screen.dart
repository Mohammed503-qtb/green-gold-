// ============================================================
// GREEN GOLD | تفاصيل الطلب — البيانات + بطاقة الدفع + آلة الحالات
// CONFIRMED→تجهيز→جاهز→خرج للتوصيل(OTP) + إلغاء/استرجاع + timeline
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../services/admin_service.dart';
import '../../state/staff.dart';
import '../../shared/widgets.dart';
import 'admin_common.dart';

class AdminOrderDetailsScreen extends ConsumerStatefulWidget {
  final String orderId;
  const AdminOrderDetailsScreen({super.key, required this.orderId});

  @override
  ConsumerState<AdminOrderDetailsScreen> createState() =>
      _AdminOrderDetailsScreenState();
}

class _AdminOrderDetailsScreenState
    extends ConsumerState<AdminOrderDetailsScreen> {
  Order? _order;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = _order == null);
    try {
      final o = await ref.read(adminServiceProvider).fetchOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = o;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = handleFetchError(ref, context, e);
      if (msg != null) {
        setState(() {
          _error = msg;
          _loading = false;
        });
      }
    }
  }

  // ───────── تنفيذ إجراء آلة الحالات ─────────

  Future<void> _runAction(String action, {String? note, String? successMsg}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await guarded(
      ref,
      context,
      () => ref
          .read(adminServiceProvider)
          .orderAction(widget.orderId, action, note: note),
    );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (result == null) return;
    setState(() => _order = result.order);
    bumpAdminData(ref);
    if (result.otp != null && result.otp!.isNotEmpty) {
      await showOtpDialog(context, result.order.orderCode, result.otp!);
    } else if (successMsg != null) {
      showAppSnackBar(context, successMsg);
    }
    _load(silent: true);
  }

  Future<void> _confirmAndRun({
    required String title,
    required String message,
    required String action,
    String? note,
    String? successMsg,
    bool danger = false,
    String confirmLabel = 'تأكيد',
  }) async {
    final ok = await confirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      danger: danger,
    );
    if (!ok || !mounted) return;
    _runAction(action, note: note, successMsg: successMsg);
  }

  // ───────── الإجراءات حسب الحالة ─────────

  List<Widget> _actionButtons(Order o) {
    final staff = ref.read(staffSessionProvider);
    final role = staff?.role;
    final canAdvance = canRole(role, 'advanceOrder');
    final isManagerial = role == 'OWNER' || role == 'MANAGER';
    final buttons = <_ActionSpec>[];

    if (canAdvance) {
      if (o.status == 'CONFIRMED') {
        buttons.add(_ActionSpec(
          label: 'بدء التجهيز',
          icon: Icons.soup_kitchen_rounded,
          run: () => _confirmAndRun(
            title: 'بدء تجهيز الطلب؟',
            message:
                'الطلب ${o.orderCode} — سيبدأ تجهيز الحزم للطلب ويظهر للعميل «جاري التجهيز».',
            action: 'start_preparing',
            confirmLabel: 'بدء التجهيز',
            successMsg: 'بدأ تجهيز الطلب ${o.orderCode}',
          ),
        ));
      }
      if (o.status == 'PREPARING') {
        buttons.add(_ActionSpec(
          label: 'جاهز للتوصيل',
          icon: Icons.checklist_rounded,
          run: () => _confirmAndRun(
            title: 'تأكيد جهوزية الطلب للتوصيل؟',
            message: 'سيصبح الطلب ${o.orderCode} جاهزًا للخروج مع السائق.',
            action: 'ready',
            confirmLabel: 'جاهز للتوصيل',
            successMsg: 'الطلب ${o.orderCode} جاهز للتوصيل',
          ),
        ));
      }
      if (o.status == 'READY_FOR_DELIVERY') {
        buttons.add(_ActionSpec(
          label: 'خرج للتوصيل',
          icon: Icons.local_shipping_rounded,
          gold: true,
          run: () => _confirmAndRun(
            title: 'خروج الطلب للتوصيل؟',
            message:
                'سيولّد النظام رمز تسليم (OTP) من 4 أرقام يُطلب من العميل عند الاستلام — تأكد من إبلاغه.',
            action: 'out_for_delivery',
            confirmLabel: 'خرج للتوصيل',
          ),
        ));
      }
      if (o.status == 'PENDING_PAYMENT' || o.status == 'PAYMENT_SUBMITTED') {
        buttons.add(_ActionSpec(
          label: 'إلغاء الطلب',
          icon: Icons.cancel_outlined,
          danger: true,
          run: () async {
            final note = await textDialog(
              context,
              title: 'إلغاء هذا الطلب؟',
              label: 'سبب الإلغاء (اختياري)',
              hint: 'مثال: العميل غيّر رأيه…',
              confirmLabel: 'متابعة',
              requiredText: false,
            );
            if (note == null || !mounted) return;
            await _confirmAndRun(
              title: 'تأكيد إلغاء الطلب؟',
              message:
                  'سيُلغى الطلب ${o.orderCode} وتُحرَّر الكميات المحجوزة فورًا. لا يمكن التراجع.',
              action: 'cancel',
              note: note,
              confirmLabel: 'إلغاء نهائي',
              danger: true,
              successMsg: 'تم إلغاء الطلب ${o.orderCode}',
            );
          },
        ));
      }
    }
    if (isManagerial &&
        o.payment?.status == 'PAID' &&
        ['CONFIRMED', 'PREPARING', 'READY_FOR_DELIVERY', 'OUT_FOR_DELIVERY', 'DELIVERED']
            .contains(o.status)) {
      buttons.add(_ActionSpec(
        label: 'استرجاع',
        icon: Icons.replay_rounded,
        outline: true,
        run: () async {
          final reason = await textDialog(
            context,
            title: 'استرجاع هذا الطلب؟',
            label: 'سبب الاسترجاع (إجباري)',
            hint: 'مثال: العميل أعاد الحزم…',
            confirmLabel: 'متابعة',
            minLen: 3,
          );
          if (reason == null || !mounted) return;
          await _confirmAndRun(
            title: 'تأكيد الاسترجاع؟',
            message:
                'سيُعلَّم الطلب ${o.orderCode} كـ«مسترجع» والدفع كـ«مسترجع». البضاعة لا تُرجَع للمخزون تلقائيًا.',
            action: 'refund',
            note: reason,
            confirmLabel: 'استرجاع نهائي',
            danger: true,
            successMsg: 'تم تسجيل الاسترجاع للطلب ${o.orderCode}',
          );
        },
      ));
    }

    return [
      for (final b in buttons)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _actionButton(b),
        ),
    ];
  }

  Widget _actionButton(_ActionSpec spec) {
    if (spec.outline) {
      return OutlinedButton.icon(
        onPressed: _busy ? null : spec.run,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF9A3412),
          side: const BorderSide(color: Color(0xFFFDBA74)),
        ),
        icon: Icon(spec.icon, size: 19),
        label: Text(spec.label),
      );
    }
    if (spec.danger) {
      return OutlinedButton.icon(
        onPressed: _busy ? null : spec.run,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFB91C1C),
          side: const BorderSide(color: Color(0xFFFCA5A5)),
        ),
        icon: Icon(spec.icon, size: 19),
        label: Text(spec.label),
      );
    }
    return FilledButton.icon(
      onPressed: _busy ? null : spec.run,
      style: spec.gold
          ? FilledButton.styleFrom(backgroundColor: AppPalette.goldDark)
          : FilledButton.styleFrom(backgroundColor: AppPalette.greenDeep),
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Icon(spec.icon, size: 19),
      label: Text(spec.label),
    );
  }

  // ───────── التحقق من الدفع ─────────

  Future<void> _verifyPayment({required bool approved}) async {
    final o = _order;
    if (o?.payment == null) return;
    String? reason;
    if (!approved) {
      reason = await textDialog(
        context,
        title: 'رفض الدفع',
        label: 'سبب الرفض (إجباري — يُرسل للعميل)',
        hint: 'مثال: رقم العملية غير مطابق للمبلغ المحوَّل…',
        confirmLabel: 'رفض نهائي',
        danger: true,
        minLen: 3,
      );
      if (reason == null || !mounted) return;
    } else {
      final ok = await confirmDialog(
        context,
        title: 'تأكيد استلام الدفع؟',
        message:
            'سيتم تحويل الكمية من «محجوز» إلى «مباع» نهائيًا وتأكيد الطلب وإخطار العميل.',
        confirmLabel: 'نعم، تأكيد الدفع',
      );
      if (!ok || !mounted) return;
    }
    final done = await guardedRun(
      ref,
      context,
      () => ref.read(adminServiceProvider).verifyPayment(
            o!.payment!.id,
            approved: approved,
            reason: reason,
          ),
    );
    if (done && mounted) {
      showAppSnackBar(
        context,
        approved ? 'تم تأكيد الدفع ✅ — ${o!.orderCode}' : 'تم رفض الدفع — ${o!.orderCode}',
      );
      bumpAdminData(ref);
      _load(silent: true);
    }
  }

  // ───────── البناء ─────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => _load(silent: _order != null),
            icon: const Icon(Icons.refresh_rounded, color: AppPalette.green),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorRetryView(message: _error!, onRetry: () => _load());
    }
    final o = _order;
    if (o == null) {
      return ErrorRetryView(
          message: 'تعذر تحميل الطلب', onRetry: () => _load());
    }

    final staff = ref.watch(staffSessionProvider);
    final canVerify = canRole(staff?.role, 'verifyPayment');

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _header(o),
          const SizedBox(height: 14),
          _customerCard(o),
          const SizedBox(height: 14),
          const SectionTitle(title: 'الأصناف', icon: Icons.grass_rounded),
          const SizedBox(height: 10),
          for (final item in o.items) _itemTile(item),
          const SizedBox(height: 14),
          _totalsCard(o),
          const SizedBox(height: 14),
          _paymentCard(o, canVerify),
          if (o.delivery != null) ...[
            const SizedBox(height: 14),
            _deliveryCard(o.delivery!),
          ],
          const SizedBox(height: 20),
          ..._actionButtons(o),
          if (o.history.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionTitle(
                title: 'سجل الحالات', icon: Icons.timeline_rounded),
            const SizedBox(height: 10),
            _historyCard(o),
          ],
        ],
      ),
    );
  }

  Widget _header(Order o) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppPalette.heroGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            o.orderCode,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OrderStatusChip(status: o.status),
              const SizedBox(width: 6),
              if (o.payment != null) PaymentStatusChip(status: o.payment!.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'أُنشئ ${timeAgoAr(o.createdAt)} • ${formatArabicDate(o.createdAt)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerCard(Order o) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'بيانات العميل', icon: Icons.person_rounded),
          const SizedBox(height: 8),
          DetailRow('الاسم', o.customerName, icon: Icons.person_outline_rounded, strong: true),
          DetailRow('الهاتف', o.phone, icon: Icons.call_outlined),
          if (o.zoneName != null)
            DetailRow('المنطقة', o.zoneName!, icon: Icons.map_outlined),
          DetailRow('العنوان', o.addressText, icon: Icons.location_on_outlined),
          if (o.note != null && o.note!.isNotEmpty)
            DetailRow('ملاحظة', o.note!, icon: Icons.sticky_note_2_outlined),
        ],
      ),
    );
  }

  Widget _itemTile(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAE4)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 58,
              height: 58,
              child: NetImage(url: item.mainImage),
            ),
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
                        item.productName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                    GradeBadge(grade: item.grade),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.batchCode,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatYER(item.unitPrice)} × ${formatNum(item.qty)} = ${formatYER(item.lineTotal)}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalsCard(Order o) {
    return _card(
      child: Column(
        children: [
          _totalRow('إجمالي الأصناف', formatYER(o.itemsTotal)),
          if (o.deliveryFee > 0)
            _totalRow('التوصيل (${o.zoneName ?? 'المنطقة'})', formatYER(o.deliveryFee)),
          if (o.discount > 0)
            _totalRow('الخصم', '- ${formatYER(o.discount)}'),
          const Divider(height: 18),
          _totalRow('الإجمالي', formatYER(o.total), strong: true),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: strong ? 15.5 : 13.5,
              fontWeight: FontWeight.w800,
              color: strong ? AppPalette.green : const Color(0xFF1B241E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(Order o, bool canVerify) {
    final p = o.payment;
    if (p == null) {
      return _card(
        child: DetailRow('الدفع', 'لا يوجد سجل دفع',
            icon: Icons.payment_rounded),
      );
    }
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: 'الدفع',
            icon: Icons.payments_rounded,
            trailing: PaymentStatusChip(status: p.status),
          ),
          const SizedBox(height: 8),
          DetailRow('المبلغ', formatYER(p.amount),
              icon: Icons.account_balance_wallet_outlined, strong: true),
          if (p.methodName != null)
            DetailRow('الطريقة', p.methodName!, icon: Icons.credit_card_rounded),
          if (p.transactionRef != null)
            DetailRow('رقم العملية', p.transactionRef!,
                icon: Icons.tag_rounded),
          DetailRow(
            'وقت الإرسال',
            p.submittedAt != null ? formatArabicDate(p.submittedAt) : '—',
            icon: Icons.schedule_rounded,
          ),
          if (p.verifiedAt != null)
            DetailRow(
              'وقت التحقق',
              formatArabicDate(p.verifiedAt),
              icon: Icons.verified_outlined,
            ),
          if (p.rejectReason != null && p.rejectReason!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: Color(0xFF991B1B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سبب الرفض: ${p.rejectReason}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (p.proofUrl != null && p.proofUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => showProofZoom(context, p.proofUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: ProofImage(url: p.proofUrl!),
                ),
              ),
            ),
          ],
          if (p.status == 'PENDING_VERIFICATION' && canVerify) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.greenDeep),
                    onPressed: _busy ? null : () => _verifyPayment(approved: true),
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
                    onPressed: _busy ? null : () => _verifyPayment(approved: false),
                    icon: const Icon(Icons.cancel_outlined, size: 19),
                    label: const Text('رفض'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _deliveryCard(DeliveryInfo d) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: 'التوصيل',
            icon: Icons.local_shipping_rounded,
            trailing: StatusChip(
              status: d.status,
              labels: kDeliveryStatusLabels,
              colors: _deliveryColors,
            ),
          ),
          const SizedBox(height: 8),
          if (d.driverName != null)
            DetailRow('السائق', d.driverName!,
                icon: Icons.badge_outlined, strong: true),
          if (d.assignedAt != null)
            DetailRow('التعيين', formatArabicDate(d.assignedAt),
                icon: Icons.schedule_rounded),
          if (d.deliveredAt != null)
            DetailRow('التسليم', formatArabicDate(d.deliveredAt),
                icon: Icons.where_to_vote_outlined),
          if (d.otp != null && d.otp!.isNotEmpty) ...[
            const SizedBox(height: 10),
            OtpGoldCard(otp: d.otp!),
          ],
        ],
      ),
    );
  }

  Widget _historyCard(Order o) {
    final entries = o.history.reversed.toList();
    return _card(
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            _historyEntry(entries[i], i, isLast: i == entries.length - 1),
        ],
      ),
    );
  }

  Widget _historyEntry(OrderHistoryEntry e, int index, {required bool isLast}) {
    final from = e.fromStatus == null
        ? '—'
        : (kOrderStatusLabels[e.fromStatus] ?? e.fromStatus!);
    final to = kOrderStatusLabels[e.toStatus] ?? e.toStatus;
    final actor = e.actor == 'CUSTOMER' ? 'العميل' : e.actor;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // خط زمني
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsetsDirectional.only(start: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == 0 ? AppPalette.green : AppPalette.greenLight,
                    border: Border.all(color: AppPalette.green),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsetsDirectional.only(start: 7),
                      color: AppPalette.greenLight,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.fromStatus == null
                              ? to
                              : '$from ← $to',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        timeAgoAr(e.createdAt),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    actor,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600),
                  ),
                  if (e.note != null && e.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      e.note!,
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3EAE4)),
        ),
        child: child,
      );
}

// ───────── مواصفات زر إجراء ─────────

class _ActionSpec {
  final String label;
  final IconData icon;
  final Future<void> Function() run;
  final bool danger;
  final bool gold;
  final bool outline;

  const _ActionSpec({
    required this.label,
    required this.icon,
    required this.run,
    this.danger = false,
    this.gold = false,
    this.outline = false,
  });
}

// ───────── ألوان حالات التوصيل ─────────

(Color, Color) _deliveryColors(String status) {
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
