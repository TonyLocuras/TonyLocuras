import 'package:flutter/material.dart';

const _red = Color(0xFFE53935);

/// Dark tactical theme: high contrast, 56 dp touch targets (gloves).
ThemeData tacticalTheme({bool night = false}) {
  final accent = night ? const Color(0xFFFF1744) : _red;
  final bg = night ? Colors.black : const Color(0xFF111418);
  final scheme = ColorScheme.dark(
    primary: accent,
    surface: bg,
    onSurface: night ? const Color(0xFFFF8A80) : Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 56)),
    ),
    chipTheme: const ChipThemeData(labelPadding: EdgeInsets.all(10)),
  );
}
