// ============================================================
// GREEN GOLD | سلة المشتريات — الأصناف + منطقة التوصيل + الإجماليات
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/checkout.dart';
import '../../shared/widgets.dart';
import '../../state/cart.dart';
import '../../state/session.dart';
import 'checkout_screen.dart';
import 'customer_helpers.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final session = ref.watch(customerSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          items.isEmpty
              ? 'سلة المشتريات'
              : 'سلة المشتريات (${formatNum(items.length)} صنف)',
        ),
      ),
      body: items.isEmpty
          ? const EmptyState(
              emoji: '🛒',
              title: 'سلتك فارغة',
              subtitle: 'تصفح دفعات قات اليوم وأضف ما يعجبك — الصور حقيقية والسعر واضح 🌿',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _CartItemTile(item: items[i]),
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : _SummaryPanel(zoneId: session.zoneId),
    );
  }
}

// ───────── صنف في السلة ─────────

class _CartItemTile extends ConsumerWidget {
  final CartItem item;

  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hintColor = Theme.of(context).hintColor;
    final dead = item.availableQty <= 0;

    return Card(
      child: Opacity(
        opacity: dead ? 0.6 : 1,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: NetImage(url: item.image),
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
                            'قات ${item.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            tooltip: 'حذف من السلة',
                            padding: EdgeInsets.zero,
                            onPressed: () => ref
                                .read(cartProvider.notifier)
                                .remove(item.batchId),
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 22,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        GradeBadge(grade: item.grade),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.batchCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10.5, color: hintColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        QtyStepper(
                          value: item.qty,
                          min: 1,
                          max: item.availableQty > 0 ? item.availableQty : 1,
                          compact: 0.95,
                          onChanged: (q) => ref
                              .read(cartProvider.notifier)
                              .setQty(item.batchId, q),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatYER(item.price * item.qty),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: AppPalette.green,
                              ),
                            ),
                            Text(
                              dead
                                  ? 'انتهت الدفعة'
                                  : 'المتاح ${formatNum(item.availableQty)} • ${formatYER(item.price)} / حزمة',
                              style:
                                  TextStyle(fontSize: 10, color: hintColor),
                            ),
                          ],
                        ),
                      ],
                    ),
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

// ───────── لوحة الملخص (المنطقة + الإجماليات + المتابعة) ─────────

class _SummaryPanel extends ConsumerWidget {
  final String? zoneId;

  const _SummaryPanel({required this.zoneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final checkoutAsync = ref.watch(checkoutDataProvider);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: checkoutAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ),
          error: (e, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'تعذر تحميل مناطق التوصيل — تحقق من الخادم',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              TextButton(
                onPressed: () => ref.invalidate(checkoutDataProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
          data: (data) {
            final zones = data.zones;
            final zone = _findZone(zones, zoneId);
            final total = subtotal + (zone?.fee ?? 0);
            final hasValidZone = zone != null;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🚚 التوصيل:',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ZoneDropdown(
                        zones: zones,
                        value: hasValidZone ? zone.id : null,
                        onChanged: (v) => ref
                            .read(customerSessionProvider.notifier)
                            .setZone(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _totalRow('المجموع', formatYER(subtotal)),
                _totalRow(
                  'التوصيل${zone != null ? ' — ${zone.name}' : ''}',
                  zone != null ? formatYER(zone.fee) : 'اختر المنطقة أعلاه',
                  muted: zone == null,
                ),
                const Divider(height: 18),
                Row(
                  children: [
                    const Text('الإجمالي',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                    const Spacer(),
                    Text(
                      formatYER(total),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: AppPalette.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 52,
                      height: 48,
                      child: IconButton(
                        tooltip: 'تفريغ السلة',
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.errorContainer,
                          foregroundColor:
                              Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        onPressed: () => _confirmClear(context, ref),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: items.isEmpty
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const CheckoutScreen()),
                                ),
                        child: const Text('متابعة الطلب',
                            style: TextStyle(fontSize: 15.5)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Zone? _findZone(List<Zone> zones, String? id) {
    if (id == null) return null;
    for (final z in zones) {
      if (z.id == id) return z;
    }
    return null;
  }

  Widget _totalRow(String label, String value, {bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تفريغ السلة؟'),
        content: const Text(
            'سيتم حذف جميع الأصناف من سلتك. يمكنك إضافتها مرة أخرى من المتجر.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('نعم، فرّغ السلة'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(cartProvider.notifier).clear();
    }
  }
}

// ───────── قائمة اختيار المنطقة ─────────

class _ZoneDropdown extends StatelessWidget {
  final List<Zone> zones;
  final String? value;
  final ValueChanged<String> onChanged;

  const _ZoneDropdown({
    required this.zones,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: const Text('اختر منطقة التوصيل',
              style: TextStyle(fontSize: 13)),
          borderRadius: BorderRadius.circular(12),
          items: [
            for (final z in zones)
              DropdownMenuItem(
                value: z.id,
                child: Text(
                  '${z.name} — ${formatYER(z.fee)}',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
