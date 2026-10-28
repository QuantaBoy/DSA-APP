import 'package:flutter/material.dart';

/// Centered icon, title and message for screens with nothing to show yet.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(icon, size: 36, color: theme.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(height: 16),
        Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ]),
    );
  }
}

/// Small uppercase heading above a group of items.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(text.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
    );
  }
}

/// A number with a label, its icon in a tinted square, e.g. "12 / due now".
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.value, required this.label, this.color});

  final IconData icon;
  final String value;
  final String label;
  final Color? color; // icon tint; defaults to the brand colour

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: tint),
            ),
            const SizedBox(height: 12),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

/// Colours used for accents across the app.
abstract final class Accent {
  static const violet = Color(0xFF6C4EF5);
  static const indigo = Color(0xFF4F46E5);
  static const green = Color(0xFF16A34A);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF97316);
  static const sky = Color(0xFF0EA5E9);
}

/// Big purple gradient card at the top of a screen (the "Continue learning" look).
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.colors = const [Color(0xFF7C5CFF), Color(0xFF5B3FE0)], this.margin = const EdgeInsets.symmetric(horizontal: 16)});

  final Widget child;
  final List<Color> colors;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: child)),
      );
}

/// Small coloured pill: difficulty, platform, status.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color});

  /// Green / amber / red by difficulty.
  factory Pill.difficulty(String difficulty) =>
      Pill(difficulty, color: switch (difficulty) { 'Easy' => Accent.green, 'Hard' => Accent.red, _ => Accent.amber });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
        child: Text(text.toUpperCase(), style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
      );
}

/// Row of StatTiles with even gaps.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.children});

  final List<StatTile> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          for (final (i, tile) in children.indexed) ...[if (i > 0) const SizedBox(width: 10), tile],
        ]),
      );
}

/// "due today", "3 days overdue", "in 5 days".
String dueLabel(int daysOverdue) => switch (daysOverdue) {
      0 => 'due today',
      1 => '1 day overdue',
      > 1 => '$daysOverdue days overdue',
      -1 => 'tomorrow',
      _ => 'in ${-daysOverdue} days',
    };
