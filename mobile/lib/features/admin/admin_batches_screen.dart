// ============================================================
// GREEN GOLD | إدارة الدفعات — قائمة بكل الحالات + إجراءات + إنشاء
// ممنوع نشر دفعة بدون صورة واحدة على الأقل (يتطابق مع الخادم 400)
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

final _batchesProvider =
    FutureProvider.autoDispose<List<AdminBatch>>((ref) async {
  ref.watch(adminDataVersionProvider);
  return ref.watch(adminServiceProvider).fetchBatches();
});

const Map<String?, String> _batchFilters = {
  null: 'الكل',
  'ACTIVE': 'نشطة',
  'HIDDEN': 'مخفية',
  'CLOSED': 'مغلقة',
  'SOLD_OUT': 'نافدة',
};

class AdminBatchesScreen extends ConsumerStatefulWidget {
  const AdminBatchesScreen({super.key});

  @override
  ConsumerState<AdminBatchesScreen> createState() =>
      _AdminBatchesScreenState();
}

class _AdminBatchesScreenState extends ConsumerState<AdminBatchesScreen> {
  String? _statusFilter;
  String _query = '';

  Future<void> _refresh() =>
      swallowRefresh(ref.refresh(_batchesProvider.future));

  @override
  Widget build(BuildContext context) {
    final batches = ref.watch(_batchesProvider);
    final staff = ref.watch(staffSessionProvider);
    final canManage = canRole(staff?.role, 'manageBatches');

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openCreateSheet(context),
              backgroundColor: AppPalette.green,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'دفعة جديدة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Row(
              children: [
                const Expanded(
                  child: SectionTitle(
                      title: 'دفعات القات', icon: Icons.grass_rounded),
                ),
                IconButton(
                  tooltip: 'تحديث',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded,
                      color: AppPalette.green),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'بحث باسم النوع أو رقم الدفعة…',
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppPalette.green),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _batchFilters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final entry = _batchFilters.entries.elementAt(i);
                  final selected = _statusFilter == entry.key;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _statusFilter = entry.key),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color:
                          selected ? Colors.white : const Color(0xFF1B241E),
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
            batches.when(
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
                    : 'تعذر تحميل الدفعات، تحقق من الاتصال',
                onRetry: _refresh,
              ),
              data: (list) {
                var filtered = _statusFilter == null
                    ? list
                    : list.where((b) => b.status == _statusFilter).toList();
                if (_query.isNotEmpty) {
                  filtered = filtered
                      .where((b) =>
                          b.productName.contains(_query) ||
                          b.batchCode.toLowerCase().contains(
                              _query.toLowerCase()))
                      .toList();
                }
                if (filtered.isEmpty) {
                  return const EmptyState(
                    emoji: '🌿',
                    title: 'لا توجد دفعات مطابقة',
                    subtitle: 'أنشئ دفعة جديدة أو غيّر الفلتر',
                  );
                }
                return Column(
                  children: [
                    for (final b in filtered)
                      _BatchTile(
                        batch: b,
                        onTap: canManage ? () => _showActions(b) : null,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ───────── إجراءات الدفعة ─────────

  void _showActions(AdminBatch b) {
    final staff = ref.read(staffSessionProvider);
    final canChangePrice = canRole(staff?.role, 'changePrice');

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: NetImage(url: b.mainImage),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${b.productName} — ${b.batchCode}',
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatYER(b.price),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.green),
                        ),
                      ],
                    ),
                  ),
                  BatchStatusChip(status: b.status),
                ],
              ),
              const Divider(height: 24),
              _sheetAction(
                ctx: ctx,
                icon: b.status == 'HIDDEN'
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_outlined,
                label: b.status == 'HIDDEN' ? 'تنشيط الدفعة' : 'إخفاء الدفعة',
                subtitle: b.status == 'HIDDEN'
                    ? 'تظهر للعملاء في الكتالوج'
                    : 'تُخفى من الكتالوج دون إغلاقها',
                onTap: () => _toggleStatus(b),
              ),
              if (b.status != 'CLOSED' && b.status != 'SOLD_OUT')
                _sheetAction(
                  ctx: ctx,
                  icon: Icons.lock_outline_rounded,
                  label: 'إغلاق الدفعة',
                  subtitle: 'إيقاف البيع نهائيًا لهذه الدفعة',
                  onTap: () => _closeBatch(b),
                ),
              _sheetAction(
                ctx: ctx,
                icon: Icons.add_circle_outline_rounded,
                label: 'إضافة كمية',
                subtitle: 'زيادة totalQty (تعيد النشاط للدفعات النافدة)',
                onTap: () => _addQty(b),
              ),
              if (canChangePrice)
                _sheetAction(
                  ctx: ctx,
                  icon: Icons.sell_outlined,
                  label: 'تعديل السعر',
                  subtitle: 'السعر الحالي: ${formatYER(b.price)}',
                  onTap: () => _changePrice(b),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetAction({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(ctx).pop();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 22, color: AppPalette.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _patch(
    AdminBatch b, {
    String? status,
    num? price,
    int? addQty,
    required String successMsg,
  }) async {
    final done = await guardedRun(
      ref,
      context,
      () => ref
          .read(adminServiceProvider)
          .patchBatch(b.id, status: status, price: price, addQty: addQty),
    );
    if (done && mounted) {
      showAppSnackBar(context, successMsg);
      bumpAdminData(ref);
    }
  }

  Future<void> _toggleStatus(AdminBatch b) async {
    final newStatus = b.status == 'HIDDEN' ? 'ACTIVE' : 'HIDDEN';
    final ok = await confirmDialog(
      context,
      title: newStatus == 'HIDDEN' ? 'إخفاء الدفعة؟' : 'تنشيط الدفعة؟',
      message: newStatus == 'HIDDEN'
          ? 'ستُخفى دفعة ${b.productName} (${b.batchCode}) من كتالوج العملاء.'
          : 'ستظهر دفعة ${b.productName} (${b.batchCode}) للعملاء في الكتالوج.',
      confirmLabel: newStatus == 'HIDDEN' ? 'إخفاء' : 'تنشيط',
    );
    if (!ok) return;
    _patch(b,
        status: newStatus,
        successMsg:
            newStatus == 'HIDDEN' ? 'أُخفيت الدفعة ${b.batchCode}' : 'نُشِّطت الدفعة ${b.batchCode}');
  }

  Future<void> _closeBatch(AdminBatch b) async {
    final ok = await confirmDialog(
      context,
      title: 'إغلاق الدفعة؟',
      message:
          'سيتم إيقاف بيع دفعة ${b.productName} (${b.batchCode}) نهائيًا. المتاح حاليًا: ${formatNum(b.availableQty)} حزمة.',
      confirmLabel: 'إغلاق نهائي',
      danger: true,
    );
    if (!ok) return;
    _patch(b, status: 'CLOSED', successMsg: 'أُغلقت الدفعة ${b.batchCode}');
  }

  Future<void> _addQty(AdminBatch b) async {
    final v = await textDialog(
      context,
      title: 'إضافة كمية',
      label: 'الكمية المضافة (حزمة)',
      hint: 'مثال: 15',
      confirmLabel: 'إضافة',
      keyboard: TextInputType.number,
    );
    if (v == null) return;
    final qty = int.tryParse(v.trim());
    if (qty == null || qty <= 0) {
      if (mounted) showAppSnackBar(context, 'أدخل رقمًا صحيحًا أكبر من صفر', error: true);
      return;
    }
    _patch(b,
        addQty: qty,
        successMsg: 'أُضيفت ${formatNum(qty)} حزمة إلى ${b.batchCode}');
  }

  Future<void> _changePrice(AdminBatch b) async {
    final v = await textDialog(
      context,
      title: 'تعديل السعر',
      label: 'السعر الجديد (ريال/حزمة) — الحالي: ${formatYER(b.price)}',
      hint: 'مثال: 8500',
      confirmLabel: 'حفظ السعر',
      keyboard: TextInputType.number,
    );
    if (v == null) return;
    final price = num.tryParse(v.trim());
    if (price == null || price <= 0) {
      if (mounted) showAppSnackBar(context, 'أدخل سعرًا صحيحًا', error: true);
      return;
    }
    _patch(b,
        price: price,
        successMsg: 'حُدّث سعر ${b.batchCode} إلى ${formatYER(price)}');
  }

  // ───────── إنشاء دفعة ─────────

  void _openCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _CreateBatchSheet(),
    );
  }
}

// ───────── بطاقة دفعة ─────────

class _BatchTile extends StatelessWidget {
  final AdminBatch batch;
  final VoidCallback? onTap;
  const _BatchTile({required this.batch, this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = batch;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAE4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 62,
                        height: 62,
                        child: NetImage(url: b.mainImage),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.productName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            b.batchCode,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              GradeBadge(grade: b.grade),
                              const SizedBox(width: 6),
                              BatchStatusChip(status: b.status),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatYER(b.price),
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.green),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _qtyStat('إجمالي', b.totalQty ?? 0, Colors.grey),
                    _qtyStat('محجوز', b.reservedQty ?? 0, const Color(0xFF92400E)),
                    _qtyStat('مباع', b.soldQty ?? 0, AppPalette.greenDeep),
                    _qtyStat(
                      'متاح',
                      b.availableQty,
                      b.availableQty <= 0
                          ? const Color(0xFF991B1B)
                          : (b.availableQty <= kLowStockThreshold
                              ? const Color(0xFFB45309)
                              : AppPalette.green),
                    ),
                    const SizedBox(width: 6),
                    if (b.availableQty <= 0)
                      const MiniChip(
                        text: 'نافد',
                        bg: Color(0xFFFEE2E2),
                        fg: Color(0xFF991B1B),
                      )
                    else if (b.availableQty <= kLowStockThreshold)
                      const MiniChip(
                        text: 'منخفض',
                        bg: Color(0xFFFEF3C7),
                        fg: Color(0xFF92400E),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.star_rounded,
                        size: 14, color: AppPalette.gold),
                    const SizedBox(width: 2),
                    Text(
                      b.avgRating != null
                          ? '${b.avgRating!.toStringAsFixed(1)} (${formatNum(b.reviewsCount)})'
                          : 'لا تقييمات',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const Spacer(),
                    Icon(Icons.camera_alt_outlined,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 3),
                    Text(
                      capturedLabel(b.capturedAt),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _qtyStat(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            formatNum(value),
            style: TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w800, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// ───────── نموذج إنشاء دفعة ─────────

class _CreateBatchSheet extends ConsumerStatefulWidget {
  const _CreateBatchSheet();

  @override
  ConsumerState<_CreateBatchSheet> createState() => _CreateBatchSheetState();
}

class _CreateBatchSheetState extends ConsumerState<_CreateBatchSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _videoCtrl = TextEditingController();
  final List<TextEditingController> _imageCtrls = [TextEditingController()];
  int _mainIndex = 0;
  String _grade = 'EXCELLENT';
  double _freshness = 8;
  double _density = 8;
  double _fullness = 8;
  double _appearance = 8;
  DateTime _capturedAt = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _descCtrl.dispose();
    _videoCtrl.dispose();
    for (final c in _imageCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasImage =>
      _imageCtrls.any((c) => c.text.trim().isNotEmpty);

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty &&
      (num.tryParse(_priceCtrl.text.trim()) ?? 0) > 0 &&
      (int.tryParse(_qtyCtrl.text.trim()) ?? 0) > 0 &&
      _hasImage;

  Future<void> _pickCapturedAt() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _capturedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'وقت التصوير — التاريخ',
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_capturedAt),
      helpText: 'وقت التصوير — الساعة',
    );
    if (t == null) return;
    setState(() {
      _capturedAt = DateTime(
          d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);

    final urls =
        _imageCtrls.map((c) => c.text.trim()).where((u) => u.isNotEmpty).toList();
    // ضبط الرئيسية ضمن حدود القائمة الصالحة
    var main = _mainIndex;
    if (main >= urls.length) main = 0;
    final images = <Map<String, dynamic>>[
      for (var i = 0; i < urls.length; i++)
        {'url': urls[i], 'isMain': i == main},
    ];

    final done = await guardedRun(
      ref,
      context,
      () => ref.read(adminServiceProvider).createBatch(
            productName: _nameCtrl.text.trim(),
            grade: _grade,
            price: num.parse(_priceCtrl.text.trim()),
            totalQty: int.parse(_qtyCtrl.text.trim()),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            images: images,
            video:
                _videoCtrl.text.trim().isEmpty ? null : _videoCtrl.text.trim(),
            quality: {
              'freshness': _freshness.round(),
              'density': _density.round(),
              'fullness': _fullness.round(),
              'appearance': _appearance.round(),
            },
            capturedAt: _capturedAt,
          ),
    );
    if (!mounted) return;
    if (done) {
      Navigator.of(context).pop();
      showAppSnackBar(context, 'تم نشر الدفعة الجديدة 🌿');
      bumpAdminData(ref);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        builder: (ctx, scrollController) => Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              const SectionTitle(
                  title: 'نشر دفعة جديدة',
                  icon: Icons.add_photo_alternate_outlined),
              const SizedBox(height: 4),
              Text(
                'انشر دفعة جديدة بتصوير اليوم — النشر يتطلب صورة واحدة على الأقل.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              _label('المنتج (نوع القات) *'),
              TextFormField(
                controller: _nameCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'مثال: حراز فحمة — يُطابق أو ينشئ منتجًا',
                ),
              ),
              const SizedBox(height: 14),
              _label('التصنيف *'),
              Row(
                children: [
                  for (final g in const ['PREMIUM', 'EXCELLENT', 'ECONOMIC'])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: 6),
                        child: ChoiceChip(
                          label: Text(
                              '${kGradeEmoji[g]} ${kGradeLabels[g]}'),
                          selected: _grade == g,
                          onSelected: (_) => setState(() => _grade = g),
                          selectedColor: AppPalette.greenLight,
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _grade == g
                                ? AppPalette.greenDeep
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('السعر (ريال/حزمة) *'),
                        TextFormField(
                          controller: _priceCtrl,
                          onChanged: (_) => setState(() {}),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              hintText: 'مثال: 8500'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('الكمية (حزمة) *'),
                        TextFormField(
                          controller: _qtyCtrl,
                          onChanged: (_) => setState(() {}),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              hintText: 'مثال: 25'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _label('الوصف (اختياري)'),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'وصف قصير يظهر للعملاء: مصدر الدفعة، ملاحظات…',
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'روابط الصور *',
                      style:
                          TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    _hasImage ? 'صورة واحدة على الأقل ✓' : 'مطلوبة للنشر',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _hasImage ? AppPalette.green : const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _imageCtrls.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      // تحديد الرئيسية
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => setState(() => _mainIndex = i),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _mainIndex == i
                                  ? AppPalette.gold
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _mainIndex == i
                                ? Icons.circle
                                : Icons.circle_outlined,
                            size: 16,
                            color: _mainIndex == i
                                ? AppPalette.gold
                                : Colors.grey.shade400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _imageCtrls[i],
                          onChanged: (_) => setState(() {}),
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            hintText: 'https://… رابط الصورة ${i + 1}',
                            prefixIcon: _mainIndex == i
                                ? const Icon(Icons.star_rounded,
                                    size: 18, color: AppPalette.gold)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'حذف الصورة',
                        onPressed: _imageCtrls.length <= 1
                            ? null
                            : () {
                                setState(() {
                                  _imageCtrls[i].dispose();
                                  _imageCtrls.removeAt(i);
                                  if (_mainIndex >= _imageCtrls.length) {
                                    _mainIndex = _imageCtrls.length - 1;
                                  }
                                });
                              },
                        icon: Icon(Icons.delete_outline_rounded,
                            size: 21,
                            color: _imageCtrls.length <= 1
                                ? Colors.grey.shade300
                                : const Color(0xFFB91C1C)),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => setState(
                      () => _imageCtrls.add(TextEditingController())),
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 19),
                  label: const Text('إضافة صورة أخرى'),
                ),
              ),
              Text(
                'الدائرة الذهبية ⭐ تحدد الصورة الرئيسية — الأولى افتراضيًا.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 14),
              _label('رابط فيديو (اختياري)'),
              TextFormField(
                controller: _videoCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    hintText: 'https://youtube.com/… أو رابط mp4'),
              ),
              const SizedBox(height: 18),
              const Text(
                'مقاييس الجودة (1-10)',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              _qualitySlider('النضارة', _freshness, (v) => _freshness = v),
              _qualitySlider('الكثافة', _density, (v) => _density = v),
              _qualitySlider('الامتلاء', _fullness, (v) => _fullness = v),
              _qualitySlider('المظهر العام', _appearance, (v) => _appearance = v),
              const SizedBox(height: 10),
              // وقت التصوير
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickCapturedAt,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD8E2DA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.camera_alt_outlined,
                          size: 19, color: AppPalette.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'وقت التصوير: ${formatArabicDate(_capturedAt)}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Icon(Icons.edit_calendar_rounded,
                          size: 19, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              // رسالة منع الحفظ بلا صور
              if (!_hasImage)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '⚠️ لا يمكن النشر بدون صورة واحدة على الأقل — أضف رابط صورة الدفعة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: _canSave && !_saving ? _save : null,
                style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.greenDeep),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.publish_rounded, size: 19),
                label: Text(_saving ? 'جارٍ النشر…' : 'نشر الدفعة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
      );

  Widget _qualitySlider(String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: AppPalette.green,
            label: value.round().toString(),
            onChanged: (v) => setState(() => onChanged(v)),
          ),
        ),
        SizedBox(
          width: 26,
          child: Text(
            value.round().toString(),
            style: const TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
