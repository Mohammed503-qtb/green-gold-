// ============================================================
// GREEN GOLD | المخزون — منخفض/الكميات الأربع + سجل الحركات
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/admin.dart';
import '../../services/admin_service.dart';
import '../../shared/widgets.dart';
import 'admin_common.dart';

final _inventoryProvider = FutureProvider.autoDispose<
    ({List<InventoryMovement> movements, List<AdminBatch> lowStock})>(
    (ref) async {
  ref.watch(adminDataVersionProvider);
  return ref.watch(adminServiceProvider).fetchInventory();
});

final _allBatchesProvider =
    FutureProvider.autoDispose<List<AdminBatch>>((ref) async {
  ref.watch(adminDataVersionProvider);
  return ref.watch(adminServiceProvider).fetchBatches();
});

class AdminInventoryScreen extends ConsumerWidget {
  const AdminInventoryScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    try {
      await Future.wait([
        ref.refresh(_inventoryProvider.future),
        ref.refresh(_allBatchesProvider.future),
      ]);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = ref.watch(_inventoryProvider);
    final batches = ref.watch(_allBatchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المخزون والحركات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => _refresh(ref),
            icon: const Icon(Icons.refresh_rounded, color: AppPalette.green),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            // ── مخزون منخفض ──
            const SectionTitle(
                title: 'مخزون منخفض', icon: Icons.warning_amber_rounded),
            const SizedBox(height: 6),
            Text(
              'آخر $kLowStockThreshold حزم أو أقل — تحتاج كمية جديدة قريبًا',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            inv.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => const _InlineLoader(),
              error: (e, _) => ErrorRetryView(
                message: e is ApiException
                    ? e.message
                    : 'تعذر تحميل المخزون، تحقق من الاتصال',
                onRetry: () => _refresh(ref),
              ),
              data: (d) => d.lowStock.isEmpty
                  ? _infoBox('لا توجد دفعات منخفضة 👍',
                      'كل الدفعات النشطة لديها مخزون كافٍ')
                  : Column(
                      children: [
                        for (final b in d.lowStock) _LowStockTile(batch: b),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            // ── جدول الدفعات (بطاقات الكميات) ──
            const SectionTitle(
                title: 'كميات الدفعات', icon: Icons.inventory_2_rounded),
            const SizedBox(height: 6),
            Text(
              'المتاح = الإجمالي − المحجوز − المباع',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            batches.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => const _InlineLoader(),
              error: (e, _) => ErrorRetryView(
                message: 'تعذر تحميل الدفعات',
                onRetry: () => _refresh(ref),
              ),
              data: (list) => list.isEmpty
                  ? _infoBox('لا توجد دفعات في المخزون',
                      'أنشئ دفعة جديدة من تبويب الدفعات')
                  : Column(
                      children: [
                        for (final b in list) _QtyBatchTile(batch: b),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            // ── سجل الحركات ──
            const SectionTitle(
                title: 'سجل الحركات', icon: Icons.history_rounded),
            const SizedBox(height: 10),
            inv.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => const _InlineLoader(),
              error: (e, _) => const SizedBox.shrink(),
              data: (d) => d.movements.isEmpty
                  ? _infoBox('لا توجد حركات بعد',
                      'تظهر هنا كل إضافة وحجز وبيع وتحرير')
                  : Column(
                      children: [
                        for (final m in d.movements) _MovementTile(movement: m),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.greenLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// ───────── دفعة منخفضة ─────────

class _LowStockTile extends StatelessWidget {
  final AdminBatch batch;
  const _LowStockTile({required this.batch});

  @override
  Widget build(BuildContext context) {
    final b = batch;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFB45309), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${b.productName} — ${b.batchCode}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'متاح: ${formatNum(b.availableQty)} حزمة فقط',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E)),
                ),
              ],
            ),
          ),
          const MiniChip(
            text: 'منخفض',
            bg: Color(0xFFFEF3C7),
            fg: Color(0xFF92400E),
          ),
        ],
      ),
    );
  }
}

// ───────── بطاقة كميات دفعة ─────────

class _QtyBatchTile extends StatelessWidget {
  final AdminBatch batch;
  const _QtyBatchTile({required this.batch});

  @override
  Widget build(BuildContext context) {
    final b = batch;
    final soldOut = b.availableQty <= 0 || b.status == 'SOLD_OUT';
    final low = !soldOut && b.availableQty <= 5;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${b.productName} — ${b.batchCode}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
              if (soldOut)
                const MiniChip(
                    text: 'نافد', bg: Color(0xFFFEE2E2), fg: Color(0xFF991B1B))
              else if (low)
                const MiniChip(
                    text: 'منخفض', bg: Color(0xFFFEF3C7), fg: Color(0xFF92400E)),
              const SizedBox(width: 6),
              BatchStatusChip(status: b.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _qty('إجمالي', b.totalQty ?? 0, Colors.grey.shade700),
              _qty('محجوز', b.reservedQty ?? 0, const Color(0xFFB45309)),
              _qty('مباع', b.soldQty ?? 0, AppPalette.greenDeep),
              _qty('متاح', b.availableQty,
                  soldOut ? const Color(0xFF991B1B) : AppPalette.green,
                  strong: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qty(String label, int value, Color color, {bool strong = false}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9F7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                formatNum(value),
                style: TextStyle(
                  fontSize: strong ? 15 : 13.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                    fontSize: 10.5, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
}

// ───────── حركة مخزون ─────────

class _MovementTile extends StatelessWidget {
  final InventoryMovement movement;
  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final m = movement;
    final positive = m.type == 'ADD' || m.type == 'SOLD';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAE4)),
      ),
      child: Row(
        children: [
          MovementChip(type: m.type),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${m.productName ?? 'قات'} — ${m.batchCode ?? ''}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (m.actor != null && m.actor!.isNotEmpty) 'بواسطة ${m.actor}',
                    if (m.note != null && m.note!.isNotEmpty) m.note!,
                  ].join(' • '),
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${positive ? '+' : ''}${formatNum(m.qty)}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: positive
                      ? AppPalette.green
                      : (m.type == 'CANCEL'
                          ? const Color(0xFFB91C1C)
                          : Colors.grey.shade700),
                ),
              ),
              Text(
                timeAgoAr(m.createdAt),
                style:
                    TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineLoader extends StatelessWidget {
  const _InlineLoader();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
}
