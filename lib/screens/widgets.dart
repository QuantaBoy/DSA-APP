import 'dart:math';

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
  const StatTile({super.key, required this.icon, required this.value, required this.label, this.color, this.onTap, this.fire = false});

  final IconData icon;
  final String value;
  final String label;
  final Color? color; // tile tint; defaults to the brand colour
  final VoidCallback? onTap;
  final bool fire; // Overdrive: a blazing orange-to-red tile with white text

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final tint = color ?? theme.colorScheme.primary;
    final ink = fire ? Colors.white : null;
    final tile = Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: fire
            ? BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFBBF24), Color(0xFFF97316), Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFFF97316).withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6))],
              )
            : BoxDecoration(
                // Softly tinted tile in the stat's colour, like the mockup.
                color: Color.alphaBlend(tint.withValues(alpha: dark ? 0.14 : 0.08), theme.colorScheme.surfaceContainerLowest),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tint.withValues(alpha: dark ? 0.28 : 0.14)),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26, color: ink ?? tint),
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final style = theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: ink);
                final n = int.tryParse(value);
                return n == null ? Text(value, style: style) : CountUp(n, style: style);
              },
            ),
            Text(
              label,
              maxLines: 2,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ink ?? theme.colorScheme.onSurfaceVariant,
                fontWeight: fire ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
    return Expanded(child: fire ? _Burning(child: tile) : tile);
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

/// Flames flickering up from the top edge of a tile (Overdrive).
class _Burning extends StatefulWidget {
  const _Burning({required this.child});

  final Widget child;

  @override
  State<_Burning> createState() => _BurningState();
}

class _BurningState extends State<_Burning> with SingleTickerProviderStateMixin {
  late final _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    builder: (context, child) => CustomPaint(painter: _TileFlames(_t.value), child: child),
    child: widget.child,
  );
}

class _TileFlames extends CustomPainter {
  _TileFlames(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Behind the tile: tongues licking up past its top edge and out of its sides.
    for (final (layer, color, scale) in [(0, const Color(0xFFF97316), 1.0), (1, const Color(0xFFFDE047), 0.55)]) {
      final paint = Paint()..color = color.withValues(alpha: 0.9);
      const count = 7;
      final w = size.width - 24;
      final path = Path()..moveTo(12, 14);
      for (var i = 0; i < count; i++) {
        final x0 = 12 + w * i / count, x1 = 12 + w * (i + 1) / count;
        final flicker = 0.5 + 0.5 * sin(t * 2 * pi * (2 + layer) + i * 2.1).abs();
        final h = (14 + 10 * ((i * 37) % 5) / 4) * scale * flicker;
        final tip = Offset((x0 + x1) / 2 + sin(t * 2 * pi + i) * 3, 2 - h);
        path
          ..quadraticBezierTo(x0, 6 - h * 0.4, tip.dx, tip.dy)
          ..quadraticBezierTo(x1, 6 - h * 0.4, x1, 14);
      }
      path.close();
      canvas.drawPath(path, paint);
      // Side licks.
      for (final side in [0.0, size.width]) {
        final dir = side == 0 ? -1.0 : 1.0;
        for (var i = 0; i < 3; i++) {
          final y = 22.0 + i * (size.height - 40) / 2;
          final h = (8 + 4 * sin(t * 2 * pi * 3 + i + side)) * scale;
          canvas.drawPath(
            Path()
              ..moveTo(side, y)
              ..quadraticBezierTo(side + dir * h * 0.6, y + 4, side + dir * h, y + 8)
              ..quadraticBezierTo(side + dir * h * 0.4, y + 12, side, y + 16)
              ..close(),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TileFlames old) => old.t != t;
}
