import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0B0B0D);
  static const surface = Color(0xFF16161A);
  static const surface2 = Color(0xFF202026);
  static const accent = Color(0xFFFF5A1F); // naranja fuego
  static const text = Color(0xFFF2F2F4);
  static const muted = Color(0xFF9A9AA5);
  // Semáforo: no se confunde con el acento. Siempre con icono y texto.
  static const green = Color(0xFF2ECC71);
  static const amber = Color(0xFFF5B301);
  static const crimson = Color(0xFFB3122B);
  static const left = Color(0xFF4FC3F7);
  static const right = Color(0xFFFF5A1F);
}

ThemeData buildTheme(double textScale) {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.text,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(56, 56),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(56, 56),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.surface2, width: 2),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent.withValues(alpha: 0.25),
      height: 72,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
      fontSizeFactor: textScale,
    ),
  );
}

/// Semáforo: color + icono + texto.
({Color color, IconData icon, String label}) trafficStyle(String c) => switch (c) {
      'green' => (color: AppColors.green, icon: Icons.check_circle, label: 'VERDE'),
      'amber' => (color: AppColors.amber, icon: Icons.warning_amber_rounded, label: 'ÁMBAR'),
      _ => (color: AppColors.crimson, icon: Icons.dangerous, label: 'ROJO'),
    };

Widget sectionTitle(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
      child: Text(t.toUpperCase(),
          style: const TextStyle(
              color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
    );

/// Selector numérico grande con +/- (uso con magnesio).
class Stepper2 extends StatelessWidget {
  final String label;
  final double value;
  final double step;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String suffix;
  const Stepper2({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.min = 0,
    this.max = 999,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    String f(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    return Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
      IconButton.filledTonal(
        iconSize: 28,
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        onPressed: value - step >= min ? () => onChanged(value - step) : null,
        icon: const Icon(Icons.remove),
      ),
      SizedBox(
        width: 84,
        child: Text('${f(value)}$suffix',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      ),
      IconButton.filledTonal(
        iconSize: 28,
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        onPressed: value + step <= max ? () => onChanged(value + step) : null,
        icon: const Icon(Icons.add),
      ),
    ]);
  }
}
