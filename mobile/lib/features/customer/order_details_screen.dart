// ============================================================
// GREEN GOLD | تتبع الطلب — شريط خطوات + دفع + إثبات + تقييم
// + إعادة الطلب + واتساب دائم (تحديث دوري كل 15 ثانية)
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/checkout.dart';
import '../../models/order.dart';
import '../../services/customer_services.dart';
import '../../shared/widgets.dart';
import '../../state/cart.dart';
import 'cart_screen.dart';
import 'customer_helpers.dart';

const List<String> _kFailedStatuses = [
  'CANCELLED',
  'PAYMENT_REJECTED',
  'REFUNDED',
  'FAILED_DELIVERY',
];

/// تتبع طلب برمزه وهاتف صاحبه — يُحدَّث تلقائيًا كل 15 ثانية
final orderDetailsProvider =
    FutureProvider.autoDispose.family<Order, (String, String)>((ref, arg) {
  ref.watch(autoRefreshTickerProvider);
  return ref.watch(ordersServiceProvider).fetchOrderByCode(arg.$1, arg.$2);
});

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final String orderCode;
  final String phone;

  const OrderDetailsScreen({
    super.key,
    required this.orderCode,
    required this.phone,
  });

  @override
  ConsumerState<OrderDetailsScreen> createState() =>
      _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  (String, String) get _arg => (widget.orderCode, widget.phone);

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailsProvider(_arg));
    final checkout = ref.watch(checkoutDataProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تتبع الطلب'),
        actions: [
          IconButton(
            tooltip: 'تحديث الطلب',
            onPressed: () => ref.invalidate(orderDetailsProvider(_arg)),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: orderAsync.when(
        loading: () => _buildSkeleton(),
        error: (e, _) => ErrorRetryView(
          message: e is ApiException
              ? e.message
              : 'تعذر جلب الطلب — تأكد من رقم الهاتف المسجّل به 🌿',
          onRetry: () => ref.invalidate(orderDetailsProvider(_arg)),
        ),
        data: (order) => RefreshIndicator(
          onRefresh: () => ref.refresh(orderDetailsProvider(_arg).future),
          child: _buildContent(context, order, checkout),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    final base = Colors.grey.shade300;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(
        4,
        (_) => Container(
          height: 110,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Order order,
    CheckoutData? checkout,
  ) {
    final whatsapp = checkout?.whatsapp ?? '967771234567';
    final methods = checkout?.methods ?? const <PaymentMethod>[];
    final canAttachProof = order.status == 'PENDING_PAYMENT' ||
        order.status == 'PAYMENT_REJECTED';
    final canReview = order.status == 'DELIVERED' && !order.reviewed;
    final flowIdx = kOrderFlow.indexOf(order.status);
    final canReorder = flowIdx >= kOrderFlow.indexOf('CONFIRMED') &&
        flowIdx <= kOrderFlow.indexOf('DELIVERED');

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        _headerCard(context, order),
        const SizedBox(height: 10),
        ..._statusAlerts(context, order),
        _trackBar(context, order),
        const SizedBox(height: 10),
        if (canAttachProof) ...[
          _attachProofButton(context, order, methods),
          const SizedBox(height: 10),
        ],
        _itemsCard(context, order),
        const SizedBox(height: 10),
        if (order.payment != null && order.payment!.status != 'UNPAID') ...[
          _paymentCard(context, order),
          const SizedBox(height: 10),
        ],
        _addressCard(context, order),
        const SizedBox(height: 10),
        if (order.delivery != null) ...[
          _deliveryCard(context, order),
          const SizedBox(height: 10),
        ],
        if (canReview) ...[
          _reviewCard(context, order),
          const SizedBox(height: 10),
        ],
        if (order.history.isNotEmpty) ...[
          _historyCard(context, order),
          const SizedBox(height: 10),
        ],
        if (canReorder) ...[
          OutlinedButton.icon(
            onPressed: () => _reorder(order),
            icon: const Icon(Icons.replay_rounded, size: 20),
            label: const Text('إعادة الطلب'),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1FAA53),
              foregroundColor: Colors.white,
            ),
            onPressed: () => launchWhatsApp(
                context, whatsapp, orderWaMessage(order.orderCode)),
            icon: const Icon(Icons.chat_rounded, size: 20),
            label: const Text('متابعة الطلب عبر واتساب',
                style: TextStyle(fontSize: 15.5)),
          ),
        ),
      ],
    );
  }

  // ───────── الرأس ─────────

  Widget _headerCard(BuildContext context, Order order) {
    final hintColor = Theme.of(context).hintColor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  order.orderCode,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    letterSpacing: 1,
                  ),
                ),
                IconButton(
                  tooltip: 'نسخ رقم الطلب',
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: order.orderCode));
                    if (mounted) {
                      showAppSnackBar(
                          this.context, 'تم النسخ ✅ ${order.orderCode}');
                    }
                  },
                  icon: const Icon(Icons.copy, size: 18),
                ),
                const Spacer(),
                OrderStatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                PaymentStatusChip(status: order.payment?.status ?? 'UNPAID'),
                const SizedBox(width: 8),
                Text(
                  formatArabicDate(order.createdAt),
                  style: TextStyle(fontSize: 11.5, color: hintColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────── التنبيهات ─────────

  List<Widget> _statusAlerts(BuildContext context, Order order) {
    final widgets = <Widget>[];

    Widget alert({
      required Color bg,
      required Color border,
      required Color fg,
      required String title,
      required String body,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14, color: fg)),
            const SizedBox(height: 4),
            Text(body,
                style: TextStyle(
                    fontSize: 12.5, height: 1.6, color: fg)),
          ],
        ),
      );
    }

    switch (order.status) {
      case 'PENDING_PAYMENT':
        widgets.add(alert(
          bg: const Color(0xFFFFFBEB),
          border: const Color(0xFFF59E0B),
          fg: const Color(0xFF92400E),
          title: '⏳ بانتظار الدفع',
          body: 'أكمل الدفع وأرفق الإثبات ليتم تأكيد طلبك.',
        ));
      case 'PAYMENT_SUBMITTED':
        widgets.add(alert(
          bg: const Color(0xFFECFDF5),
          border: AppPalette.green,
          fg: const Color(0xFF065F46),
          title: '✅ وصل إثبات الدفع',
          body: 'جارٍ التحقق من الدفع — عادةً خلال دقائق، ثم يبدأ التجهيز.',
        ));
      case 'PAYMENT_REJECTED':
        widgets.add(alert(
          bg: const Color(0xFFFEF2F2),
          border: const Color(0xFFDC2626),
          fg: const Color(0xFF991B1B),
          title: '❌ تم رفض إثبات الدفع',
          body: order.payment?.rejectReason ??
              'راجع المتجر وأعد إرفاق إثبات صحيح.',
        ));
      case 'CANCELLED':
      case 'REFUNDED':
      case 'FAILED_DELIVERY':
        widgets.add(alert(
          bg: const Color(0xFFFEF2F2),
          border: const Color(0xFFDC2626),
          fg: const Color(0xFF991B1B),
          title: kOrderStatusLabels[order.status] ?? order.status,
          body: 'للاستفسار تواصل معنا عبر واتساب من أسفل الشاشة.',
        ));
    }

    // بطاقة OTP ذهبية كبيرة عند الخروج للتوصيل
    if (order.status == 'OUT_FOR_DELIVERY' &&
        order.delivery?.otp != null &&
        order.delivery!.status != 'DELIVERED') {
      widgets.add(Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppPalette.goldLight.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppPalette.gold, width: 2),
        ),
        child: Column(
          children: [
            const Text(
              '🔑 رمز التسليم — أعطه للمندوب عند الاستلام',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              order.delivery!.otp!,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 10,
                color: AppPalette.goldDark,
              ),
            ),
          ],
        ),
      ));
    }

    return widgets;
  }

  // ───────── شريط الخطوات ✅🟡⚪ ─────────

  Widget _trackBar(BuildContext context, Order order) {
    final status = order.status;
    final failed = _kFailedStatuses.contains(status);
    final flowIdx = kOrderFlow.indexOf(status);
    final preConfirm = !failed &&
        flowIdx >= 0 &&
        flowIdx < kOrderFlow.indexOf('CONFIRMED');

    String stateOf(String key) {
      if (failed) return 'pending';
      // قبل التأكيد: كل الخطوات 🟡 بانتظار الدفع/التحقق
      if (preConfirm) return 'current';
      final sIdx = kOrderFlow.indexOf(key);
      if (flowIdx >= sIdx) return flowIdx == sIdx ? 'current' : 'done';
      return 'pending';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                for (var i = 0; i < kCustomerTrackSteps.length; i++) ...[
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2.5,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: stateOf(kCustomerTrackSteps[i - 1].key) == 'done'
                            ? const Color(0xFF34D399)
                            : Colors.grey.shade300,
                      ),
                    ),
                  _buildTrackStep(
                    emoji: switch (stateOf(kCustomerTrackSteps[i].key)) {
                      'done' => '✅',
                      'current' => '🟡',
                      _ => '⚪',
                    },
                    label: kCustomerTrackSteps[i].value,
                    state: stateOf(kCustomerTrackSteps[i].key),
                  ),
                ],
              ],
            ),
            if (preConfirm)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '⏳ بانتظار الدفع/التحقق',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackStep({
    required String emoji,
    required String label,
    required String state,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 21)),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: switch (state) {
              'done' => AppPalette.green,
              'current' => const Color(0xFFB45309),
              _ => Colors.grey,
            },
          ),
        ),
      ],
    );
  }

  // ───────── إرفاق إثبات الدفع ─────────

  Widget _attachProofButton(
    BuildContext context,
    Order order,
    List<PaymentMethod> methods,
  ) {
    return OutlinedButton.icon(
      onPressed: methods.isEmpty
          ? null
          : () => _openAttachSheet(order, methods),
      icon: const Icon(Icons.photo_camera_outlined, size: 20),
      label: const Text('إرفاق إثبات الدفع'),
    );
  }

  void _openAttachSheet(Order order, List<PaymentMethod> methods) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _AttachProofSheet(
        orderCode: order.orderCode,
        phone: widget.phone,
        methods: methods.where((m) => !m.isCod).toList(),
        onDone: () => ref.invalidate(orderDetailsProvider(_arg)),
      ),
    );
  }

  // ───────── الأصناف والإجماليات ─────────

  Widget _itemsCard(BuildContext context, Order order) {
    final hintColor = Theme.of(context).hintColor;
    return TitledCard(
      title: '🌿 الأصناف',
      child: Column(
        children: [
          for (final it in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: NetImage(url: it.mainImage),
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
                                'قات ${it.productName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5),
                              ),
                            ),
                            GradeBadge(grade: it.grade),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${it.batchCode} • ${formatYER(it.unitPrice)} × ${formatNum(it.qty)}',
                          style: TextStyle(fontSize: 11, color: hintColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatYER(it.lineTotal),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 13.5),
                  ),
                ],
              ),
            ),
          const Divider(height: 4),
          const SizedBox(height: 10),
          _row('المجموع الفرعي', formatYER(order.itemsTotal)),
          _row(
            'التوصيل${order.zoneName != null ? ' — ${order.zoneName}' : ''}',
            formatYER(order.deliveryFee),
          ),
          if (order.discount > 0)
            _row('خصم', '- ${formatYER(order.discount)}',
                valueColor: AppPalette.green),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('الإجمالي',
                  style:
                      TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
              const Spacer(),
              Text(
                formatYER(order.total),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppPalette.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // ───────── بطاقة الدفع ─────────

  Widget _paymentCard(BuildContext context, Order order) {
    final payment = order.payment!;
    final hintColor = Theme.of(context).hintColor;
    return TitledCard(
      title: '💳 الدفع',
      trailing: PaymentStatusChip(status: payment.status),
      child: Column(
        children: [
          if (payment.methodName != null)
            _row('الطريقة', payment.methodName!),
          if (payment.transactionRef != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text('رقم العملية',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade700)),
                  ),
                  Text(
                    payment.transactionRef!,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          _row('المبلغ', formatYER(payment.amount),
              valueColor: AppPalette.green),
          if (payment.submittedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                'أُرسل ${timeAgoAr(payment.submittedAt)}',
                style: TextStyle(fontSize: 11, color: hintColor),
              ),
            ),
          if (payment.rejectReason != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'سبب الرفض: ${payment.rejectReason}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF991B1B),
                ),
              ),
            ),
          if (payment.proofUrl != null && payment.proofUrl!.isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _showProofFullscreen(payment.proofUrl!),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: hintColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: ProofImage(url: payment.proofUrl!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'عرض صورة الإثبات',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.green,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.zoom_in_rounded, size: 20),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showProofFullscreen(String url) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: _proofFullScreenImage(url)),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                tooltip: 'إغلاق',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 26),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _proofFullScreenImage(String url) {
    if (url.startsWith('data:')) {
      try {
        final b64 = url.contains(',') ? url.split(',')[1] : '';
        if (b64.isNotEmpty) {
          return Image.memory(
            base64Decode(b64),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image,
                size: 48, color: Colors.white),
          );
        }
      } catch (_) {}
    }
    return NetImage(url: url, fit: BoxFit.contain);
  }

  // ───────── العنوان ─────────

  Widget _addressCard(BuildContext context, Order order) {
    return TitledCard(
      title: '📍 التوصيل',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${order.zoneName != null ? '${order.zoneName} — ' : ''}${order.addressText}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          if (order.note != null && order.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'ملاحظة: ${order.note}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ───────── المندوب ─────────

  Widget _deliveryCard(BuildContext context, Order order) {
    final delivery = order.delivery!;
    return TitledCard(
      title: '🚚 المندوب',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          kDeliveryStatusLabels[delivery.status] ?? delivery.status,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
      ),
      child: Column(
        children: [
          if (delivery.driverName != null)
            _row('السائق', delivery.driverName!),
          if (delivery.otp != null && delivery.status != 'DELIVERED')
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text('🔑 رمز التسليم',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade700)),
                  ),
                  Text(
                    delivery.otp!,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: AppPalette.goldDark,
                    ),
                  ),
                ],
              ),
            ),
          if (delivery.deliveredAt != null)
            Text(
              '✅ تم التسليم ${timeAgoAr(delivery.deliveredAt)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppPalette.green,
              ),
            ),
        ],
      ),
    );
  }

  // ───────── التقييم ─────────

  Widget _reviewCard(BuildContext context, Order order) {
    return TitledCard(
      title: '🌿 قيّم تجربتك',
      child: Column(
        children: [
          Text(
            'شاركنا رأيك — ساعد باقي العملاء يشتروا بثقة 🌿',
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).hintColor,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _openReviewSheet(order),
              icon: const Icon(Icons.rate_review_outlined, size: 20),
              label: const Text('قيّم هذا الطلب'),
            ),
          ),
        ],
      ),
    );
  }

  void _openReviewSheet(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ReviewSheet(
        orderCode: order.orderCode,
        phone: widget.phone,
        onDone: () => ref.invalidate(orderDetailsProvider(_arg)),
      ),
    );
  }

  // ───────── سجل الطلب ─────────

  Widget _historyCard(BuildContext context, Order order) {
    final hintColor = Theme.of(context).hintColor;
    final entries = order.history.reversed.toList();
    return Card(
      child: Theme(
        data: Theme.of(context)
            .copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: const Text('سجل الطلب',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
          children: [
            for (final h in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppPalette.green.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${kOrderStatusLabels[h.toStatus] ?? h.toStatus}'
                            '${h.actor.isNotEmpty ? ' — ${h.actor}' : ''}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 12.5),
                          ),
                          Text(
                            '${timeAgoAr(h.createdAt)}'
                            '${h.note != null && h.note!.isNotEmpty ? ' • ${h.note}' : ''}',
                            style:
                                TextStyle(fontSize: 11, color: hintColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ───────── إعادة الطلب ─────────

  Future<void> _reorder(Order order) async {
    try {
      final catalog = await ref.read(catalogServiceProvider).fetchCatalog();
      final byId = {for (final b in catalog) b.id: b};
      final cartNotifier = ref.read(cartProvider.notifier);
      var addedBundles = 0;
      final ended = <String>{};
      for (final item in order.items) {
        final batch = byId[item.batchId];
        if (batch == null || !batch.isActive) {
          ended.add(item.productName);
          continue;
        }
        await cartNotifier.addFromBatch(batch, item.qty);
        addedBundles += item.qty;
      }
      if (!mounted) return;
      final parts = <String>[];
      if (addedBundles > 0) {
        parts.add('أُضيفت ${formatNum(addedBundles)} حزمة إلى السلة');
      }
      if (ended.isNotEmpty) {
        parts.add('دفعة ${ended.join('، ')} انتهت');
      }
      if (parts.isEmpty) {
        parts.add('لا توجد أصناف صالحة للإضافة');
      }
      showAppSnackBar(context, parts.join(' — '));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
    } on ApiException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'تعذر تحميل الكتالوج، حاول مرة أخرى',
            error: true);
      }
    }
  }
}

// ───────── نافذة إرفاق إثبات الدفع ─────────

class _AttachProofSheet extends ConsumerStatefulWidget {
  final String orderCode;
  final String phone;
  final List<PaymentMethod> methods;
  final VoidCallback onDone;

  const _AttachProofSheet({
    required this.orderCode,
    required this.phone,
    required this.methods,
    required this.onDone,
  });

  @override
  ConsumerState<_AttachProofSheet> createState() => _AttachProofSheetState();
}

class _AttachProofSheetState extends ConsumerState<_AttachProofSheet> {
  late String _methodId =
      widget.methods.isNotEmpty ? widget.methods.first.id : '';
  final _refCtrl = TextEditingController();
  String? _img;
  bool _sending = false;

  @override
  void dispose() {
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    if (_refCtrl.text.trim().isEmpty && _img == null) {
      showAppSnackBar(context, 'أرفق رقم العملية أو صورة الإثبات', error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(ordersServiceProvider).submitPayment(
            widget.orderCode,
            phone: widget.phone,
            methodId: _methodId,
            transactionRef: _refCtrl.text.trim(),
            proofDataUrl: _img,
          );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      widget.onDone();
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: Color(0xFF8BE9AF), size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('تم إرسال الإثبات ✅ — سيُتحقق منه خلال دقائق')),
            ],
          ),
          backgroundColor: Color(0xFF17361F),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAppSnackBar(context, e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAppSnackBar(context, 'حدث خطأ غير متوقع، حاول مرة أخرى', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إثبات الدفع',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          const Text('طريقة الدفع',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final m in widget.methods)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _methodId = m.id),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: m.id == _methodId
                        ? AppPalette.green
                        : Colors.grey.shade300,
                    width: m.id == _methodId ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      m.id == _methodId
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: m.id == _methodId
                          ? AppPalette.green
                          : Colors.grey.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(m.name,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                    if (m.accountNumber != null)
                      Text(
                        m.accountNumber!,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: Theme.of(context).hintColor),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _refCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: const InputDecoration(
              hintText: 'رقم العملية / الحوالة',
            ),
          ),
          const SizedBox(height: 12),
          ProofCaptureField(
            dataUrl: _img,
            onChanged: (url) => setState(() => _img = url),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed:
                    _sending ? null : () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _send,
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('إرسال الإثبات'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────── نافذة التقييم ─────────

class _ReviewSheet extends ConsumerStatefulWidget {
  final String orderCode;
  final String phone;
  final VoidCallback onDone;

  const _ReviewSheet({
    required this.orderCode,
    required this.phone,
    required this.onDone,
  });

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  String? _smiley;
  bool? _matched;
  final _commentCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _smiley == null || _matched == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(ordersServiceProvider).submitReview(
            orderCode: widget.orderCode,
            phone: widget.phone,
            rating: kSmileyRating[_smiley] ?? 4,
            smiley: _smiley!,
            matchedPhotos: _matched,
            comment: _commentCtrl.text.trim(),
          );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      widget.onDone();
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: Color(0xFF8BE9AF), size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('شكرًا لتقييمك 🌿 — رأيك يساعد باقي العملاء')),
            ],
          ),
          backgroundColor: Color(0xFF17361F),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAppSnackBar(context, e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAppSnackBar(context, 'حدث خطأ غير متوقع، حاول مرة أخرى', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌿 قيّم تجربتك',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final entry in kSmileys.entries)
                GestureDetector(
                  onTap: () => setState(() => _smiley = entry.key),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _smiley == entry.key
                            ? AppPalette.gold
                            : Colors.transparent,
                        width: 2.5,
                      ),
                      color: _smiley == entry.key
                          ? AppPalette.goldLight.withValues(alpha: 0.5)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                    ),
                    child: Center(
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('هل كان القات مطابقًا للصور؟',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _matched = true),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _matched == true
                            ? AppPalette.green
                            : Colors.grey.shade300,
                        width: _matched == true ? 1.8 : 1,
                      ),
                      color: _matched == true
                          ? AppPalette.greenLight.withValues(alpha: 0.6)
                          : null,
                    ),
                    child: const Text('✅ نعم مطابق',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13.5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _matched = false),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _matched == false
                            ? Theme.of(context).colorScheme.error
                            : Colors.grey.shade300,
                        width: _matched == false ? 1.8 : 1,
                      ),
                      color: _matched == false
                          ? const Color(0xFFFEF2F2)
                          : null,
                    ),
                    child: const Text('❌ لا',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13.5)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _commentCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'تعليق اختياري — جودة القات، سرعة التوصيل…',
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  _smiley == null || _matched == null ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Text('إرسال التقييم',
                      style: TextStyle(fontSize: 15.5)),
            ),
          ),
        ],
      ),
    );
  }
}
