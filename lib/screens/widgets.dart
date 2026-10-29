import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'motion.dart';

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(icon, size: 36, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// Small uppercase heading above a group of items.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});

  final String text;
  final String? action; // e.g. "See all"
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2)),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// A number with a label, its icon in a tinted square, e.g. "12 / due now".
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.value, required this.label, this.color, this.onTap});

  final IconData icon;
  final String value;
  final String label;
  final Color? color; // tile tint; defaults to the brand colour
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final tint = color ?? theme.colorScheme.primary;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            // Softly tinted tile in the stat's colour, like the mockup.
            color: Color.alphaBlend(tint.withValues(alpha: dark ? 0.14 : 0.08), theme.colorScheme.surfaceContainerLowest),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tint.withValues(alpha: dark ? 0.28 : 0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 26, color: tint),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final style = theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5);
                  final n = int.tryParse(value);
                  return n == null ? Text(value, style: style) : CountUp(n, style: style);
                },
              ),
              Text(
                label,
                maxLines: 2,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Difficulty colour: green / amber / red.
Color difficultyColor(String? difficulty) => switch (difficulty) {
  'Easy' => Accent.green,
  'Hard' => Accent.red,
  _ => Accent.amber,
};

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

/// Big gradient card at the top of a screen (the "Continue learning" look):
/// violet in light mode, deep cobalt in dark mode.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.margin = const EdgeInsets.symmetric(horizontal: 16)});

  final Widget child;
  final EdgeInsetsGeometry margin;

  static bool _dark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  /// The card's deep colour: use it for text on the white buttons inside the card.
  static Color ink(BuildContext context) => _dark(context) ? const Color(0xFF2C3480) : const Color(0xFF5B3FE0);

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    final colors = dark ? const [Color(0xFF2C3480), Color(0xFF1A1F5C)] : const [Color(0xFF7C5CFF), Color(0xFF5B3FE0)];
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(26),
        border: dark ? Border.all(color: const Color(0xFF6B7BFF).withValues(alpha: 0.25)) : null,
        boxShadow: [
          BoxShadow(
            color: (dark ? const Color(0xFF2C3480) : colors.last).withValues(alpha: dark ? 0.55 : 0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: IconTheme.merge(
          data: const IconThemeData(color: Colors.white),
          child: child,
        ),
      ),
    );
  }
}

/// Small coloured pill: difficulty, platform, status.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color});

  /// Green / amber / red by difficulty.
  factory Pill.difficulty(String difficulty) => Pill(difficulty, color: difficultyColor(difficulty));

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.4),
    ),
  );
}

/// Row of StatTiles with even gaps.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.children});

  final List<StatTile> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        for (final (i, tile) in children.indexed) ...[if (i > 0) const SizedBox(width: 10), tile],
      ],
    ),
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

/// A dialog button that looks native on each platform (Cupertino on iOS, Material elsewhere).
Widget adaptiveAction(BuildContext context, String label, VoidCallback onPressed, {bool primary = false, bool destructive = false}) {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return CupertinoDialogAction(onPressed: onPressed, isDefaultAction: primary, isDestructiveAction: destructive, child: Text(label));
  }
  if (destructive) {
    return FilledButton(
      style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
      onPressed: onPressed,
      child: Text(label),
    );
  }
  return primary ? FilledButton(onPressed: onPressed, child: Text(label)) : TextButton(onPressed: onPressed, child: Text(label));
}
