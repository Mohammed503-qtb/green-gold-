// ============================================================
// GREEN GOLD | خدمات الإدارة — كل مسارات /api/admin/**
// تتطلب جلسة موظف (x-staff-pin يُرفق تلقائيًا من ApiClient)
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/admin.dart';
import '../models/batch.dart';
import '../models/order.dart';
import 'api_provider.dart';

class AdminService {
  final ApiClient api;
  AdminService(this.api);

  // ───────── الدخول ─────────

  Future<({String name, String role})> login(String pin) async {
    final data = await api.post('/api/admin/login', body: {'pin': pin});
    if (data is Map<String, dynamic>) {
      final name = data['name'];
      final role = data['role'];
      if (name is String && name.isNotEmpty && role is String) {
        return (name: name, role: role);
      }
    }
    throw ApiException('استجابة دخول غير صالحة من الخادم', 500);
  }

  // ───────── لوحة المعلومات ─────────

  Future<DashboardData> fetchDashboard() async {
    final data = await api.get('/api/admin/dashboard');
    if (data is Map<String, dynamic>) return DashboardData.fromJson(data);
    throw ApiException('تعذر تحميل لوحة المعلومات', 500);
  }

  Future<List<AdminNotification>> fetchNotifications() async {
    final data = await api.get('/api/notifications',
        queryParameters: {'audience': 'ADMIN'});
    if (data is Map<String, dynamic> && data['notifications'] is List) {
      return (data['notifications'] as List)
          .whereType<Map>()
          .map((e) => AdminNotification.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  // ───────── الطلبات ─────────

  Future<List<Order>> fetchOrders({String? status, String? q}) async {
    final data = await api.get('/api/admin/orders', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    });
    if (data is Map<String, dynamic> && data['orders'] is List) {
      return (data['orders'] as List)
          .whereType<Map>()
          .map((e) => Order.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  Future<Order> fetchOrder(String id) async {
    final data = await api.get('/api/admin/orders/${Uri.encodeComponent(id)}');
    final order = data is Map<String, dynamic> ? data['order'] : null;
    if (order is Map) return Order.fromJson(order.cast<String, dynamic>());
    throw ApiException('تعذر تحميل الطلب', 500);
  }

  /// إجراء على الطلب: start_preparing | ready | out_for_delivery | cancel | refund
  /// out_for_delivery يعيد OTP في الاستجابة
  Future<({Order order, String? otp})> orderAction(String id, String action,
      {String? note}) async {
    final data = await api.post('/api/admin/orders/${Uri.encodeComponent(id)}/action',
        body: {
          'action': action,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        });
    final order = data is Map<String, dynamic> ? data['order'] : null;
    if (order is Map) {
      final otp =
          data is Map<String, dynamic> ? data['otp']?.toString() : null;
      return (
        order: Order.fromJson(order.cast<String, dynamic>()),
        otp: otp,
      );
    }
    throw ApiException('تعذر تنفيذ الإجراء', 500);
  }

  // ───────── التحقق من الدفعات ─────────

  Future<void> verifyPayment(String paymentId,
      {required bool approved, String? reason}) async {
    await api.post(
        '/api/admin/payments/${Uri.encodeComponent(paymentId)}/verify',
        body: {
          'approved': approved,
          if (!approved && reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        });
  }

  // ───────── الدفعات (البضاعة) ─────────

  Future<List<AdminBatch>> fetchBatches() async {
    final data = await api.get('/api/admin/batches');
    if (data is Map<String, dynamic> && data['batches'] is List) {
      return (data['batches'] as List)
          .whereType<Map>()
          .map((e) => BatchCard.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  /// إنشاء دفعة جديدة — ممنوع النشر بدون صورة أساسية (400 من الخادم)
  Future<void> createBatch({
    String? productId,
    String? productName,
    required String grade,
    required num price,
    required int totalQty,
    String? description,
    required List<Map<String, dynamic>> images,
    String? video,
    Map<String, int>? quality,
    DateTime? capturedAt,
  }) async {
    await api.post('/api/admin/batches', body: {
      if (productId != null && productId.isNotEmpty) 'productId': productId,
      'productName': productName?.trim(),
      'grade': grade,
      'price': price,
      'totalQty': totalQty,
      'description': description?.trim(),
      'images': images,
      'video': video?.trim(),
      if (quality != null)
        'quality': {
          'freshness': quality['freshness'] ?? 8,
          'density': quality['density'] ?? 8,
          'fullness': quality['fullness'] ?? 8,
          'appearance': quality['appearance'] ?? 8,
        },
      'capturedAt':
          (capturedAt ?? DateTime.now()).toUtc().toIso8601String(),
    });
  }

  /// تعديل دفعة: السعر / الحالة / إضافة كمية / الوصف
  /// ملاحظة: الوصف يُرسل فقط عندما يكون غير فارغ — الخادم يميّز null عن غياب المفتاح
  Future<void> patchBatch(String id,
      {num? price, String? status, int? addQty, String? description}) async {
    await api.patch('/api/admin/batches/${Uri.encodeComponent(id)}', body: {
      'price': ?price,
      'status': ?status,
      'addQty': ?addQty,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    });
  }

  // ───────── المخزون ─────────

  Future<({List<InventoryMovement> movements, List<AdminBatch> lowStock})>
      fetchInventory() async {
    final data = await api.get('/api/admin/inventory');
    if (data is! Map<String, dynamic>) {
      throw ApiException('تعذر تحميل المخزون', 500);
    }
    final movements = (data['movements'] is List)
        ? (data['movements'] as List)
            .whereType<Map>()
            .map((e) => InventoryMovement.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <InventoryMovement>[];
    final lowStock = (data['lowStock'] is List)
        ? (data['lowStock'] as List)
            .whereType<Map>()
            .map((e) => BatchCard.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <AdminBatch>[];
    return (movements: movements, lowStock: lowStock);
  }

  // ───────── العملاء ─────────

  Future<List<CustomerRow>> fetchCustomers({String? q}) async {
    final data = await api.get('/api/admin/customers',
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        });
    if (data is Map<String, dynamic> && data['customers'] is List) {
      return (data['customers'] as List)
          .whereType<Map>()
          .map((e) => CustomerRow.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  Future<({CustomerRow customer, List<Order> orders})> fetchCustomerDetail(
      String id) async {
    final data = await api.get('/api/admin/customers/${Uri.encodeComponent(id)}');
    if (data is Map<String, dynamic>) {
      final customerRaw = data['customer'];
      final ordersRaw = data['orders'];
      return (
        customer: customerRaw is Map
            ? CustomerRow.fromJson(customerRaw.cast<String, dynamic>())
            : CustomerRow(
                id: id, name: 'عميل', phone: '', ordersCount: 0, totalSpent: 0),
        orders: ordersRaw is List
            ? ordersRaw
                .whereType<Map>()
                .map((e) => Order.fromJson(e.cast<String, dynamic>()))
                .toList()
            : <Order>[],
      );
    }
    throw ApiException('تعذر تحميل بيانات العميل', 500);
  }

  // ───────── سجل التدقيق ─────────

  Future<List<AuditRow>> fetchAudit() async {
    final data = await api.get('/api/admin/audit');
    if (data is Map<String, dynamic> && data['logs'] is List) {
      return (data['logs'] as List)
          .whereType<Map>()
          .map((e) => AuditRow.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  // ───────── التقارير ─────────

  Future<ReportsData> fetchReports() async {
    final data = await api.get('/api/admin/reports');
    if (data is Map<String, dynamic>) return ReportsData.fromJson(data);
    throw ApiException('تعذر تحميل التقارير', 500);
  }

  // ───────── التوصيل ─────────

  Future<List<DeliveryTask>> fetchDeliveryTasks({String? status}) async {
    final data = await api.get('/api/admin/delivery', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
    });
    if (data is Map<String, dynamic> && data['deliveries'] is List) {
      return (data['deliveries'] as List)
          .whereType<Map>()
          .map((e) => DeliveryTask.fromJson(e.cast<String, dynamic>()))
          .where((t) => t.id.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// إجراء توصيل: assign | picked_up | out | delivered | failed
  Future<void> deliveryAction(String id, String action,
      {String? driverName, String? failReason, String? otp}) async {
    await api.post(
        '/api/admin/delivery/${Uri.encodeComponent(id)}/action',
        body: {
          'action': action,
          if (driverName != null && driverName.trim().isNotEmpty)
            'driverName': driverName.trim(),
          if (failReason != null && failReason.trim().isNotEmpty)
            'failReason': failReason.trim(),
          if (otp != null && otp.isNotEmpty) 'otp': otp,
        });
  }

  /// التحقق من OTP للتسليم
  Future<void> verifyOtp({required String deliveryOrderId, required String otp}) async {
    await api.post('/api/admin/delivery/verify-otp',
        body: {'deliveryOrderId': deliveryOrderId, 'otp': otp});
  }
}

// ───────── مزوّد Riverpod ─────────

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(ref.watch(apiClientProvider));
});
