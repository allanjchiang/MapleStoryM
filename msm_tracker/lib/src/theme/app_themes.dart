import 'package:flutter/material.dart';

/// Shared text theme: larger body, clear section headers, readable secondary.
TextTheme _msmTextTheme({
  required Color onSurface,
  required Color onSurfaceVariant,
}) {
  return TextTheme(
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      color: onSurface,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      color: onSurface,
    ),
    titleSmall: TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: onSurface,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    bodySmall: TextStyle(
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w400,
      color: onSurfaceVariant,
    ),
    labelLarge: TextStyle(
      fontSize: 15,
      height: 1.35,
      fontWeight: FontWeight.w500,
      color: onSurface,
    ),
  );
}

/// Light theme (mobile default; user can switch on web too).
ThemeData msmLightTheme() {
  const onSurface = Color(0xFF1C1B1F);
  const onSurfaceVariant = Color(0xFF49454F);
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    surface: const Color(0xFFF5F5F7),
  );
  const card = Color(0xFFFFFFFF);

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: _msmTextTheme(onSurface: onSurface, onSurfaceVariant: onSurfaceVariant),
    cardTheme: CardThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 12,
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    checkboxTheme: CheckboxThemeData(
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

/// Dark theme: #1E1E1E background; cards lighter for stronger separation.
ThemeData msmDarkTheme() {
  const bg = Color(0xFF1E1E1E);
  const onSurface = Color.fromRGBO(255, 255, 255, 0.87);
  const onSurfaceVariant = Color.fromRGBO(255, 255, 255, 0.60);
  const card = Color(0xFF3A3A3A);

  final base = ColorScheme.dark(
    surface: bg,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    primary: Colors.indigo.shade300,
    onPrimary: const Color(0xFF121212),
    secondary: Colors.indigo.shade200,
    onSecondary: const Color(0xFF121212),
    surfaceContainerHighest: card,
    outline: Color.fromRGBO(255, 255, 255, 0.14),
    outlineVariant: Color.fromRGBO(255, 255, 255, 0.10),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: base,
    textTheme: _msmTextTheme(onSurface: onSurface, onSurfaceVariant: onSurfaceVariant),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colors.indigo.shade400,
      foregroundColor: Colors.white,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF323232),
      contentTextStyle: const TextStyle(color: onSurface, fontSize: 15),
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: TextStyle(color: onSurface.withValues(alpha: 0.9)),
      hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.5)),
    ),
    checkboxTheme: CheckboxThemeData(
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.indigo.shade400;
        }
        return null;
      }),
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 12,
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      textStyle: const TextStyle(color: onSurface, fontSize: 15),
    ),
  );
}
