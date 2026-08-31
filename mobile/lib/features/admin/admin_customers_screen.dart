// ============================================================
// GREEN GOLD | العملاء — قائمة + بحث + ملف العميل وطلباته
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/admin.dart';
import '../../models/order.dart';
import '../../services/admin_service.dart';
import '../../shared/widgets.dart';
import 'admin_common.dart';
import 'admin_order_details_screen.dart';

final _customersQueryProvider = StateProvider<String>((ref) => '');

final _customersProvider =
    FutureProvider.autoDispose<List<CustomerRow>>((ref) async {
  ref.watch(adminDataVersionProvider);
  final q = ref.watch(_customersQueryProvider);
  return ref.watch(adminServiceProvider).fetchCustomers(q: q);
});

class AdminCustomersScreen extends ConsumerStatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  ConsumerState<AdminCustomersScreen> createState() =>
      _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends ConsumerState<AdminCustomersScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) ref.read(_customersQueryProvider.notifier).state = v.trim();
    });
  }

  Future<void> _refresh() =>
      swallowRefresh(ref.refresh(_customersProvider.future));

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(_customersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('العملاء'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: AppPalette.green),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو رقم الهاتف…',
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppPalette.green),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(_customersQueryProvider.notifier).state = '';
                        },
                      ),
              ),
            ),
            const SizedBox(height: 14),
            customers.when(
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
                    : 'تعذر تحميل العملاء، تحقق من الاتصال',
                onRetry: _refresh,
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    emoji: '👥',
                    title: 'لا يوجد عملاء مطابقون',
                    subtitle: 'يُنشأ ملف العميل تلقائيًا مع أول طلب',
                  );
                }
                return Column(
                  children: [
                    for (final c in list) _CustomerTile(customer: c),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final CustomerRow customer;
  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    final c = customer;
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
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _CustomerDetailScreen(customerId: c.id))),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppPalette.greenLight,
                  child: Text(
                    c.name.isNotEmpty ? c.name.characters.first : '؟',
                    style: const TextStyle(
                        color: AppPalette.greenDeep,
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${c.phone} • ${formatNum(c.ordersCount)} طلب',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatYER(c.totalSpent),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.green),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.lastOrderAt != null
                          ? 'آخر طلب ${timeAgoAr(c.lastOrderAt)}'
                          : 'لا طلبات',
                      style: TextStyle(
                          fontSize: 10.5, color: Colors.grey.shade500),
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
}

// ───────── ملف العميل ─────────

class _CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;
  const _CustomerDetailScreen({required this.customerId});

  @override
  ConsumerState<_CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<_CustomerDetailScreen> {
  CustomerRow? _customer;
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final d = await ref
          .read(adminServiceProvider)
          .fetchCustomerDetail(widget.customerId);
      if (!mounted) return;
      setState(() {
        _customer = d.customer;
        _orders = d.orders;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_customer?.name ?? 'ملف العميل'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => _load(silent: _customer != null),
            icon: const Icon(Icons.refresh_rounded, color: AppPalette.green),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorRetryView(message: _error!, onRetry: () => _load())
              : RefreshIndicator(
                  onRefresh: () => _load(silent: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      if (_customer != null) _customerCard(_customer!),
                      const SizedBox(height: 16),
                      const SectionTitle(
                          title: 'طلبات العميل',
                          icon: Icons.receipt_long_rounded),
                      const SizedBox(height: 10),
                      if (_orders.isEmpty)
                        const EmptyState(
                            emoji: '📋', title: 'لا توجد طلبات لهذا العميل')
                      else
                        for (final o in _orders) _orderTile(o),
                    ],
                  ),
                ),
    );
  }

  Widget _customerCard(CustomerRow c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppPalette.heroGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(
              c.name.isNotEmpty ? c.name.characters.first : '؟',
              style: const TextStyle(
                  color: AppPalette.green,
                  fontWeight: FontWeight.w800,
                  fontSize: 20),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            c.name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            c.phone,
            textDirection: TextDirection.ltr,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('الطلبات', formatNum(c.ordersCount)),
              _stat('إجمالي المشتريات', formatYER(c.totalSpent)),
              _stat('آخر طلب', timeAgoAr(c.lastOrderAt)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _orderTile(Order o) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAE4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AdminOrderDetailsScreen(orderId: o.id))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            o.orderCode,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 6),
                          Flexible(child: OrderStatusChip(status: o.status)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatNum(o.items.length)} صنف • ${timeAgoAr(o.createdAt)}',
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatYER(o.total),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.green),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
