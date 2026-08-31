// ============================================================
// GREEN GOLD | غلاف الإدارة — NavigationBar بخمس وجهات + المزيد
// AdminShell بلا معاملات (يُفتح بعد نجاح دخول الـ PIN)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../state/staff.dart';
import 'admin_audit_screen.dart';
import 'admin_batches_screen.dart';
import 'admin_common.dart';
import 'admin_customers_screen.dart';
import 'admin_delivery_screen.dart';
import 'admin_inventory_screen.dart';
import 'admin_login_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_reports_screen.dart';
import 'dashboard_screen.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: 'تسجيل الخروج؟',
      message: 'ستحتاج إلى إدخال رمز PIN للدخول مرة أخرى.',
      confirmLabel: 'خروج',
      danger: true,
    );
    if (!ok || !mounted) return;
    await ref.read(staffSessionProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffSessionProvider);
    final index = ref.watch(adminShellTabProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Column(
          children: [
            const Text(
              'ذهب أخضر — الإدارة',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
            ),
            if (staff != null)
              Text(
                '${staff.name} • ${staffRoleLabel(staff.role)}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: AppPalette.green),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: const [
          DashboardScreen(),
          AdminOrdersScreen(),
          AdminBatchesScreen(),
          AdminDeliveryScreen(),
          _AdminMoreScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(adminShellTabProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'لوحة',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'طلبات',
          ),
          NavigationDestination(
            icon: Icon(Icons.grass_outlined),
            selectedIcon: Icon(Icons.grass_rounded),
            label: 'دفعات',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping_rounded),
            label: 'توصيل',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_rounded),
            label: 'المزيد',
          ),
        ],
      ),
    );
  }
}

/// وجهة «المزيد»: المخزون / العملاء / التقارير / السجل / تسجيل الخروج
class _AdminMoreScreen extends ConsumerWidget {
  const _AdminMoreScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffSessionProvider);
    final role = staff?.role;
    final canReports = canRole(role, 'viewReports');
    final canAudit = canRole(role, 'viewAudit');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        SectionTitle(
          title: 'المزيد',
          icon: Icons.menu_rounded,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.greenLight,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              staff == null ? '' : '${staff.name} • ${staffRoleLabel(role)}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppPalette.greenDeep,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        MoreTile(
          icon: Icons.inventory_2_rounded,
          color: AppPalette.green,
          title: 'المخزون',
          subtitle: 'الكميات والحجز والبيع وحركات الدفعات',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AdminInventoryScreen())),
        ),
        MoreTile(
          icon: Icons.people_alt_rounded,
          color: AppPalette.gold,
          title: 'العملاء',
          subtitle: 'قائمة العملاء وسجل طلبات كل عميل',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AdminCustomersScreen())),
        ),
        if (canReports)
          MoreTile(
            icon: Icons.bar_chart_rounded,
            color: AppPalette.green,
            title: 'التقارير',
            subtitle: 'مبيعات 14 يومًا وأفضل الدفعات وتوزيع التصنيفات',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminReportsScreen())),
          ),
        if (canAudit)
          MoreTile(
            icon: Icons.shield_outlined,
            color: AppPalette.goldDark,
            title: 'السجل',
            subtitle: 'سجل التدقيق — من فعل ماذا ومتى',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminAuditScreen())),
          ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final shell =
                    context.findAncestorStateOfType<_AdminShellState>();
                await shell?._logout();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Color(0xFFB91C1C)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'تسجيل الخروج',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
