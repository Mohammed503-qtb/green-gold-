// ============================================================
// GREEN GOLD | سلة المشتريات — Riverpod + تخزين محلي دائم
// لقطات وقت الإضافة + التحقق من التوفر عند كل فتح
// ============================================================

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/batch.dart';

class CartItem {
  final String batchId;
  final int qty;
  final String name;
  final String grade;
  final num price;
  final String? image;
  final String batchCode;
  final int availableQty;
  final DateTime addedAt;

  const CartItem({
    required this.batchId,
    required this.qty,
    required this.name,
    required this.grade,
    required this.price,
    this.image,
    required this.batchCode,
    required this.availableQty,
    required this.addedAt,
  });

  CartItem copyWith({int? qty}) => CartItem(
        batchId: batchId,
        qty: qty ?? this.qty,
        name: name,
        grade: grade,
        price: price,
        image: image,
        batchCode: batchCode,
        availableQty: availableQty,
        addedAt: addedAt,
      );

  Map<String, dynamic> toJson() => {
        'batchId': batchId,
        'qty': qty,
        'name': name,
        'grade': grade,
        'price': price,
        'image': image,
        'batchCode': batchCode,
        'availableQty': availableQty,
        'addedAt': addedAt.toIso8601String(),
      };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        batchId: j['batchId']?.toString() ?? '',
        qty: j['qty'] is num ? (j['qty'] as num).toInt() : 1,
        name: j['name']?.toString() ?? 'قات',
        grade: j['grade']?.toString() ?? 'ECONOMIC',
        price: j['price'] is num ? j['price'] as num : 0,
        image: j['image']?.toString(),
        batchCode: j['batchCode']?.toString() ?? '',
        availableQty:
            j['availableQty'] is num ? (j['availableQty'] as num).toInt() : 0,
        addedAt: DateTime.tryParse(j['addedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  final SharedPreferences prefs;

  CartNotifier(this.prefs) : super(const []) {
    _load();
  }

  void _load() {
    try {
      final raw = prefs.getString('gg-cart');
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw);
      if (list is List) {
        state = list
            .whereType<Map>()
            .map((e) => CartItem.fromJson(e.cast<String, dynamic>()))
            .where((i) => i.batchId.isNotEmpty && i.qty > 0)
            .toList();
      }
    } catch (_) {
      // تخزين تالف — ابدأ بسلة فارغة
    }
  }

  Future<void> _persist() async {
    try {
      await prefs.setString(
          'gg-cart', jsonEncode(state.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  int count() => state.fold<int>(0, (a, e) => a + e.qty);

  num subtotal() => state.fold<num>(0, (a, e) => a + e.price * e.qty);

  /// إضافة دفعة للسلة (بحد المتاح) — يعيد رسالة تنبيه إن قُيّدت الكمية
  Future<String?> addFromBatch(BatchCard batch, int qty) async {
    final existing = state.where((i) => i.batchId == batch.id).toList();
    final currentQty =
        existing.isEmpty ? 0 : existing.fold<int>(0, (a, e) => a + e.qty);
    final maxAdd = batch.availableQty - currentQty;
    if (maxAdd <= 0) {
      return 'وصلت للحد الأقصى المتاح من هذه الدفعة (${batch.availableQty} حزمة)';
    }
    final addQty = qty > maxAdd ? maxAdd : qty;
    final notice = addQty < qty
        ? 'تم تحديد الكمية للحد المتاح ($maxAdd حزمة)'
        : null;

    if (existing.isNotEmpty) {
      state = state.map((i) {
        if (i.batchId == batch.id) {
          return i.copyWith(qty: i.qty + addQty);
        }
        return i;
      }).toList();
    } else {
      state = [
        ...state,
        CartItem(
          batchId: batch.id,
          qty: addQty,
          name: batch.productName,
          grade: batch.grade,
          price: batch.price,
          image: batch.mainImage,
          batchCode: batch.batchCode,
          availableQty: batch.availableQty,
          addedAt: DateTime.now(),
        ),
      ];
    }
    await _persist();
    return notice;
  }

  Future<void> setQty(String batchId, int qty) async {
    if (qty <= 0) {
      await remove(batchId);
      return;
    }
    state = state.map((i) {
      if (i.batchId == batchId) {
        final capped = qty > i.availableQty ? i.availableQty : qty;
        return i.copyWith(qty: capped);
      }
      return i;
    }).toList();
    await _persist();
  }

  Future<void> remove(String batchId) async {
    state = state.where((i) => i.batchId != batchId).toList();
    await _persist();
  }

  Future<void> clear() async {
    state = const [];
    await _persist();
  }

  /// التحقق من السلة مقابل الكتالوج الجديد (خطة §24):
  /// يزيل ما انتهت دفعته ويصحح الكميات والأسعار
  /// يعيد قائمة رسائل للمستخدم
  List<String> validateAgainstCatalog(List<BatchCard> batches) {
    final messages = <String>[];
    final byId = {for (final b in batches) b.id: b};
    final kept = <CartItem>[];
    for (final item in state) {
      final b = byId[item.batchId];
      if (b == null || !b.isActive) {
        messages
            .add('انتهت دفعة ${item.name} (${item.batchCode}) وأُزيلت من السلة');
        continue;
      }
      var qty = item.qty;
      if (qty > b.availableQty) {
        qty = b.availableQty;
        messages.add('تم تصحيح كمية ${item.name} إلى $qty (المتاح حاليًا)');
      }
      kept.add(CartItem(
        batchId: item.batchId,
        qty: qty,
        name: b.productName,
        grade: b.grade,
        price: b.price,
        image: b.mainImage,
        batchCode: b.batchCode,
        availableQty: b.availableQty,
        addedAt: item.addedAt,
      ));
    }
    final changed = kept.length != state.length ||
        state.asMap().entries.any((e) =>
            kept.length > e.key &&
            (kept[e.key].qty != e.value.qty ||
                kept[e.key].price != e.value.price ||
                kept[e.key].availableQty != e.value.availableQty));
    state = kept;
    if (changed) {
      _persist();
    }
    return messages;
  }
}

final cartProvider =
    StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  throw UnimplementedError('يُستبدل في main عبر overrides');
});

final cartCountProvider = Provider<int>((ref) {
  final items = ref.watch(cartProvider);
  return items.fold<int>(0, (a, e) => a + e.qty);
});

final cartSubtotalProvider = Provider<num>((ref) {
  final items = ref.watch(cartProvider);
  return items.fold<num>(0, (a, e) => a + e.price * e.qty);
});
