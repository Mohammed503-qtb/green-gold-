// ============================================================
// GREEN GOLD | إدارة الطلبات — شرائح حالة + بحث + بطاقات الطلبات
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../services/admin_service.dart';
import '../../shared/widgets.dart';
import 'admin_common.dart';
import 'admin_order_details_screen.dart';

/// فلتر الحالة — null = الكل، 'STOPPED' = الملغي/المرفوض/المسترجع معًا
final _ordersStatusProvider = StateProvider<String?>((ref) => null);
final _ordersQueryProvider = StateProvider<String>((ref) => '');

final _ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  ref.watch(adminDataVersionProvider);
  final status = ref.watch(_ordersStatusProvider);
  final q = ref.watch(_ordersQueryProvider);
  final svc = ref.watch(adminServiceProvider);
  if (status == 'STOPPED') {
    final all = await svc.fetchOrders(q: q);
    return all
        .where((o) =>
            o.status == 'CANCELLED' ||
            o.status == 'PAYMENT_REJECTED' ||
            o.status == 'REFUNDED')
        .toList();
  }
  return svc.fetchOrders(status: status, q: q);
});

class _StatusFilter {
  final String? value;
  final String label;
  const _StatusFilter(this.value, this.label);
}

const List<_StatusFilter> _filters = [
  _StatusFilter(null, 'الكل'),
  _StatusFilter('PENDING_PAYMENT', 'بانتظار الدفع'),
  _StatusFilter('PAYMENT_SUBMITTED', 'إثبات الدفع'),
  _StatusFilter('CONFIRMED', 'مؤكد'),
  _StatusFilter('PREPARING', 'تجهيز'),
  _StatusFilter('READY_FOR_DELIVERY', 'جاهز'),
  _StatusFilter('OUT_FOR_DELIVERY', 'خرج للتوصيل'),
  _StatusFilter('DELIVERED', 'مسلّم'),
  _StatusFilter('STOPPED', 'متوقفة'),
];

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
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
      if (mounted) ref.read(_ordersQueryProvider.notifier).state = v.trim();
    });
  }

  Future<void> _refresh() =>
      swallowRefresh(ref.refresh(_ordersProvider.future));

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(_ordersStatusProvider);
    final orders = ref.watch(_ordersProvider);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionTitle(
                    title: 'الطلبات', icon: Icons.receipt_long_rounded),
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
          // البحث
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'بحث برقم الطلب أو الاسم أو الهاتف أو المرجع…',
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppPalette.green),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        _searchCtrl.clear();
                        ref.read(_ordersQueryProvider.notifier).state = '';
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // شرائح الحالة
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _filters[i];
                final selected = status == f.value;
                return ChoiceChip(
                  label: Text(f.label),
                  selected: selected,
                  onSelected: (_) => ref
                      .read(_ordersStatusProvider.notifier)
                      .state = f.value,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : const Color(0xFF1B241E),
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
          orders.when(
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
                  : 'تعذر تحميل الطلبات، تحقق من الاتصال',
              onRetry: _refresh,
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  emoji: '📋',
                  title: 'لا توجد طلبات مطابقة',
                  subtitle: 'جرّب تغيير الفلتر أو مصطلح البحث',
                );
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        '${formatNum(list.length)} طلب',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                  for (final o in list) _OrderTile(order: o),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final o = order;
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
              builder: (_) => AdminOrderDetailsScreen(orderId: o.id))),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        o.orderCode,
                        textDirection: TextDirection.ltr,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5),
                      ),
                    ),
                    Text(
                      formatYER(o.total),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.green),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OrderStatusChip(status: o.status),
                    const SizedBox(width: 6),
                    if (o.payment != null) PaymentStatusChip(status: o.payment!.status),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_rounded,
                        size: 15, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        o.customerName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.call_rounded,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      o.phone,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.inventory_2_outlined,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '${formatNum(o.items.length)} صنف',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const Spacer(),
                    Text(
                      timeAgoAr(o.createdAt),
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.grey.shade500),
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
