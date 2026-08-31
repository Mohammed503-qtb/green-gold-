// ============================================================
// GREEN GOLD | مزوّد عميل الـ API — يعاد بناؤه تلقائيًا عند
// تغيير عنوان الخادم أو جلسة الموظف
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../state/config.dart';
import '../state/staff.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final staff = ref.watch(staffSessionProvider);
  final url = config.effectiveBaseUrl;
  if (url.isEmpty) {
    // عنوان فارغ = لم يُضبط الخادم بعد — العمليات ستفشل برسالة عربية
    throw StateError('SERVER_NOT_CONFIGURED');
  }
  return ApiClient(baseUrl: url, staffPin: staff?.pin);
});
