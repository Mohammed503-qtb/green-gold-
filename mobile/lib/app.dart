// ============================================================
// GREEN GOLD | توجيه البداية — الواجهة الرئيسية أو بوابة الاتصال
// ------------------------------------------------------------
// المستخدم العادي لا يرى أي شاشة إعداد تقنية:
// • إذا وُجد عنوان الخادم (مضمّن وقت البناء أو مضبوط) ← المتجر.
// • إن لم يوجد ← بوابة اتصال برسالة «تواصل مع إدارة المتجر»،
//   ومدخل الضبط فيها مخفي (5 نقرات على الشعار — للإدارة).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/connection_gate_screen.dart';
import 'features/customer/shell.dart';
import 'state/config.dart';

class AppBootstrap extends ConsumerWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    if (!config.isConfigured) {
      return const ConnectionGateScreen();
    }
    return const CustomerShell();
  }
}
