import 'package:flutter/material.dart';

/// Modo de tema global (lo controla el ajuste "Modo oscuro" del perfil).
final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

/// Paleta corporativa industrial: azul cobalto y grises acero.
class Pal {
  final Color bg, surface, surface2, fg, muted, line;
  final Color accent, onAccent, accentSoft;
  final Color steel, steelFg, steelMuted;
  final Color ok, okSoft, warn, warnSoft, crit, critSoft;

  const Pal({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.fg,
    required this.muted,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.steel,
    required this.steelFg,
    required this.steelMuted,
    required this.ok,
    required this.okSoft,
    required this.warn,
    required this.warnSoft,
    required this.crit,
    required this.critSoft,
  });

  static const Pal light = Pal(
    bg: Color(0xFFEDF0F4),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFE2E7EE),
    fg: Color(0xFF142033),
    muted: Color(0xFF5A6678),
    line: Color(0xFFCBD3DE),
    accent: Color(0xFF1F4E9A),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFDCE5F4),
    steel: Color(0xFF22324A),
    steelFg: Color(0xFFF2F5F9),
    steelMuted: Color(0xFFA9B6C8),
    ok: Color(0xFF1C7448),
    okSoft: Color(0xFFDDF0E5),
    warn: Color(0xFFA8650E),
    warnSoft: Color(0xFFF8EAD3),
    crit: Color(0xFFB42318),
    critSoft: Color(0xFFFBE3E0),
  );

  static const Pal dark = Pal(
    bg: Color(0xFF0E141C),
    surface: Color(0xFF162030),
    surface2: Color(0xFF1E2A3A),
    fg: Color(0xFFE5EBF2),
    muted: Color(0xFF94A2B4),
    line: Color(0xFF2C3A4D),
    accent: Color(0xFF6A9BEA),
    onAccent: Color(0xFF06101E),
    accentSoft: Color(0xFF1B2D4B),
    steel: Color(0xFF0A1019),
    steelFg: Color(0xFFE5EBF2),
    steelMuted: Color(0xFF8796AA),
    ok: Color(0xFF55C98F),
    okSoft: Color(0xFF14301F),
    warn: Color(0xFFE6B25E),
    warnSoft: Color(0xFF33270F),
    crit: Color(0xFFF0756C),
    critSoft: Color(0xFF3A1715),
  );

  static Pal of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData buildTheme(Brightness b) {
  final Pal p = b == Brightness.dark ? Pal.dark : Pal.light;
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1F4E9A),
    brightness: b,
  ).copyWith(
    primary: p.accent,
    onPrimary: p.onAccent,
    surface: p.surface,
    onSurface: p.fg,
    error: p.crit,
  );
  final OutlineInputBorder borde = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: p.line),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    appBarTheme: AppBarTheme(
      backgroundColor: p.steel,
      foregroundColor: p.steelFg,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.bg,
      border: borde,
      enabledBorder: borde,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: p.accent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        side: BorderSide(color: p.line),
        foregroundColor: p.fg,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
  );
}
