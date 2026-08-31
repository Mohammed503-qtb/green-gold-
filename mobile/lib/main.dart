// ============================================================
// GREEN GOLD | نقطة الدخول
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/theme.dart';
import 'state/cart.dart';
import 'state/config.dart';
import 'state/session.dart';
import 'state/staff.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // بيانات رموز التواريخ العربية (أسماء الشهور)
  await initializeDateFormatting('ar');

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWith((ref) => AppConfigNotifier(prefs)),
        cartProvider.overrideWith((ref) => CartNotifier(prefs)),
        customerSessionProvider
            .overrideWith((ref) => CustomerSessionNotifier(prefs)),
        staffSessionProvider.overrideWith((ref) => StaffSessionNotifier(prefs)),
      ],
      child: const GreenGoldApp(),
    ),
  );
}

class GreenGoldApp extends ConsumerWidget {
  const GreenGoldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'ذهب أخضر',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.light, // هوية العلامة فاتحة دائمًا
      home: const AppBootstrap(),
    );
  }
}
