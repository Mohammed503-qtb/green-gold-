// ============================================================
// GREEN GOLD | الثيم — أخضر قات + ذهبي، فاتح وداكن
// ممنوع الأزرق/البنفسجي كهوية
// ============================================================

import 'package:flutter/material.dart';

class AppPalette {
  // الأخضر الأساسي (قات)
  static const Color green = Color(0xFF157F3D);
  static const Color greenDark = Color(0xFF0B3D20);
  static const Color greenDeep = Color(0xFF0E5C2E);
  static const Color greenLight = Color(0xFFDCF5E4);

  // الذهبي
  static const Color gold = Color(0xFFC9A227);
  static const Color goldLight = Color(0xFFF6E7B4);
  static const Color goldDark = Color(0xFF8A6D14);

  // خلفيات
  static const Color bgLight = Color(0xFFF7F9F7);
  static const Color cardLight = Colors.white;
  static const Color bgDark = Color(0xFF0D1512);
  static const Color cardDark = Color(0xFF152019);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF0B3D20), Color(0xFF116335), Color(0xFF0A2E19)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFE3C558), Color(0xFFC9A227), Color(0xFFA8861B)],
  );
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppPalette.green,
    brightness: brightness,
  ).copyWith(
    primary: isDark ? const Color(0xFF4CAF7A) : AppPalette.green,
    onPrimary: Colors.white,
    secondary: AppPalette.gold,
    onSecondary: Colors.white,
    surface: isDark ? AppPalette.cardDark : AppPalette.cardLight,
    onSurface: isDark ? const Color(0xFFE7EFE9) : const Color(0xFF1B241E),
    surfaceContainerHighest:
        isDark ? const Color(0xFF1C2A21) : const Color(0xFFEDF3EE),
    error: isDark ? const Color(0xFFF87B7B) : const Color(0xFFC62828),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? AppPalette.bgDark : AppPalette.bgLight,
    fontFamily: 'Tajawal',
    splashFactory: InkRipple.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
      fontFamily: 'Tajawal',
    ),
    appBarTheme: AppBarTheme(
      backgroundColor:
          isDark ? AppPalette.bgDark : AppPalette.bgLight,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Tajawal',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF24332A) : const Color(0xFFE3EAE4),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.green,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: scheme.primary, width: 1.2),
        textStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF18251D) : Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A3A30) : const Color(0xFFD8E2DA),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A3A30) : const Color(0xFFD8E2DA),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppPalette.green, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF7B8C81) : const Color(0xFF9AA79E),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      modalBackgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? const Color(0xFF223429) : const Color(0xFF17361F),
      contentTextStyle: const TextStyle(
        fontFamily: 'Tajawal',
        color: Colors.white,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? const Color(0xFF24332A) : const Color(0xFFE3EAE4),
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? AppPalette.cardDark : Colors.white,
      indicatorColor: AppPalette.greenLight,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFCFE2D5) : const Color(0xFF1B241E),
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 26,
          color: states.contains(WidgetState.selected)
              ? AppPalette.green
              : (isDark ? const Color(0xFF7B8C81) : const Color(0xFF9AA79E)),
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppPalette.green,
    ),
  );
}
