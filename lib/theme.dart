// Colori e tema dell'app: scuro, pensato per l'uso di notte.

import 'package:material_ui/material_ui.dart';

class AppColors {
  static const Color bg = Color(0xFF0C0F1E);
  static const Color surface = Color(0xFF141930);
  static const Color ink = Color(0xFFE7E9F4);
  static const Color muted = Color(0xFF9AA1C0);
  static const Color line = Color(0xFF29304F);
  static const Color chip = Color(0xFF1D2442);
  static const Color accent = Color(0xFF41C9C2);
  static const Color accentInk = Color(0xFF06201F);
  static const Color accentSoft = Color(0xFF7FE0DA);
  static const Color amber = Color(0xFFE8B04A);
  static const Color ha = Color(0xFFF0708A);
  static const Color q5 = Color(0xFF4FCB8B);
  static const Color q4 = Color(0xFFA3D25A);
  static const Color q3 = Color(0xFFE8B04A);
  static const Color q2 = Color(0xFFF08A5E);
  static const Color q1 = Color(0xFF8E94B0);
  static const Color q0 = Color(0xFF5C6283);
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
    secondary: AppColors.accent,
    onSecondary: AppColors.accentInk,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    outline: AppColors.line,
    outlineVariant: AppColors.line,
    secondaryContainer: AppColors.chip,
    onSecondaryContainer: AppColors.ink,
    error: Color(0xFFF08A5E),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.bg, foregroundColor: AppColors.ink, elevation: 0),
    dividerColor: AppColors.line,
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: AppColors.surface, indicatorColor: AppColors.chip),
    navigationRailTheme: const NavigationRailThemeData(backgroundColor: AppColors.surface, indicatorColor: AppColors.chip),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.line)),
    ),
  );
}

const TextStyle kMono = TextStyle(fontFamily: 'monospace', fontFeatures: <FontFeature>[FontFeature.tabularFigures()]);
