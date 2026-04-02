import 'package:flutter/material.dart';

/// Light theme (mobile default; user can switch on web too).
ThemeData msmLightTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    useMaterial3: true,
  );
}

/// Dark theme for web default: #1E1E1E background, ~87% white primary text.
ThemeData msmDarkTheme() {
  const bg = Color(0xFF1E1E1E);
  const onSurface = Color.fromRGBO(255, 255, 255, 0.87);
  const onSurfaceVariant = Color.fromRGBO(255, 255, 255, 0.60);
  const card = Color(0xFF2D2D2D);

  final base = ColorScheme.dark(
    surface: bg,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    primary: Colors.indigo.shade300,
    onPrimary: const Color(0xFF121212),
    secondary: Colors.indigo.shade200,
    onSecondary: const Color(0xFF121212),
    surfaceContainerHighest: card,
    outline: Color.fromRGBO(255, 255, 255, 0.12),
    outlineVariant: Color.fromRGBO(255, 255, 255, 0.08),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: base,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
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
      contentTextStyle: const TextStyle(color: onSurface),
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: TextStyle(color: onSurface.withValues(alpha: 0.9)),
      hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.5)),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.indigo.shade400;
        }
        return null;
      }),
    ),
    listTileTheme: ListTileThemeData(
      textColor: onSurface,
      iconColor: onSurface,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      textStyle: const TextStyle(color: onSurface),
    ),
  );
}
