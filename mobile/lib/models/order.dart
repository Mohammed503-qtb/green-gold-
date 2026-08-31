// ============================================================
// GREEN GOLD | نماذج الطلب — OrderDTO الكامل مع الأصناف والدفع والتوصيل
// ============================================================

class OrderItem {
  final String id;
  final String batchId;
  final String productName;
  final String batchCode;
  final String grade;
  final num unitPrice;
  final int qty;
  final num lineTotal;
  final String? mainImage;

  const OrderItem({
    required this.id,
    required this.batchId,
    required this.productName,
    required this.batchCode,
    required this.grade,
    required this.unitPrice,
    required this.qty,
    required this.lineTotal,
    this.mainImage,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: j['id']?.toString() ?? '',
        batchId: j['batchId']?.toString() ?? '',
        productName: j['productName']?.toString() ?? 'قات',
        batchCode: j['batchCode']?.toString() ?? '',
        grade: j['grade']?.toString() ?? 'ECONOMIC',
        unitPrice: _n(j['unitPrice']) ?? 0,
        qty: _i(j['qty']),
        lineTotal: _n(j['lineTotal']) ?? 0,
        mainImage: _s(j['mainImage']),
      );
}

class PaymentInfo {
  final String id;
  final String status; // UNPAID | PENDING_VERIFICATION | PAID | REJECTED | REFUNDED
  final num amount;
  final String? methodName;
  final String? methodType;
  final String? transactionRef;
  final String? proofUrl;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;
  final String? rejectReason;

  const PaymentInfo({
    required this.id,
    required this.status,
    required this.amount,
    this.methodName,
    this.methodType,
    this.transactionRef,
    this.proofUrl,
    this.submittedAt,
    this.verifiedAt,
    this.rejectReason,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> j) {
    final methodSnapshot = j['methodSnapshot'];
    return PaymentInfo(
      id: j['id']?.toString() ?? '',
      status: j['status']?.toString() ?? 'UNPAID',
      amount: _n(j['amount']) ?? 0,
      methodName: methodSnapshot is Map<String, dynamic>
          ? methodSnapshot['name']?.toString()
          : null,
      methodType: methodSnapshot is Map<String, dynamic>
          ? methodSnapshot['type']?.toString()
          : null,
      transactionRef: _s(j['transactionRef']),
      proofUrl: _s(j['proofUrl']),
      submittedAt: _d(j['submittedAt']),
      verifiedAt: _d(j['verifiedAt']),
      rejectReason: _s(j['rejectReason']),
    );
  }
}

class DeliveryInfo {
  final String id;
  final String status; // WAITING | ASSIGNED | PICKED_UP | OUT_FOR_DELIVERY | DELIVERED | FAILED
  final String? driverName;
  final String? otp;
  final DateTime? assignedAt;
  final DateTime? deliveredAt;

  const DeliveryInfo({
    required this.id,
    required this.status,
    this.driverName,
    this.otp,
    this.assignedAt,
    this.deliveredAt,
  });

  factory DeliveryInfo.fromJson(Map<String, dynamic> j) => DeliveryInfo(
        id: j['id']?.toString() ?? '',
        status: j['status']?.toString() ?? 'WAITING',
        driverName: _s(j['driverName']),
        otp: _s(j['otp']),
        assignedAt: _d(j['assignedAt']),
        deliveredAt: _d(j['deliveredAt']),
      );
}

class OrderHistoryEntry {
  final String? fromStatus;
  final String toStatus;
  final String actor;
  final String? note;
  final DateTime? createdAt;

  const OrderHistoryEntry({
    this.fromStatus,
    required this.toStatus,
    required this.actor,
    this.note,
    this.createdAt,
  });

  factory OrderHistoryEntry.fromJson(Map<String, dynamic> j) =>
      OrderHistoryEntry(
        fromStatus: _s(j['fromStatus']),
        toStatus: j['toStatus']?.toString() ?? '',
        actor: j['actor']?.toString() ?? '',
        note: _s(j['note']),
        createdAt: _d(j['createdAt']),
      );
}

class Order {
  final String id;
  final String orderCode;
  final String status;
  final num itemsTotal;
  final num deliveryFee;
  final num discount;
  final num total;
  final String customerName;
  final String phone;
  final String addressText;
  final String? zoneName;
  final String? note;
  final DateTime? createdAt;
  final List<OrderItem> items;
  final PaymentInfo? payment;
  final DeliveryInfo? delivery;
  final List<OrderHistoryEntry> history;
  final bool reviewed;

  const Order({
    required this.id,
    required this.orderCode,
    required this.status,
    required this.itemsTotal,
    required this.deliveryFee,
    required this.discount,
    required this.total,
    required this.customerName,
    required this.phone,
    required this.addressText,
    this.zoneName,
    this.note,
    this.createdAt,
    this.items = const [],
    this.payment,
    this.delivery,
    this.history = const [],
    this.reviewed = false,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id']?.toString() ?? '',
        orderCode: j['orderCode']?.toString() ?? '',
        status: j['status']?.toString() ?? 'PENDING_PAYMENT',
        itemsTotal: _n(j['itemsTotal']) ?? 0,
        deliveryFee: _n(j['deliveryFee']) ?? 0,
        discount: _n(j['discount']) ?? 0,
        total: _n(j['total']) ?? 0,
        customerName: j['customerName']?.toString() ?? 'عميل',
        phone: j['phone']?.toString() ?? '',
        addressText: j['addressText']?.toString() ?? '',
        zoneName: _s(j['zoneName']),
        note: _s(j['note']),
        createdAt: _d(j['createdAt']),
        items: _list<OrderItem>(j['items'], OrderItem.fromJson),
        payment: j['payment'] is Map<String, dynamic>
            ? PaymentInfo.fromJson(j['payment'] as Map<String, dynamic>)
            : null,
        delivery: j['delivery'] is Map<String, dynamic>
            ? DeliveryInfo.fromJson(j['delivery'] as Map<String, dynamic>)
            : null,
        history: _list<OrderHistoryEntry>(j['history'], OrderHistoryEntry.fromJson),
        reviewed: j['reviewed'] == true,
      );

  // ─── الحزم لتطبيق الويب (payloads) ───

  Map<String, dynamic> toCreatePayload({
    required String name,
    required String phone,
    required String zoneId,
    required String addressText,
    String? notes,
    String? label,
  }) =>
      {
        'customer': {'name': name, 'phone': phone},
        'address': {
          'zoneId': zoneId,
          'addressText': addressText,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (label != null && label.isNotEmpty) 'label': label,
        },
      };
}

// ───────── أدوات تحليل دفاعية ─────────

String? _s(dynamic v) => v is String && v.isNotEmpty ? v : null;
num? _n(dynamic v) => v is num ? v : (v is String ? num.tryParse(v) : null);
int _i(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

DateTime? _d(dynamic v) {
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}

List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((e) => fromJson(e.cast<String, dynamic>()))
      .toList();
}
