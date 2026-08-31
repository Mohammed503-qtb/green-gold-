// ============================================================
// GREEN GOLD | طلباتي — إدخال الهاتف (محفوظ) + قائمة حية كل 15 ثانية
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../services/customer_services.dart';
import '../../shared/widgets.dart';
import '../../state/session.dart';
import 'order_details_screen.dart';

/// طلبات العميل حسب الهاتف — يُحدَّث تلقائيًا كل 15 ثانية (نبض المشترك)
final ordersByPhoneProvider =
    FutureProvider.autoDispose.family<List<Order>, String>((ref, phone) {
  ref.watch(autoRefreshTickerProvider);
  return ref.watch(ordersServiceProvider).fetchOrdersByPhone(phone);
});

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final TextEditingController _phoneCtrl = TextEditingController();
  bool _changeMode = false;
  String? _phoneError;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(customerSessionProvider);
    final showForm = _changeMode || !session.hasPhone;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Text('📦 طلباتي',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const Spacer(),
              if (!showForm && session.hasPhone)
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    tooltip: 'تحديث الطلبات',
                    onPressed: () => ref
                        .invalidate(ordersByPhoneProvider(session.phone)),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: showForm
              ? _buildPhoneForm(context)
              : _buildOrdersList(context, session.phone),
        ),
      ],
    );
  }

  // ───────── إدخال الهاتف ─────────

  Widget _buildPhoneForm(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppPalette.greenLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.phone_rounded,
                          color: AppPalette.greenDeep, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('اعرض طلباتك برقم هاتفك',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                          SizedBox(height: 2),
                          Text(
                            'يُحفظ الرقم على جهازك فقط — لا حاجة لكلمة مرور',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('رقم الهاتف',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  autofocus: _changeMode,
                  onSubmitted: (_) => _submitPhone(),
                  decoration: InputDecoration(
                    hintText: '7XXXXXXXX',
                    errorText: _phoneError,
                  ),
                  onChanged: (_) {
                    if (_phoneError != null) {
                      setState(() => _phoneError = null);
                    }
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _submitPhone,
                    child: const Text('عرض طلباتي',
                        style: TextStyle(fontSize: 15.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitPhone() async {
    final normalized = normalizePhone(_phoneCtrl.text);
    if (normalized == null) {
      setState(() =>
          _phoneError = 'أدخل رقمًا يمنيًا صحيحًا مثل 771234567');
      return;
    }
    setState(() => _phoneError = null);
    await ref.read(customerSessionProvider.notifier).setPhone(normalized);
    setState(() => _changeMode = false);
  }

  // ───────── قائمة الطلبات ─────────

  Widget _buildOrdersList(BuildContext context, String phone) {
    final ordersAsync = ref.watch(ordersByPhoneProvider(phone));

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.phone_rounded,
                  size: 16, color: AppPalette.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الطلبات المرتبطة بالرقم',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                phone,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () => setState(() {
                  _changeMode = true;
                  _phoneCtrl.text = phone;
                }),
                child: const Text('تغيير الرقم',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ordersAsync.when(
            loading: _buildSkeleton,
            error: (e, _) => ErrorRetryView(
              message: e.toString(),
              onRetry: () => ref.invalidate(ordersByPhoneProvider(phone)),
            ),
            data: (orders) {
              if (orders.isEmpty) {
                return const EmptyState(
                  emoji: '🧾',
                  title: 'لا توجد طلبات بعد',
                  subtitle: 'اطلب أول دفعة قات من المتجر وتابعها هنا من الدفع حتى التسليم',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) =>
                    _OrderCard(order: orders[i], phone: phone),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    final base = Colors.grey.shade300;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      children: List.generate(
        3,
        (_) => Container(
          height: 112,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ───────── بطاقة الطلب ─────────

class _OrderCard extends StatelessWidget {
  final Order order;
  final String phone;

  const _OrderCard({required this.order, required this.phone});

  @override
  Widget build(BuildContext context) {
    final hintColor = Theme.of(context).hintColor;
    final totalBundles = order.items.fold<int>(0, (a, e) => a + e.qty);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(
              orderCode: order.orderCode,
              phone: phone,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    order.orderCode,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  OrderStatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  PaymentStatusChip(
                      status: order.payment?.status ?? 'UNPAID'),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${timeAgoAr(order.createdAt)} • ${formatNum(totalBundles)} حزمة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: hintColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ...order.items.take(3).map(
                        (it) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child: NetImage(url: it.mainImage),
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.items
                          .map((it) => 'قات ${it.productName} ×${formatNum(it.qty)}')
                          .join('، '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: hintColor),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatYER(order.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: AppPalette.green,
                        ),
                      ),
                      const Icon(Icons.chevron_left,
                          size: 16, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
