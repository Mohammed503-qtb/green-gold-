// ============================================================
// GREEN GOLD | إعدادات التطبيق — عنوان خادم الـ API
// الأولوية: المحفوظ في الجهاز ← قيمة وقت البناء (dart-define)
// إن لم يوجد أي عنوان → شاشة إعداد الخادم
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// العنوان المضمّن وقت البناء: --dart-define=API_BASE_URL=https://...
const String kCompileTimeApiUrl = String.fromEnvironment('API_BASE_URL');

class AppConfig {
  /// عنوان يخص هذا الجهاز (يضبطه المستخدم من شاشة الإعداد)
  final String? storedBaseUrl;

  const AppConfig({this.storedBaseUrl});

  String get effectiveBaseUrl {
    final stored = storedBaseUrl?.trim() ?? '';
    if (stored.isNotEmpty) return stored;
    final compile = kCompileTimeApiUrl.trim();
    if (compile.isNotEmpty) return compile;
    return '';
  }

  bool get isConfigured => effectiveBaseUrl.isNotEmpty;
}

class AppConfigNotifier extends StateNotifier<AppConfig> {
  final SharedPreferences prefs;

  AppConfigNotifier(this.prefs)
      : super(AppConfig(storedBaseUrl: prefs.getString('gg-api-base-url')));

  /// ضبط عنوان الخادم لهذا الجهاز
  Future<void> setBaseUrl(String url) async {
    final clean = _normalize(url);
    await prefs.setString('gg-api-base-url', clean);
    state = AppConfig(storedBaseUrl: clean);
  }

  /// إلغاء العنوان المخصص (العودة لقيمة وقت البناء إن وُجدت)
  Future<void> clearBaseUrl() async {
    await prefs.remove('gg-api-base-url');
    state = const AppConfig();
  }

  static String _normalize(String url) {
    var u = url.trim();
    if (u.isEmpty) return '';
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    // إزالة الشرطة المائلة الأخيرة
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}

final appConfigProvider =
    StateNotifierProvider<AppConfigNotifier, AppConfig>((ref) {
  throw UnimplementedError('يُستبدل في main عبر overrides');
});
