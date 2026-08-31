// ============================================================
// GREEN GOLD | إتمام الطلب — 3 خطوات + شاشة نجاح ذهبية 🏆
// (1) بياناتك → (2) طريقة الدفع → (3) الإثبات ثم التأكيد
// ============================================================

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
import '../../state/session.dart';
import 'customer_helpers.dart';
import 'order_details_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  static const int _kStepData = 1;
  static const int _kStepPay = 2;
  static const int _kStepProof = 3;
  static const int _kStepSuccess = 4;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _refCtrl = TextEditingController();

  int _step = _kStepData;
  String? _methodId;
  String? _proofDataUrl;
  bool _submitting = false;
  bool _attachFailed = false;
  Order? _successOrder;

  String _nameError = '';
  String _phoneError = '';
  String _zoneError = '';
  String _addressError = '';
  String _proofError = '';

  @override
  void initState() {
    super.initState();
    final session = ref.read(customerSessionProvider);
    _nameCtrl.text = session.name;
    _phoneCtrl.text = session.phone;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _labelCtrl.dispose();
    _notesCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartProvider);
    final checkoutAsync = ref.watch(checkoutDataProvider);

    return PopScope(
      canPop: _step != _kStepSuccess,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == _kStepSuccess) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              _step == _kStepSuccess ? 'تم الطلب بنجاح' : 'إتمام الطلب'),
        ),
        body: _step == _kStepSuccess
            ? _buildSuccess()
            : checkoutAsync.when(
                loading: () => const Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  ),
                ),
                error: (e, _) => ErrorRetryView(
                  message:
                      'تعذر تحميل بيانات الشراء — تأكد من اتصال الخادم',
                  onRetry: () => ref.invalidate(checkoutDataProvider),
                ),
                data: (data) {
                  if (items.isEmpty) {
                    return const EmptyState(
                      emoji: '🛒',
                      title: 'سلتك فارغة',
                      subtitle: 'أضف دفعة من المتجر أولًا ثم عد لإتمام الطلب',
                    );
                  }
                  return _buildStepsArea(context, data);
                },
              ),
      ),
    );
  }

  // ───────── منطقة الخطوات ─────────

  Widget _buildStepsArea(BuildContext context, CheckoutData data) {
    return Column(
      children: [
        _buildStepsIndicator(),
        const Divider(height: 1),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _buildStepBody(context, data),
          ),
        ),
        // شريط التنقل الثابت — الزر الرئيسي مرئي دائمًا
        // مهما كان موضع التمرير أو لوحة المفاتيح
        _buildBottomNav(context, data),
      ],
    );
  }

  // ───────── شريط التنقل السفلي الثابت ─────────

  Widget _buildBottomNav(BuildContext context, CheckoutData data) {
    final methods = data.methods;
    final selectedId = _selectedMethodId(methods);

    late final List<Widget> buttons;
    switch (_step) {
      case _kStepPay:
        buttons = [
          OutlinedButton(
            onPressed: () => setState(() => _step = _kStepData),
            child: const Text('رجوع'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: selectedId.isEmpty
                  ? null
                  : () => setState(() => _step = _kStepProof),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('متابعة للإثبات',
                  style: TextStyle(fontSize: 15.5)),
            ),
          ),
        ];
      case _kStepProof:
        buttons = [
          OutlinedButton(
            onPressed: _submitting
                ? null
                : () => setState(() => _step = _kStepPay),
            child: const Text('رجوع'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.gold,
                foregroundColor: Colors.white,
              ),
              onPressed: _submitting ? null : _confirmOrder,
              icon: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(_submitting ? 'جارٍ الإرسال…' : 'تأكيد الطلب',
                  style: const TextStyle(fontSize: 15.5)),
            ),
          ),
        ];
      default: // _kStepData
        buttons = [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('رجوع'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: _goStep2,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('متابعة للدفع',
                  style: TextStyle(fontSize: 15.5)),
            ),
          ),
        ];
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: buttons),
      ),
    );
  }

  Widget _buildStepsIndicator() {
    const labels = ['بياناتك', 'الدفع', 'الإثبات'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2.5,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: _step > i + 1
                        ? AppPalette.green
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            _buildStepCircle(i + 1, labels[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildStepCircle(int number, String label) {
    final done = _step > number;
    final active = _step == number;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? AppPalette.green
                : active
                    ? AppPalette.greenLight
                    : Colors.transparent,
            border: Border.all(
              color: done || active ? AppPalette.green : Colors.grey.shade400,
              width: 2,
            ),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, size: 17, color: Colors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: active
                          ? AppPalette.greenDeep
                          : Colors.grey.shade500,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: done || active
                ? AppPalette.green
                : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildStepBody(BuildContext context, CheckoutData data) {
    switch (_step) {
      case _kStepData:
        return _buildStep1(context, data);
      case _kStepPay:
        return _buildStep2(context, data);
      default:
        return _buildStep3(context, data);
    }
  }

  // ───────── الخطوة 1: بياناتك ─────────

  Widget _buildStep1(BuildContext context, CheckoutData data) {
    final session = ref.watch(customerSessionProvider);
    final validZone = _findZone(data.zones, session.zoneId);

    return ListView(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(16),
      children: [
        _fieldLabel('الاسم الكامل *'),
        TextField(
          controller: _nameCtrl,
          textInputAction: TextInputAction.next,
          decoration: _decoration(
              hint: 'مثال: أحمد عبدالله', error: _nameError),
          onChanged: (_) => setState(() => _nameError = ''),
        ),
        if (_nameError.isNotEmpty) _errorText(_nameError),
        _fieldLabel('رقم الهاتف *'),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          decoration: _decoration(
              hint: '7XXXXXXXX', error: _phoneError),
          onChanged: (_) => setState(() => _phoneError = ''),
        ),
        if (_phoneError.isNotEmpty)
          _errorText(_phoneError)
        else
          _hintText('نستخدم رقمك لعرض طلباتك فقط'),
        _fieldLabel('منطقة التوصيل *'),
        _ZoneDropdownField(
          zones: data.zones,
          value: validZone?.id,
          error: _zoneError,
          onChanged: (v) {
            ref.read(customerSessionProvider.notifier).setZone(v);
            setState(() => _zoneError = '');
          },
        ),
        if (_zoneError.isNotEmpty) _errorText(_zoneError),
        _fieldLabel('وصف العنوان *'),
        TextField(
          controller: _addressCtrl,
          minLines: 2,
          maxLines: 3,
          decoration: _decoration(
            hint: 'مثال: كريتر، جولة المصلى، قرب مسجد النور، العمارة الثالثة',
            error: _addressError,
          ),
          onChanged: (_) => setState(() => _addressError = ''),
        ),
        if (_addressError.isNotEmpty) _errorText(_addressError),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('وسم المكان (اختياري)', small: true),
                  TextField(
                    controller: _labelCtrl,
                    decoration:
                        _decoration(hint: 'المنزل / العمل'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('ملاحظات (اختياري)', small: true),
                  TextField(
                    controller: _notesCtrl,
                    decoration:
                        _decoration(hint: 'وقت مناسب للتوصيل…'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _summaryCard(context, data),
        const SizedBox(height: 16),
      ],
    );
  }

  void _goStep2() {
    final phone = normalizePhone(_phoneCtrl.text);
    setState(() {
      _nameError = _nameCtrl.text.trim().length < 2
          ? 'اكتب اسمك الكامل (حرفان على الأقل)'
          : '';
      _phoneError = phone == null
          ? 'أدخل رقم هاتف يمني صحيح يبدأ بـ7 (9 أرقام)'
          : '';
      _zoneError = ref.read(customerSessionProvider).zoneId == null
          ? 'اختر منطقة التوصيل'
          : '';
      _addressError = _addressCtrl.text.trim().length < 5
          ? 'اكتب وصف العنوان بشكل أوضح (5 أحرف فأكثر)'
          : '';
    });
    if (_nameError.isNotEmpty ||
        _phoneError.isNotEmpty ||
        _zoneError.isNotEmpty ||
        _addressError.isNotEmpty) {
      return;
    }
    _phoneCtrl.text = phone!;
    final session = ref.read(customerSessionProvider.notifier);
    session.setName(_nameCtrl.text);
    session.setPhone(phone);
    setState(() => _step = _kStepPay);
  }

  // ───────── الخطوة 2: طريقة الدفع ─────────

  Widget _buildStep2(BuildContext context, CheckoutData data) {
    final methods = data.methods;
    final selectedId = _selectedMethodId(methods);

    return ListView(
      key: const ValueKey(2),
      padding: const EdgeInsets.all(16),
      children: [
        for (final m in methods)
          _PaymentMethodCard(
            method: m,
            selected: m.id == selectedId,
            onTap: () => setState(() => _methodId = m.id),
          ),
        if (methods.isEmpty)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'لا توجد طرق دفع متاحة حاليًا — جرّب لاحقًا 🌿',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).hintColor, fontSize: 13.5),
            ),
          ),
        const SizedBox(height: 14),
        _summaryCard(context, data),
        const SizedBox(height: 16),
      ],
    );
  }

  // ───────── الخطوة 3: الإثبات والتأكيد ─────────

  Widget _buildStep3(BuildContext context, CheckoutData data) {
    final methods = data.methods;
    final method = _findMethod(methods, _selectedMethodId(methods));
    final isCod = method?.isCod ?? false;

    return ListView(
      key: const ValueKey(3),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppPalette.greenLight.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppPalette.green.withValues(alpha: 0.3)),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'طريقة الدفع: '),
                TextSpan(
                  text: method?.name ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 12.5, height: 1.6),
          ),
        ),
        const SizedBox(height: 14),
        if (!isCod) ...[
          _fieldLabel('رقم العملية / الحوالة'),
          TextField(
            controller: _refCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: _decoration(hint: 'مثال: 8462091'),
            onChanged: (_) {
              if (_proofError.isNotEmpty) {
                setState(() => _proofError = '');
              }
            },
          ),
          const SizedBox(height: 14),
          const Text(
            'صورة الإثبات (تُضغط تلقائيًا 🌿)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ProofCaptureField(
            dataUrl: _proofDataUrl,
            onChanged: (url) => setState(() => _proofDataUrl = url),
          ),
          const SizedBox(height: 4),
          Text(
            'لقطة شاشة التحويل أو صورة الإيصال',
            style: TextStyle(
                fontSize: 11, color: Theme.of(context).hintColor),
          ),
          if (_proofError.isNotEmpty) _errorText(_proofError),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppPalette.goldLight.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppPalette.gold),
            ),
            child: Column(
              children: [
                const Text('💵 الدفع عند الاستلام',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 6),
                Text(
                  'ستدفع ${formatYER(_totalWithFee(data))} نقدًا عند الاستلام، لا حاجة لإثبات الآن.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, height: 1.6),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _summaryCard(context, data),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _confirmOrder() async {
    if (_submitting) return;
    final data = ref.read(checkoutDataProvider).valueOrNull;
    if (data == null) return;
    final methods = data.methods;
    final method = _findMethod(methods, _selectedMethodId(methods));
    if (method == null) return;
    final isCod = method.isCod;

    if (!isCod && _refCtrl.text.trim().isEmpty && _proofDataUrl == null) {
      setState(() =>
          _proofError = 'أرفق رقم العملية أو صورة الإثبات على الأقل');
      return;
    }

    final session = ref.read(customerSessionProvider);
    final phone = normalizePhone(_phoneCtrl.text)!;
    setState(() {
      _submitting = true;
      _proofError = '';
    });

    try {
      final items = ref.read(cartProvider);
      final order = await ref.read(ordersServiceProvider).createOrder(
            name: _nameCtrl.text.trim(),
            phone: phone,
            zoneId: session.zoneId!,
            addressText: _addressCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
            label: _labelCtrl.text.trim(),
            items: [
              for (final item in items) MapEntry(item.batchId, item.qty),
            ],
          );

      // إرفاق إثبات الدفع إن كانت الطريقة تتطلب ذلك
      // (فشل الإرفاق لا يلغي الطلب — يمكن إرفاقه من المتتبع)
      Order finalOrder = order;
      var attachFailed = false;
      if (!isCod &&
          (_refCtrl.text.trim().isNotEmpty || _proofDataUrl != null)) {
        try {
          finalOrder = await ref.read(ordersServiceProvider).submitPayment(
                order.orderCode,
                phone: phone,
                methodId: method.id,
                transactionRef: _refCtrl.text.trim(),
                proofDataUrl: _proofDataUrl,
              );
        } on ApiException {
          attachFailed = true;
        }
      }

      await ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      setState(() {
        _successOrder = finalOrder;
        _attachFailed = attachFailed;
        _submitting = false;
        _step = _kStepSuccess;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnackBar(context, e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnackBar(context, 'حدث خطأ غير متوقع، حاول مرة أخرى', error: true);
    }
  }

  // ───────── شاشة النجاح ─────────

  Widget _buildSuccess() {
    final order = _successOrder;
    final data = ref.read(checkoutDataProvider).valueOrNull;
    if (order == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final whatsapp = data?.whatsapp ?? '967771234567';
    final phone = normalizePhone(_phoneCtrl.text) ?? _phoneCtrl.text;

    String message;
    if (order.status == 'PAYMENT_SUBMITTED') {
      message = 'وصل إثبات الدفع — سيُتحقق منه خلال دقائق ثم يبدأ التجهيز.';
    } else if (order.status == 'PENDING_PAYMENT' && _attachFailed == false) {
      message = 'سنتواصل معك لتأكيد الطلب — يمكنك إرفاق الإثبات من شاشة التتبع.';
    } else if (_attachFailed) {
      message =
          'تم حفظ طلبك لكن تعذّر إرفاق الإثبات — أرفقه من شاشة «تتبع الطلب».';
    } else {
      message = 'سنتواصل معك عبر واتساب عند الحاجة.';
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppPalette.goldLight.withValues(alpha: 0.5),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.gold.withValues(alpha: 0.45),
                  blurRadius: 26,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.check_circle,
              size: 48,
              color: AppPalette.goldDark,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'تم استلام طلبك!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.7,
            color: Theme.of(context).hintColor,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppPalette.goldLight.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.gold.withValues(alpha: 0.6), width: 1.6),
          ),
          child: Column(
            children: [
              const Text(
                'رقم الطلب — احتفظ به',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    order.orderCode,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: AppPalette.goldDark,
                    ),
                  ),
                  IconButton(
                    tooltip: 'نسخ رقم الطلب',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: order.orderCode));
                      if (mounted) {
                        showAppSnackBar(context, 'تم النسخ ✅ ${order.orderCode}');
                      }
                    },
                    icon: const Icon(Icons.copy, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OrderStatusChip(status: order.status),
                  const SizedBox(width: 8),
                  Text(
                    'الإجمالي: ${formatYER(order.total)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
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
            label: const Text('تواصل واتساب',
                style: TextStyle(fontSize: 15.5)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrderDetailsScreen(
                      orderCode: order.orderCode,
                      phone: phone,
                    ),
                  ),
                ),
                icon: const Icon(Icons.track_changes, size: 18),
                label: const Text('تتبع طلبي'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextButton.icon(
                onPressed: () => Navigator.of(context)
                    .popUntil((route) => route.isFirst),
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('متابعة التسوق'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ───────── مساعدات ─────────

  String _selectedMethodId(List<PaymentMethod> methods) {
    if (_methodId != null && _findMethod(methods, _methodId) != null) {
      return _methodId!;
    }
    return methods.isNotEmpty ? methods.first.id : '';
  }

  PaymentMethod? _findMethod(List<PaymentMethod> methods, String? id) {
    if (id == null) return null;
    for (final m in methods) {
      if (m.id == id) return m;
    }
    return null;
  }

  Zone? _findZone(List<Zone> zones, String? id) {
    if (id == null) return null;
    for (final z in zones) {
      if (z.id == id) return z;
    }
    return null;
  }

  num _subtotal() => ref.read(cartSubtotalProvider);

  num _totalWithFee(CheckoutData data) {
    final session = ref.read(customerSessionProvider);
    final zone = _findZone(data.zones, session.zoneId);
    return _subtotal() + (zone?.fee ?? 0);
  }

  Widget _summaryCard(BuildContext context, CheckoutData data) {
    final session = ref.watch(customerSessionProvider);
    final items = ref.watch(cartProvider);
    final zone = _findZone(data.zones, session.zoneId);
    final subtotal = ref.watch(cartSubtotalProvider);
    final totalBundles =
        items.fold<int>(0, (a, e) => a + e.qty);
    final total = subtotal + (zone?.fee ?? 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _summaryRow('المجموع الفرعي (${formatNum(totalBundles)} حزمة)',
                formatYER(subtotal)),
            _summaryRow(
              'التوصيل${zone != null ? ' — ${zone.name}' : ''}',
              zone != null ? formatYER(zone.fee) : 'اختر المنطقة',
              muted: zone == null,
            ),
            const Divider(height: 16),
            Row(
              children: [
                const Text('الإجمالي',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const Spacer(),
                Text(
                  formatYER(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16.5,
                    color: AppPalette.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: muted ? Colors.grey : Colors.grey.shade700)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
              color: muted ? Colors.grey : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text, {bool small = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: small ? 12.5 : 13.5,
        ),
      ),
    );
  }

  InputDecoration _decoration({required String hint, String? error}) {
    final isEmptyError = error == null || error.isEmpty;
    return InputDecoration(
      hintText: hint,
      errorText: isEmptyError ? null : error,
    );
  }

  Widget _errorText(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFFC62828),
        ),
      ),
    );
  }

  Widget _hintText(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11, color: Theme.of(context).hintColor),
      ),
    );
  }
}

// ───────── بطاقة طريقة الدفع ─────────

class _PaymentMethodCard extends StatelessWidget {
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon {
    switch (method.type) {
      case 'BANK':
        return Icons.account_balance;
      case 'WALLET':
        return Icons.account_balance_wallet;
      default:
        return Icons.payments;
    }
  }

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      showAppSnackBar(context, 'تم النسخ ✅ $value');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hintColor = Theme.of(context).hintColor;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppPalette.green : Colors.transparent,
          width: 1.8,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppPalette.greenLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(_icon, color: AppPalette.greenDeep, size: 24),
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
                            method.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ),
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected
                              ? AppPalette.green
                              : Colors.grey.shade400,
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      kPaymentTypeLabels[method.type] ?? method.type,
                      style: TextStyle(fontSize: 11, color: hintColor),
                    ),
                    if (method.accountNumber != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (method.institution != null ||
                                      method.accountName != null)
                                    Text(
                                      [
                                        if (method.institution != null)
                                          method.institution!,
                                        if (method.accountName != null)
                                          method.accountName!,
                                      ].join(' — '),
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: hintColor),
                                    ),
                                  const SizedBox(height: 3),
                                  Text(
                                    method.accountNumber!,
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: IconButton(
                                tooltip: 'نسخ رقم الحساب',
                                padding: EdgeInsets.zero,
                                onPressed: () =>
                                    _copy(context, method.accountNumber!),
                                icon: const Icon(Icons.copy, size: 19),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (method.instructions != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        method.instructions!,
                        style: TextStyle(
                            fontSize: 11.5,
                            height: 1.6,
                            color: hintColor),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────── قائمة اختيار المنطقة (خطوة البيانات) ─────────

class _ZoneDropdownField extends StatelessWidget {
  final List<Zone> zones;
  final String? value;
  final String error;
  final ValueChanged<String> onChanged;

  const _ZoneDropdownField({
    required this.zones,
    required this.value,
    required this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              width: 1.2,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              hint: const Text('اختر المنطقة',
                  style: TextStyle(fontSize: 14)),
              items: [
                for (final z in zones)
                  DropdownMenuItem(
                    value: z.id,
                    child: Text(
                      '${z.name} — ${formatYER(z.fee)}',
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
