// ============================================================
// GREEN GOLD | نماذج الإدارة — لوحة المعلومات والمخزون والتوصيل والتقارير
// ============================================================

import 'batch.dart';
import 'order.dart';

class PendingPayment {
  final String paymentId;
  final String orderCode;
  final String customerName;
  final String? phone;
  final num amount;
  final DateTime? submittedAt;
  final String? proofUrl;
  final String? transactionRef;
  final String? methodName;

  const PendingPayment({
    required this.paymentId,
    required this.orderCode,
    required this.customerName,
    this.phone,
    required this.amount,
    this.submittedAt,
    this.proofUrl,
    this.transactionRef,
    this.methodName,
  });

  factory PendingPayment.fromJson(Map<String, dynamic> j) => PendingPayment(
        paymentId: (j['paymentId'] ?? j['id'] ?? '').toString(),
        orderCode: j['orderCode']?.toString() ?? '',
        customerName: j['customerName']?.toString() ?? 'عميل',
        phone: _s(j['phone']),
        amount: _n(j['amount']) ?? 0,
        submittedAt: _d(j['submittedAt']),
        proofUrl: _s(j['proofUrl']) ?? _s(j['proofDataUrl']),
        transactionRef: _s(j['transactionRef']),
        methodName: _s(j['methodName']) ?? _s(j['method']),
      );
}

class DashboardData {
  final num todaySales;
  final int todayOrders;
  final int paidCount;
  final int pendingVerify;
  final int outForDelivery;
  final int activeBatches;
  final int lowStock;
  final int soldOut;
  final List<Order> recentOrders;
  final List<PendingPayment> pendingPayments;

  const DashboardData({
    required this.todaySales,
    required this.todayOrders,
    required this.paidCount,
    required this.pendingVerify,
    required this.outForDelivery,
    required this.activeBatches,
    required this.lowStock,
    required this.soldOut,
    required this.recentOrders,
    required this.pendingPayments,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    final today = (j['today'] ?? {}) as Map;
    final inventory = (j['inventory'] ?? {}) as Map;
    return DashboardData(
      todaySales: _n(today['sales']) ?? 0,
      todayOrders: _i(today['orders']),
      paidCount: _i(today['paidCount']),
      pendingVerify: _i(today['pendingVerify']),
      outForDelivery: _i(today['outForDelivery']),
      activeBatches: _i(inventory['activeBatches']),
      lowStock: _i(inventory['lowStock']),
      soldOut: _i(inventory['soldOut']),
      recentOrders: _list<Order>(j['recentOrders'], Order.fromJson),
      pendingPayments: _list<PendingPayment>(
          j['pendingPayments'], PendingPayment.fromJson),
    );
  }
}

class InventoryMovement {
  final String id;
  final String type; // ADD | RESERVE | RELEASE | SOLD | ADJUST | CANCEL
  final int qty;
  final String? batchCode;
  final String? productName;
  final String? note;
  final String? actor;
  final DateTime? createdAt;

  const InventoryMovement({
    required this.id,
    required this.type,
    required this.qty,
    this.batchCode,
    this.productName,
    this.note,
    this.actor,
    this.createdAt,
  });

  factory InventoryMovement.fromJson(Map<String, dynamic> j) {
    final batch = j['batch'];
    return InventoryMovement(
      id: j['id']?.toString() ?? '',
      type: j['type']?.toString() ?? '',
      qty: _i(j['qty']),
      batchCode: _s(j['batchCode']) ??
          (batch is Map ? _s(batch['batchCode']) : null),
      productName: _s(j['productName']) ??
          (batch is Map ? _s(batch['productName']) : null),
      note: _s(j['note']),
      actor: _s(j['actor']),
      createdAt: _d(j['createdAt']),
    );
  }
}

class DeliveryTask {
  final String id;
  final String status; // WAITING | ASSIGNED | PICKED_UP | OUT_FOR_DELIVERY | DELIVERED | FAILED
  final String? driverName;
  final String? otp;
  final DateTime? assignedAt;
  final DateTime? deliveredAt;
  final String? failReason;
  final String orderCode;
  final String? orderStatus;
  final String customerName;
  final String phone;
  final String? zoneName;
  final String addressText;
  final num total;
  final String? paymentStatus;
  final DateTime? createdAt;

  const DeliveryTask({
    required this.id,
    required this.status,
    this.driverName,
    this.otp,
    this.assignedAt,
    this.deliveredAt,
    this.failReason,
    required this.orderCode,
    this.orderStatus,
    required this.customerName,
    required this.phone,
    this.zoneName,
    required this.addressText,
    required this.total,
    this.paymentStatus,
    this.createdAt,
  });

  factory DeliveryTask.fromJson(Map<String, dynamic> j) {
    final order = j['order'];
    return DeliveryTask(
      id: j['id']?.toString() ?? '',
      status: j['status']?.toString() ?? 'WAITING',
      driverName: _s(j['driverName']),
      otp: _s(j['otp']),
      assignedAt: _d(j['assignedAt']),
      deliveredAt: _d(j['deliveredAt']),
      failReason: _s(j['failReason']),
      orderCode: (j['orderCode'] ??
              (order is Map ? order['orderCode'] : null) ??
              '')
          .toString(),
      orderStatus:
          _s(j['orderStatus']) ?? (order is Map ? _s(order['status']) : null),
      customerName: (j['customerName'] ??
              (order is Map ? order['customerName'] : null) ??
              'عميل')
          .toString(),
      phone: (j['phone'] ?? (order is Map ? order['phone'] : null) ?? '')
          .toString(),
      zoneName: _s(j['zoneName']) ?? (order is Map ? _s(order['zoneName']) : null),
      addressText: (j['addressText'] ??
              (order is Map ? order['addressText'] : null) ??
              '')
          .toString(),
      total: _n(j['total']) ??
          (order is Map ? _n(order['total']) : null) ??
          0,
      paymentStatus: _s(j['paymentStatus']) ??
          (order is Map ? _s(order['paymentStatus']) : null),
      createdAt: _d(j['createdAt']),
    );
  }
}

class CustomerRow {
  final String id;
  final String name;
  final String phone;
  final int ordersCount;
  final num totalSpent;
  final DateTime? lastOrderAt;

  const CustomerRow({
    required this.id,
    required this.name,
    required this.phone,
    required this.ordersCount,
    required this.totalSpent,
    this.lastOrderAt,
  });

  factory CustomerRow.fromJson(Map<String, dynamic> j) => CustomerRow(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? 'عميل',
        phone: j['phone']?.toString() ?? '',
        ordersCount: _i(j['ordersCount'] ?? j['orders']),
        totalSpent: _n(j['totalSpent']) ?? 0,
        lastOrderAt: _d(j['lastOrderAt']),
      );
}

class AuditRow {
  final String id;
  final String actorName;
  final String actorRole;
  final String action;
  final String entityType;
  final String entityId;
  final String? before;
  final String? after;
  final DateTime? createdAt;

  const AuditRow({
    required this.id,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.before,
    this.after,
    this.createdAt,
  });

  factory AuditRow.fromJson(Map<String, dynamic> j) => AuditRow(
        id: j['id']?.toString() ?? '',
        actorName: j['actorName']?.toString() ?? 'غير معروف',
        actorRole: j['actorRole']?.toString() ?? '',
        action: j['action']?.toString() ?? '',
        entityType: j['entityType']?.toString() ?? '',
        entityId: j['entityId']?.toString() ?? '',
        before: _s(j['before']),
        after: _s(j['after']),
        createdAt: _d(j['createdAt']),
      );
}

class SalesDay {
  final String date;
  final num total;
  final int orders;

  const SalesDay(
      {required this.date, required this.total, required this.orders});

  factory SalesDay.fromJson(Map<String, dynamic> j) => SalesDay(
        date: j['date']?.toString() ?? '',
        total: _n(j['total']) ?? 0,
        orders: _i(j['orders']),
      );
}

class TopBatch {
  final String batchCode;
  final String productName;
  final int soldQty;
  final num revenue;
  final num? avgRating;

  const TopBatch({
    required this.batchCode,
    required this.productName,
    required this.soldQty,
    required this.revenue,
    this.avgRating,
  });

  factory TopBatch.fromJson(Map<String, dynamic> j) => TopBatch(
        batchCode: j['batchCode']?.toString() ?? '',
        productName: j['productName']?.toString() ?? '',
        soldQty: _i(j['soldQty']),
        revenue: _n(j['revenue']) ?? 0,
        avgRating: _n(j['avgRating']),
      );
}

class GradeDistribution {
  final String grade;
  final int count;

  const GradeDistribution({required this.grade, required this.count});

  factory GradeDistribution.fromJson(Map<String, dynamic> j) =>
      GradeDistribution(
        grade: j['grade']?.toString() ?? '',
        count: _i(j['count']),
      );
}

class ReportsData {
  final List<SalesDay> salesByDay;
  final List<TopBatch> topBatches;
  final List<GradeDistribution> gradeDistribution;
  final int repeatCustomers;
  final int totalCustomers;
  final num? avgDeliveryMinutes;

  const ReportsData({
    required this.salesByDay,
    required this.topBatches,
    required this.gradeDistribution,
    required this.repeatCustomers,
    required this.totalCustomers,
    this.avgDeliveryMinutes,
  });

  factory ReportsData.fromJson(Map<String, dynamic> j) => ReportsData(
        salesByDay: _list<SalesDay>(j['salesByDay'], SalesDay.fromJson),
        topBatches: _list<TopBatch>(j['topBatches'], TopBatch.fromJson),
        gradeDistribution: _list<GradeDistribution>(
            j['gradeDistribution'], GradeDistribution.fromJson),
        repeatCustomers: _i(j['repeatCustomers']),
        totalCustomers: _i(j['totalCustomers']),
        avgDeliveryMinutes: _n(j['avgDeliveryMinutes']),
      );
}

class AdminNotification {
  final String id;
  final String title;
  final String body;
  final String? orderCode;
  final bool read;
  final DateTime? createdAt;

  const AdminNotification({
    required this.id,
    required this.title,
    required this.body,
    this.orderCode,
    required this.read,
    this.createdAt,
  });

  factory AdminNotification.fromJson(Map<String, dynamic> j) =>
      AdminNotification(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        orderCode: _s(j['orderCode']),
        read: j['read'] == true,
        createdAt: _d(j['createdAt']),
      );
}

/// دفعة كما تعيدها واجهة الإدارة (BatchCardDTO + حقول المخزون)
typedef AdminBatch = BatchCard;

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
