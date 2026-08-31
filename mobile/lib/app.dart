// ============================================================
// GREEN GOLD | توجيه البداية — إعداد الخادم أو الواجهة الرئيسية
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/customer/shell.dart';
import 'features/server_setup_screen.dart';
import 'state/config.dart';

class AppBootstrap extends ConsumerWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    if (!config.isConfigured) {
      return const ServerSetupScreen();
    }
    return const CustomerShell();
  }
}
