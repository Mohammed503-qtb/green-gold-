// ============================================================
// GREEN GOLD | سجل التدقيق — من فعل ماذا ومتى + قبل ← بعد
// (فقط لمن يملك صلاحية viewAudit)
// ============================================================

import 'dart:convert';

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

final _auditProvider = FutureProvider.autoDispose<List<AuditRow>>((ref) async {
  ref.watch(adminDataVersionProvider);
  return ref.watch(adminServiceProvider).fetchAudit();
});

class AdminAuditScreen extends ConsumerWidget {
  const AdminAuditScreen({super.key});

  Future<void> _refresh(WidgetRef ref) =>
      swallowRefresh(ref.refresh(_auditProvider.future));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffSessionProvider);
    if (!canRole(staff?.role, 'viewAudit')) {
      return Scaffold(
        appBar: AppBar(title: const Text('سجل التدقيق')),
        body: const EmptyState(
          emoji: '🔒',
          title: 'لا تملك صلاحية السجل',
          subtitle: 'سجل التدقيق متاح للمالك والمدير فقط',
        ),
      );
    }

    final logs = ref.watch(_auditProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التدقيق'),
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
        child: logs.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ErrorRetryView(
                message: e is ApiException
                    ? e.message
                    : 'تعذر تحميل السجل، تحقق من الاتصال',
                onRetry: () => _refresh(ref),
              ),
            ],
          ),
          data: (list) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              const SectionTitle(
                  title: 'آخر العمليات الحساسة',
                  icon: Icons.shield_outlined),
              const SizedBox(height: 6),
              Text(
                'آخر ${formatNum(list.length)} عملية — من فعل ماذا ومتى ومع «قبل ← بعد».',
                style:
                    TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const EmptyState(
                  emoji: '🛡️',
                  title: 'لا توجد سجلات',
                  subtitle: 'تظهر هنا العمليات الحساسة فور حدوثها',
                )
              else
                for (final r in list) _AuditTile(row: r),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────── صف سجل ─────────

class _AuditTile extends StatelessWidget {
  final AuditRow row;
  const _AuditTile({required this.row});

  /// JSON مقروء إن أمكن
  String _pretty(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map || decoded is List) {
        return const JsonEncoder.withIndent('  ').convert(decoded);
      }
    } catch (_) {}
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final r = row;
    final roleLabel = kStaffRoleLabels[r.actorRole] ?? r.actorRole;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAE4)),
      ),
      child: Theme(
        // إزالة خطوط التقسيم الافتراضية للـ ExpansionTile
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${r.actorName} ($roleLabel)',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    timeAgoAr(r.createdAt),
                    style: TextStyle(
                        fontSize: 10.5, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  MiniChip(
                    text: r.action,
                    bg: const Color(0xFFEDF3EE),
                    fg: AppPalette.greenDeep,
                  ),
                  const SizedBox(width: 6),
                  MiniChip(
                    text: r.entityType,
                    bg: Colors.grey.shade100,
                    fg: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      shortId(r.entityId),
                      textDirection: TextDirection.ltr,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'قبل ← بعد',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _jsonBlock('قبل', r.before, const Color(0xFFB45309)),
                  const SizedBox(height: 6),
                  _jsonBlock('بعد', r.after, AppPalette.greenDeep),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _jsonBlock(String label, String? raw, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          _pretty(raw),
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.5,
            fontFamily: 'monospace',
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
