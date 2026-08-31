// ============================================================
// GREEN GOLD | كاش الـ API — الطبقة المحلية للعمل بشبكة ضعيفة
// ------------------------------------------------------------
// المشكلة: في اليمن الشبكة ضعيفة ومتقطعة، والتطبيق كان يعيد جلب
// كل البيانات من الخادم في كل مرة.
// الحل: كاش ثنائي (ذاكرة + SharedPreferences):
//   • الكتابة: عند كل نجاح شبكة (آخر نسخة صالحة).
//   • القراءة: فورية من الذاكرة أولًا ثم من القرص.
//   • الاستخدام: عرض الكاش لحظيًا ثم التحديث من الشبكة،
//     وعند انقطاع الشبكة يستمر العرض من الكاش.
// ملاحظة: الأسعار والكميات تُعاد دائمًا من الخادم عند الشراء —
// الكاش للعرض فقط ولا يؤثر على أي عملية دفع.
// ============================================================

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class _CacheEntry {
  final String json;
  final DateTime savedAt;
  const _CacheEntry(this.json, this.savedAt);
}

class ApiCache {
  ApiCache._();
  static final ApiCache I = ApiCache._();

  static const String _prefix = 'gg-cache:';
  final Map<String, _CacheEntry> _mem = {};

  /// قراءة آخر نسخة محفوظة (JSON نصي) — أو null
  Future<String?> read(String key) async {
    final m = _mem[key];
    if (m != null) return m.json;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return null;
      final entry = _decodeEnvelope(raw);
      if (entry == null) return null;
      _mem[key] = entry;
      return entry.json;
    } catch (_) {
      return null;
    }
  }

  /// وقت حفظ آخر نسخة ناجحة (لعرض «آخر تحديث» الصادق)
  Future<DateTime?> readTime(String key) async {
    final m = _mem[key];
    if (m != null) return m.savedAt;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return null;
      final entry = _decodeEnvelope(raw);
      if (entry == null) return null;
      _mem[key] = entry;
      return entry.savedAt;
    } catch (_) {
      return null;
    }
  }

  /// حفظ نسخة ناجحة (data هنا كائن Dart مفكوك من JSON)
  Future<void> write(String key, Object? data) async {
    try {
      final json = jsonEncode(data);
      final entry = _CacheEntry(json, DateTime.now());
      _mem[key] = entry;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefix$key',
        jsonEncode({'t': entry.savedAt.millisecondsSinceEpoch, 'd': json}),
      );
    } catch (_) {
      // فشل الحفظ لا يُفشل التطبيق أبدًا
    }
  }

  /// تفريغ الذاكرة فقط (عند تغيير الخادم — لا تصلح بيانات متجر آخر)
  void resetMemory() => _mem.clear();

  _CacheEntry? _decodeEnvelope(String raw) {
    try {
      final env = jsonDecode(raw);
      if (env is Map<String, dynamic> &&
          env['d'] is String &&
          env['t'] is num) {
        return _CacheEntry(
          env['d'] as String,
          DateTime.fromMillisecondsSinceEpoch(env['t'] as int),
        );
      }
    } catch (_) {}
    return null;
  }
}

/// مفتاح كاش الكتالوج حسب الفلتر (كل شريحة كاش مستقل)
String catalogCacheKey({String? grade, String? search, String? sort}) {
  return 'cat:'
      '${grade ?? '-'}|'
      '${(search ?? '').trim()}|'
      '${sort ?? '-'}';
}
