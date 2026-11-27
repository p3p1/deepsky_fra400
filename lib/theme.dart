// Colori e tema dell'app: scuro, pensato per l'uso di notte.

import 'package:material_ui/material_ui.dart';

class AppColors {
  // Material 3 scuro su nero puro: sui display AMOLED i pixel neri sono
  // spenti (meno consumo, meno luce che disturba l'adattamento al buio).
  static const Color bg = Color(0xFF000000);
  static const Color surface = Color(0xFF121212); // superficie delle schede
  static const Color surfaceHigh = Color(0xFF1E1E1E); // riquadri, campi di testo
  static const Color surfaceHighest = Color(0xFF262626);
  static const Color ink = Color(0xFFE8E8E8);
  static const Color muted = Color(0xFFB4B4B4);
  static const Color outline = Color(0xFF8C8C8C);
  static const Color line = Color(0xFF2E2E2E);
  static const Color chip = Color(0xFF1F3B38); // secondaryContainer
  static const Color chipInk = Color(0xFFCCE8E4);
  static const Color accent = Color(0xFF80D5CF);
  static const Color accentInk = Color(0xFF003734);
  static const Color accentSoft = Color(0xFF9CF2EB);
  static const Color accentContainer = Color(0xFF00504C);
  static const Color amber = Color(0xFFFFB95C);
  static const Color ha = Color(0xFFFF8FA3);
  static const Color q5 = Color(0xFF7DDB8A);
  static const Color q4 = Color(0xFFC5D86D);
  static const Color q3 = Color(0xFFFFB95C);
  static const Color q2 = Color(0xFFFF9F80);
  static const Color q1 = Color(0xFF9E9E9E);
  static const Color q0 = Color(0xFF6E6E6E);
}

Color scoreColor(double v) {
  if (v >= 8) return AppColors.q5;
  if (v >= 6) return AppColors.q4;
  if (v >= 4) return AppColors.q3;
  if (v >= 2) return AppColors.q2;
  if (v > 0) return AppColors.q1;
  return AppColors.q0;
}

ThemeData buildTheme() {
  const ColorScheme scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.accentInk,
    primaryContainer: AppColors.accentContainer,
    onPrimaryContainer: AppColors.accentSoft,
    secondary: AppColors.accent,
    onSecondary: AppColors.accentInk,
    secondaryContainer: AppColors.chip,
    onSecondaryContainer: AppColors.chipInk,
    tertiary: AppColors.amber,
    surface: AppColors.bg,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerLowest: AppColors.bg,
    surfaceContainerLow: Color(0xFF0A0A0A),
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surfaceHigh,
    surfaceContainerHighest: AppColors.surfaceHighest,
    outline: AppColors.outline,
    outlineVariant: AppColors.line,
    error: AppColors.q2,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerColor: AppColors.line,
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
    // Schede "filled" di Material 3: niente bordo, solo una superficie più chiara del nero.
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.chip,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? AppColors.ink : AppColors.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> s) =>
          IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.chipInk : AppColors.muted)),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.chip,
      selectedIconTheme: IconThemeData(color: AppColors.chipInk),
      unselectedIconTheme: IconThemeData(color: AppColors.muted),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.accent,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.accent,
      dividerColor: AppColors.line,
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: AppColors.chip,
      side: BorderSide(color: AppColors.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accentContainer,
      foregroundColor: AppColors.accentSoft,
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.surfaceHigh, surfaceTintColor: Colors.transparent),
    snackBarTheme: const SnackBarThemeData(backgroundColor: AppColors.surfaceHighest, contentTextStyle: TextStyle(color: AppColors.ink)),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.muted),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.accent, width: 2), borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
  );
}

const TextStyle kMono = TextStyle(fontFamily: 'monospace', fontFeatures: <FontFeature>[FontFeature.tabularFigures()]);
