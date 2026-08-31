// ============================================================
// GREEN GOLD | خدمات العميل — الكتالوج والشراء والطلبات والتقييم
// مطابقة حرفيًا لعقد الـ API في نسخة الويب
// ------------------------------------------------------------
// كل قراءة: الشبكة أولًا → عند النجاح تُحدِّث الكاش،
// وعند فشل الشبكة تُرجع آخر نسخة محفوظة (وضع الشبكة الضعيفة)
// ============================================================

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/batch.dart';
import '../models/checkout.dart';
import '../models/order.dart';
import 'api_cache.dart';
import 'api_provider.dart';

class CatalogService {
  final ApiClient api;
  CatalogService(this.api);

  /// قراءة نسخة الكاش لفلتر معين (لعرضها فورًا قبل الشبكة)
  Future<List<BatchCard>?> cachedCatalog({
    String? grade,
    String? search,
    String? sort,
  }) async {
    final raw = await ApiCache.I
        .read(catalogCacheKey(grade: grade, search: search, sort: sort));
    if (raw == null) return null;
    try {
      return _batches(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// الكتالوج: الدفعات النشطة فقط — مع فلترة وبحث وفرز
  Future<List<BatchCard>> fetchCatalog({
    String? grade,
    String? search,
    String? sort,
  }) async {
    final query = <String, dynamic>{
      if (grade != null && grade.isNotEmpty) 'grade': grade,
      if (search != null && search.trim().isNotEmpty)
        'search': search.trim(),
      if (sort != null && sort.isNotEmpty) 'sort': sort,
    };
    final key =
        catalogCacheKey(grade: grade, search: search, sort: sort);
    try {
      final data = await api.get('/api/catalog',
          queryParameters: query.isEmpty ? null : query);
      await ApiCache.I.write(key, data);
      return _batches(data);
    } catch (e) {
      final cached =
          await cachedCatalog(grade: grade, search: search, sort: sort);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// تفاصيل دفعة (تشمل الوصف والمنشأ والتقييمات)
  Future<BatchDetail> fetchBatch(String id) async {
    final key = 'batch:${id.hashCode}';
    try {
      final data =
          await api.get('/api/batches/${Uri.encodeComponent(id)}');
      final detail = _parseBatchDetail(data);
      await ApiCache.I.write(key, data);
      return detail;
    } catch (e) {
      final raw = await ApiCache.I.read(key);
      if (raw != null) {
        try {
          return _parseBatchDetail(jsonDecode(raw));
        } catch (_) {}
      }
      rethrow;
    }
  }

  BatchDetail _parseBatchDetail(dynamic data) {
    final raw = data is Map<String, dynamic> ? data['batch'] : null;
    if (raw is! Map) throw ApiException('تعذر تحميل الدفعة', 500);
    final j = raw.cast<String, dynamic>();
    final card = BatchCard.fromJson(j);
    final reviewsRaw = j['reviews'];
    return BatchDetail(
      batch: card,
      productOrigin: j['productOrigin'] is String
          ? j['productOrigin'] as String?
          : null,
      reviews: reviewsRaw is List
          ? reviewsRaw
              .whereType<Map>()
              .map((e) => BatchReview.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }

  List<BatchCard> _batches(dynamic data) {
    if (data is Map<String, dynamic> && data['batches'] is List) {
      return (data['batches'] as List)
          .whereType<Map>()
          .map((e) => BatchCard.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }
}

class CheckoutService {
  final ApiClient api;
  CheckoutService(this.api);

  Future<CheckoutData> fetchCheckoutData() async {
    try {
      final data = await api.get('/api/checkout-data');
      if (data is Map<String, dynamic>) {
        await ApiCache.I.write('checkout-data', data);
        return CheckoutData.fromJson(data);
      }
      throw ApiException('تعذر تحميل بيانات الشراء', 500);
    } catch (e) {
      final raw = await ApiCache.I.read('checkout-data');
      if (raw != null) {
        try {
          final d = jsonDecode(raw);
          if (d is Map<String, dynamic>) {
            return CheckoutData.fromJson(d);
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<PublicSettings> fetchPublicSettings() async {
    try {
      final data = await api.get('/api/settings/public');
      if (data is Map<String, dynamic>) {
        await ApiCache.I.write('settings-public', data);
        return PublicSettings.fromJson(data);
      }
      throw ApiException('تعذر تحميل الإعدادات', 500);
    } catch (e) {
      final raw = await ApiCache.I.read('settings-public');
      if (raw != null) {
        try {
          final d = jsonDecode(raw);
          if (d is Map<String, dynamic>) {
            return PublicSettings.fromJson(d);
          }
        } catch (_) {}
      }
      rethrow;
    }
  }
}

class OrdersService {
  final ApiClient api;
  OrdersService(this.api);

  /// إنشاء طلب — الخادم يعيد حساب كل الأسعار (منع التلاعب)
  /// يفشل برسالة عربية عند نفاد الكمية (409)
  Future<Order> createOrder({
    required String name,
    required String phone,
    required String zoneId,
    required String addressText,
    String? notes,
    String? label,
    required List<MapEntry<String, int>> items,
  }) async {
    final data = await api.post('/api/orders', body: {
      'customer': {'name': name, 'phone': phone},
      'address': {
        'zoneId': zoneId,
        'addressText': addressText,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      },
      'items': items
          .map((e) => {'batchId': e.key, 'qty': e.value})
          .toList(),
    });
    final order = data is Map<String, dynamic> ? data['order'] : null;
    if (order is Map) return Order.fromJson(order.cast<String, dynamic>());
    throw ApiException('تعذر إنشاء الطلب', 500);
  }

  Future<List<Order>> fetchOrdersByPhone(String phone) async {
    final key = 'orders:${phone.hashCode}';
    try {
      final data = await api.get('/api/orders',
          queryParameters: {'phone': phone});
      if (data is Map<String, dynamic> && data['orders'] is List) {
        await ApiCache.I.write(key, data);
        return (data['orders'] as List)
            .whereType<Map>()
            .map((e) => Order.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      return [];
    } catch (e) {
      final raw = await ApiCache.I.read(key);
      if (raw != null) {
        try {
          final d = jsonDecode(raw);
          if (d is Map<String, dynamic> && d['orders'] is List) {
            return (d['orders'] as List)
                .whereType<Map>()
                .map((e) => Order.fromJson(e.cast<String, dynamic>()))
                .toList();
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<Order> fetchOrderByCode(String code, String phone) async {
    final key = 'order:${code.hashCode}';
    try {
      final data = await api.get(
          '/api/orders/${Uri.encodeComponent(code)}',
          queryParameters: {'phone': phone});
      final order = data is Map<String, dynamic> ? data['order'] : null;
      if (order is Map) {
        await ApiCache.I.write(key, data);
        return Order.fromJson(order.cast<String, dynamic>());
      }
      throw ApiException('تعذر تحميل الطلب', 500);
    } catch (e) {
      final raw = await ApiCache.I.read(key);
      if (raw != null) {
        try {
          final d = jsonDecode(raw);
          final order = d is Map<String, dynamic> ? d['order'] : null;
          if (order is Map) {
            return Order.fromJson(order.cast<String, dynamic>());
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// إرسال/إرفاق إثبات الدفع — العميل لا يستطيع أبدًا جعل الدفع PAID
  Future<Order> submitPayment(
    String code, {
    required String phone,
    required String methodId,
    String? transactionRef,
    String? proofDataUrl,
  }) async {
    final data = await api.post(
        '/api/orders/${Uri.encodeComponent(code)}/payment',
        body: {
          'phone': phone,
          'methodId': methodId,
          'transactionRef': transactionRef?.trim(),
          if (proofDataUrl != null && proofDataUrl.isNotEmpty)
            'proofDataUrl': proofDataUrl,
        });
    final order = data is Map<String, dynamic> ? data['order'] : null;
    if (order is Map) return Order.fromJson(order.cast<String, dynamic>());
    throw ApiException('تعذر إرسال إثبات الدفع', 500);
  }

  /// تقييم طلب مُسلَّم (فقط للطلبات DELIVERED غير المقيّمة)
  Future<void> submitReview({
    required String orderCode,
    required String phone,
    required int rating,
    required String smiley,
    bool? matchedPhotos,
    String? comment,
  }) async {
    await api.post('/api/reviews', body: {
      'orderCode': orderCode,
      'phone': phone,
      'rating': rating,
      'smiley': smiley,
      'matchedPhotos': ?matchedPhotos,
      'comment': ?comment?.trim(),
    });
  }
}

// ───────── مزوّدات Riverpod ─────────

final catalogServiceProvider = Provider<CatalogService>((ref) {
  return CatalogService(ref.watch(apiClientProvider));
});

final checkoutServiceProvider = Provider<CheckoutService>((ref) {
  return CheckoutService(ref.watch(apiClientProvider));
});

final ordersServiceProvider = Provider<OrdersService>((ref) {
  return OrdersService(ref.watch(apiClientProvider));
});
