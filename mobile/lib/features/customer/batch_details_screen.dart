// ============================================================
// GREEN GOLD | تفاصيل الدفعة — معرض صور + جودة + إضافة للسلة + تقييمات
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/batch.dart';
import '../../services/customer_services.dart';
import '../../shared/widgets.dart';
import '../../state/cart.dart';
import 'cart_screen.dart';
import 'customer_helpers.dart';

final batchDetailProvider =
    FutureProvider.autoDispose.family<BatchDetail, String>((ref, id) {
  return ref.watch(catalogServiceProvider).fetchBatch(id);
});

class BatchDetailsScreen extends ConsumerStatefulWidget {
  final String batchId;

  const BatchDetailsScreen({super.key, required this.batchId});

  @override
  ConsumerState<BatchDetailsScreen> createState() =>
      _BatchDetailsScreenState();
}

class _BatchDetailsScreenState extends ConsumerState<BatchDetailsScreen> {
  int _qty = 1;
  int _selectedImage = 0;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(batchDetailProvider(widget.batchId));

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الدفعة')),
      body: detailAsync.when(
        loading: () => _buildSkeleton(),
        error: (e, _) => ErrorRetryView(
          message: e is ApiException
              ? e.message
              : 'تعذر تحميل تفاصيل الدفعة، حاول مرة أخرى',
          onRetry: () =>
              ref.invalidate(batchDetailProvider(widget.batchId)),
        ),
        data: (detail) => _buildContent(context, detail),
      ),
    );
  }

  Widget _buildSkeleton() {
    final base = Colors.grey.shade300;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            decoration: BoxDecoration(
                color: base, borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 64,
          child: Row(
            children: List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                      color: base, borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
            height: 22, width: 160, color: base),
        const SizedBox(height: 10),
        Container(height: 14, width: 220, color: base),
        const SizedBox(height: 18),
        Container(
          height: 130,
          decoration: BoxDecoration(
              color: base, borderRadius: BorderRadius.circular(14)),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, BatchDetail detail) {
    final batch = detail.batch;
    final hintColor = Theme.of(context).hintColor;
    final images = batch.images.isNotEmpty
        ? batch.images
        : (batch.mainImage != null ? [batch.mainImage!] : <String>[]);
    final selIdx =
        images.isEmpty ? 0 : _selectedImage.clamp(0, images.length - 1);
    final available = batch.availableQty > 0;
    final maxQty = available ? batch.availableQty : 1;
    final qty = _qty.clamp(1, maxQty);
    final avgRating = batch.avgRating ?? detail.avgRating;
    final reviewsCount =
        batch.reviewsCount > 0 ? batch.reviewsCount : detail.reviews.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        // ─── المعرض ───
        GestureDetector(
          onTap: images.isEmpty ? null : () => _openGallery(images, selIdx),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: images.isEmpty
                  ? Container(
                      color: const Color(0xFFEDF3EE),
                      child: const Center(
                        child: Text('🌿', style: TextStyle(fontSize: 60)),
                      ),
                    )
                  : NetImage(url: images[selIdx]),
            ),
          ),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final selected = i == selIdx;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedImage = i),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppPalette.green
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: NetImage(url: images[i]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        if (batch.video != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: OutlinedButton.icon(
              onPressed: () =>
                  launchExternal(context, batch.video!),
              icon: const Icon(Icons.play_circle_outline, size: 20),
              label: const Text('مشاهدة فيديو الدفعة'),
            ),
          ),

        const SizedBox(height: 16),

        // ─── المعلومات ───
        Row(
          children: [
            GradeBadge(grade: batch.grade),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: hintColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                batch.batchCode,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: hintColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'قات ${batch.productName}',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '📸 ${capturedLabel(batch.capturedAt)}'
          '${detail.productOrigin != null ? '   •   📍 المصدر: ${detail.productOrigin}' : ''}',
          style: TextStyle(fontSize: 12.5, color: hintColor),
        ),
        if (batch.description != null &&
            batch.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            batch.description!,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.7,
              color: hintColor,
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ─── الجودة ───
        if (batch.quality != null)
          TitledCard(
            title: '📊 جودة الدفعة',
            child: Column(
              children: [
                _qualityRow('نضارة', batch.quality!.freshness),
                _qualityRow('كثافة', batch.quality!.density),
                _qualityRow('امتلاء', batch.quality!.fullness),
                _qualityRow('مظهر', batch.quality!.appearance),
              ],
            ),
          )
        else
          TitledCard(
            title: '📊 جودة الدفعة',
            child: Text(
              'لم تُسجَّل مقاييس جودة لهذه الدفعة.',
              style: TextStyle(fontSize: 12.5, color: hintColor),
            ),
          ),

        const SizedBox(height: 16),

        // ─── السعر + العدّاد + الإضافة ───
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatYER(batch.price),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppPalette.green,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('للحزمة الواحدة',
                          style: TextStyle(fontSize: 11, color: hintColor)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: !available
                            ? Colors.grey.shade200
                            : batch.isLowStock
                                ? const Color(0xFFFEF3C7)
                                : AppPalette.greenLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        !available
                            ? 'نفدت الكمية'
                            : batch.isLowStock
                                ? 'آخر ${formatNum(batch.availableQty)} حُزمة ⚡'
                                : 'متوفر ${formatNum(batch.availableQty)} حزمة',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: !available
                              ? Colors.grey.shade700
                              : batch.isLowStock
                                  ? const Color(0xFF92400E)
                                  : AppPalette.greenDeep,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    QtyStepper(
                      value: qty,
                      min: 1,
                      max: maxQty,
                      compact: 1.1,
                      onChanged: (v) => setState(() => _qty = v),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'الإجمالي: ${formatYER(batch.price * qty)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: available ? () => _addToCart(batch) : null,
                    icon: const Icon(Icons.shopping_basket_outlined, size: 20),
                    label: Text(
                      available
                          ? 'أضف للسلة — ${formatYER(batch.price * qty)}'
                          : 'نفدت الكمية',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ─── التقييمات ───
        TitledCard(
          title: '⭐ تقييمات الدفعة',
          trailing: reviewsCount > 0 && avgRating != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Color(0xFFB45309),
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Text('★★★★★',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFFF59E0B))),
                    const SizedBox(width: 4),
                    Text(
                      '(${formatNum(reviewsCount)} تقييم)',
                      style: TextStyle(fontSize: 11, color: hintColor),
                    ),
                  ],
                )
              : null,
          child: detail.reviews.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: hintColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    'لا تقييمات بعد — سيظهر تقييم العملاء هنا بعد الاستلام 🌿',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: hintColor),
                  ),
                )
              : Column(
                  children: [
                    for (final r in detail.reviews) _reviewItem(context, r),
                  ],
                ),
        ),
      ],
    );
  }

  // ─── مساعدات البناء ───

  Widget _qualityRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${formatNum(value)}/10',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: AppPalette.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value / 10).clamp(0.0, 1.0),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewItem(BuildContext context, BatchReview r) {
    final hintColor = Theme.of(context).hintColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hintColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kSmileys[r.smiley] ?? '🙂',
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.customerName ?? 'عميل',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      timeAgoAr(r.createdAt),
                      style: TextStyle(fontSize: 11, color: hintColor),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return Icon(
                    i < r.rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: i < r.rating
                        ? const Color(0xFFF59E0B)
                        : Colors.grey.shade400,
                  );
                }),
              ),
            ],
          ),
          if (r.comment != null && r.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              r.comment!,
              style: TextStyle(
                  fontSize: 12.5, height: 1.6, color: hintColor),
            ),
          ],
          if (r.matchedPhotos != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: r.matchedPhotos!
                    ? AppPalette.greenLight
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                r.matchedPhotos! ? '✅ مطابق للصور' : '📷 غير مطابق للصور',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: r.matchedPhotos!
                      ? AppPalette.greenDeep
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── الإجراءات ───

  Future<void> _addToCart(BatchCard batch) async {
    final qty = _qty.clamp(1, batch.availableQty > 0 ? batch.availableQty : 1);
    final notice =
        await ref.read(cartProvider.notifier).addFromBatch(batch, qty);
    if (!mounted) return;
    final message = notice ??
        'أُضيفت إلى السلة 🛒 — قات ${batch.productName} × ${formatNum(qty)}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              notice != null
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              color: notice != null
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFF8BE9AF),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
            notice != null ? const Color(0xFF7A4E00) : const Color(0xFF17361F),
        action: SnackBarAction(
          label: 'عرض السلة',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CartScreen()),
          ),
        ),
      ),
    );
  }

  void _openGallery(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.black.withValues(alpha: 0.92),
          child: Stack(
            children: [
              PageView.builder(
                itemCount: images.length,
                controller:
                    PageController(initialPage: initialIndex),
                itemBuilder: (_, i) => InteractiveViewer(
                  child: Center(
                    child: NetImage(url: images[i], fit: BoxFit.contain),
                  ),
                ),
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
        );
      },
    );
  }
}
