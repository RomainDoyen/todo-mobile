import 'package:flutter/material.dart';

import 'src/models.dart';
import 'src/time.dart';

const accent = Color(0xFF0F766E);
const accentDark = Color(0xFF2DD4BF);
const ink = Color(0xFF152033);
const inkDark = Color(0xFFE8EEF8);
const muted = Color(0xFF5B6B82);
const danger = Color(0xFFE11D48);
const warning = Color(0xFFD97706);

Color colorFromHex(String hex) {
  final value = hex.replaceFirst('#', '').trim();
  if (value.length != 6) return accent;
  return Color(int.parse('FF$value', radix: 16));
}

String priorityLabel(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.low:
      return 'Basse';
    case TaskPriority.medium:
      return 'Moyenne';
    case TaskPriority.high:
      return 'Haute';
    case TaskPriority.urgent:
      return 'Urgente';
  }
}

Color priorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.low:
      return const Color(0xFF94A3B8);
    case TaskPriority.medium:
      return accent;
    case TaskPriority.high:
      return warning;
    case TaskPriority.urgent:
      return danger;
  }
}

String filterLabel(QuickFilter filter) {
  switch (filter) {
    case QuickFilter.all:
      return 'Toutes';
    case QuickFilter.today:
      return "Aujourd'hui";
    case QuickFilter.urgent:
      return 'Urgent';
    case QuickFilter.week:
      return 'Semaine';
  }
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final primary = dark ? accentDark : accent;
  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
    primary: primary,
    surface: dark ? const Color(0xFF0B1220) : const Color(0xFFEDF1F6),
  );
  final onSurface = dark ? inkDark : ink;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: onSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF151E31) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? const Color(0x24FFFFFF) : const Color(0x24152033)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? const Color(0x24FFFFFF) : const Color(0x24152033)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF151E31) : Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: dark ? const Color(0xFF06241F) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    textTheme: Typography.material2021(platform: TargetPlatform.android).black
        .apply(bodyColor: onSurface, displayColor: onSurface),
  );
}

String formatDue(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  const months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  final date = DateTime.parse(iso).toLocal();
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}';
}

String formatDueLong(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  const weekdays = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  final date = DateTime.parse(iso).toLocal();
  return '${weekdays[date.weekday - 1]} ${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}

enum DueTone { none, late, today, later }

DueTone dueTone(String? iso) {
  if (iso == null || iso.isEmpty) return DueTone.none;
  final due = DateTime.parse(iso).toLocal();
  if (due.isBefore(startOfToday())) return DueTone.late;
  if (!due.isAfter(endOfToday())) return DueTone.today;
  return DueTone.later;
}

double screenBottomInset(BuildContext context) {
  final media = MediaQuery.of(context);
  final keyboard = media.viewInsets.bottom;
  final bar = media.viewPadding.bottom;
  return keyboard > bar ? keyboard : bar;
}

Color cardSolid(Brightness brightness) {
  return brightness == Brightness.dark ? const Color(0xFF151E31) : Colors.white;
}

Color fieldFill(Brightness brightness) {
  return brightness == Brightness.dark ? const Color(0xFF0B1220) : const Color(0xFFEDF1F6);
}

Color hairline(Brightness brightness) {
  return brightness == Brightness.dark ? const Color(0x24FFFFFF) : const Color(0x24152033);
}

InputDecoration fieldDecoration(BuildContext context, {String? hint}) {
  final brightness = Theme.of(context).brightness;
  final radius = BorderRadius.circular(12);
  final side = BorderSide(color: hairline(brightness));
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: fieldFill(brightness),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(borderRadius: radius, borderSide: side),
    enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: side),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: brightness == Brightness.dark ? accentDark : accent, width: 1.5),
    ),
  );
}

class ColorPill extends StatelessWidget {
  const ColorPill({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
    this.onTap,
  });

  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        label,
        style: TextStyle(
          color: filled ? Colors.white : color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
    return Material(
      color: filled ? color : color.withValues(alpha: 0.14),
      shape: StadiumBorder(
        side: filled ? BorderSide.none : BorderSide(color: color.withValues(alpha: 0.45)),
      ),
      child: onTap == null
          ? child
          : InkWell(onTap: onTap, customBorder: const StadiumBorder(), child: child),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF0E1626), Color(0xFF0B1220)]
              : const [Color(0xFFF7F9FC), Color(0xFFEDF1F6)],
        ),
      ),
      child: child,
    );
  }
}
