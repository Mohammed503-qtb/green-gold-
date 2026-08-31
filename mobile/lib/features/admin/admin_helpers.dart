// ============================================================
// GREEN GOLD | أدوات الإدارة المساعدة — guarded وعائلتها
// (المواصفة: guarded يُكتب في ملف admin_helpers.dart)
// يُعاد تصديره عبر admin_common.dart لكل شاشات الإدارة
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../state/staff.dart';
import '../../shared/widgets.dart';
import 'admin_login_screen.dart';

/// ينفّذ [action] ويلتقط أخطاء API برسالة عربية، ويعالج انتهاء الجلسة
/// (خروج + الانتقال لشاشة الدخول). يعيد null عند الفشل.
Future<T?> guarded<T>(
    WidgetRef ref, BuildContext context, Future<T> Function() action) async {
  try {
    return await action();
  } on ApiException catch (e) {
    if (e.isAuthExpiry) {
      _forceLogout(ref, context);
      return null;
    }
    if (context.mounted) {
      showAppSnackBar(context, e.message, error: true);
    }
    return null;
  } on StateError {
    // SERVER_NOT_CONFIGURED من apiClientProvider
    if (context.mounted) {
      showAppSnackBar(context, 'تعذر الاتصال بالخادم', error: true);
    }
    return null;
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, 'حدث خطأ غير متوقع، حاول مرة أخرى', error: true);
    }
    return null;
  }
}

/// نسخة منطقية من guarded للعمليات التي لا تعيد قيمة (true = نجحت).
Future<bool> guardedRun(
    WidgetRef ref, BuildContext context, Future<void> Function() action) async {
  const marker = '\u200b-ok';
  final r = await guarded<String>(
    ref,
    context,
    () async {
      await action();
      return marker;
    },
  );
  return identical(r, marker) || r == marker;
}

/// انتهاء الجلسة: خروج فوري + إعادة إلى شاشة الدخول
void _forceLogout(WidgetRef ref, BuildContext context) {
  ref.read(staffSessionProvider.notifier).logout();
  if (!context.mounted) return;
  showAppSnackBar(context, 'انتهت الجلسة، سجّل الدخول من جديد', error: true);
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
    (route) => false,
  );
}

/// معالجة خطأ API أثناء الجلب (بدون SnackBar) — يعيد رسالة العرض أو null
/// إن كان انتهاء جلسة وقد عولج (تم الانتقال لشاشة الدخول).
String? handleFetchError(WidgetRef ref, BuildContext context, Object e) {
  if (e is ApiException) {
    if (e.isAuthExpiry) {
      _forceLogout(ref, context);
      return null;
    }
    return e.message;
  }
  return 'تعذر الاتصال بالخادم، حاول مرة أخرى';
}
