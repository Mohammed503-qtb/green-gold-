// ============================================================
// GREEN GOLD | التقارير — بطاقات + رسم أعمدة مخصص + أفضل الدفعات
// (فقط لمن يملك صلاحية viewReports)
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

final _reportsProvider = FutureProvider.autoDispose<ReportsData>((ref) async {
  ref.watch(adminDataVersionProvider);
  return ref.watch(adminServiceProvider).fetchReports();
});

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) =>
      swallowRefresh(ref.refresh(_reportsProvider.future));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffSessionProvider);
    if (!canRole(staff?.role, 'viewReports')) {
      return Scaffold(
        appBar: AppBar(title: const Text('التقارير')),
        body: const EmptyState(
          emoji: '🔒',
          title: 'لا تملك صلاحية التقارير',
          subtitle: 'التقارير متاحة للمالك والمدير فقط',
        ),
      );
    }

    final reports = ref.watch(_reportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
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
        child: reports.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ErrorRetryView(
                message: e is ApiException
                    ? e.message
                    : 'تعذر تحميل التقارير، تحقق من الاتصال',
                onRetry: () => _refresh(ref),
              ),
            ],
          ),
          data: (d) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              // ── بطاقات الإحصاء ──
              Row(
                children: [
                  Expanded(
                    child: KpiCard(
                      icon: Icons.people_alt_outlined,
                      label: 'إجمالي العملاء',
                      value: formatNum(d.totalCustomers),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KpiCard(
                      icon: Icons.repeat_rounded,
                      label: 'عملاء متكررون',
                      value: formatNum(d.repeatCustomers),
                      tone: KpiTone.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KpiCard(
                      icon: Icons.timer_outlined,
                      label: 'متوسط زمن التوصيل',
                      value: d.avgDeliveryMinutes != null
                          ? '${formatNum(d.avgDeliveryMinutes!)} دقيقة'
                          : '—',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // ── مبيعات 14 يومًا ──
              const SectionTitle(
                  title: 'المبيعات — آخر 14 يومًا',
                  icon: Icons.trending_up_rounded),
              const SizedBox(height: 10),
              _SalesBarChart(days: d.salesByDay),
              const SizedBox(height: 20),
              // ── أفضل الدفعات ──
              const SectionTitle(
                  title: 'أفضل الدفعات مبيعًا',
                  icon: Icons.emoji_events_outlined),
              const SizedBox(height: 10),
              if (d.topBatches.isEmpty)
                _empty('لا توجد مبيعات مسجلة بعد')
              else
                for (var i = 0; i < d.topBatches.length; i++)
                  _TopBatchTile(item: d.topBatches[i], rank: i + 1),
              const SizedBox(height: 20),
              // ── توزيع التصنيفات ──
              const SectionTitle(
                  title: 'توزيع الدفعات حسب التصنيف',
                  icon: Icons.pie_chart_outline_rounded),
              const SizedBox(height: 10),
              if (d.gradeDistribution.isEmpty)
                _empty('لا توجد دفعات')
              else
                _gradeDistribution(context, d.gradeDistribution),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9F7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
      );

  Widget _gradeDistribution(BuildContext context, List<GradeDistribution> dist) {
    final maxCount = dist.fold<int>(0, (a, g) => a > g.count ? a : g.count);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAE4)),
      ),
      child: Column(
        children: [
          for (final g in dist)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${kGradeEmoji[g.grade] ?? ''} ${kGradeLabels[g.grade] ?? g.grade}',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF3EE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: maxCount > 0 ? g.count / maxCount : 0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppPalette.goldGradient,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    child: Text(
                      formatNum(g.count),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ───────── رسم أعمدة مخصص (بدون مكتبات) ─────────

class _SalesBarChart extends StatelessWidget {
  final List<SalesDay> days;
  const _SalesBarChart({required this.days});

  String _dayLabel(String date) {
    final parts = date.split('-');
    if (parts.length < 3) return date;
    final day = parts[2];
    final month = parts[1];
    return '$day/${month.replaceFirst('0', '')}';
  }

  @override
  Widget build(BuildContext context) {
    final max = days.fold<num>(1, (a, d) => d.total > a ? d.total : a);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAE4)),
      ),
      child: SizedBox(
        height: 170,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          textDirection: TextDirection.ltr,
          children: [
            for (final d in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (d.total > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            compactNum(d.total),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.greenDeep,
                            ),
                          ),
                        ),
                      Container(
                        width: double.infinity,
                        height: (d.total / max) * 108 + (d.total > 0 ? 4 : 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              d.total > 0
                                  ? AppPalette.green
                                  : const Color(0xFFE3EAE4),
                              d.total > 0
                                  ? AppPalette.greenDeep
                                  : const Color(0xFFEDF3EE),
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _dayLabel(d.date),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────── أفضل دفعة ─────────

class _TopBatchTile extends StatelessWidget {
  final TopBatch item;
  final int rank;
  const _TopBatchTile({required this.item, required this.rank});

  @override
  Widget build(BuildContext context) {
    final t = item;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAE4)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank == 1
                  ? AppPalette.gold
                  : rank == 2
                      ? const Color(0xFFC0C8C2)
                      : const Color(0xFFE3EAE4),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.productName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t.batchCode} • ${formatNum(t.soldQty)} حزمة',
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
                formatYER(t.revenue),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.green),
              ),
              if (t.avgRating != null)
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 13, color: AppPalette.gold),
                    Text(
                      t.avgRating!.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                )
              else
                Text(
                  'لا تقييم',
                  style: TextStyle(
                      fontSize: 10.5, color: Colors.grey.shade500),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
