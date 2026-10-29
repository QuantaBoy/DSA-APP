import 'dart:math';

import 'package:flutter/material.dart';

/// Small animation building blocks used across the app.
/// All of them show the final state at once when the phone's "remove animations" setting is on.

bool _still(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Fades and slides its child up into place, [index] steps after the screen appears (for staggered lists).
class Rise extends StatelessWidget {
  const Rise({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (_still(context)) return child;
    final delay = min(index, 8) * 0.06; // later items wait a little longer, capped so long lists stay quick
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: (450 + delay * 1000).round()),
      curve: Interval(delay / (0.45 + delay), 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// A number that counts up to [value].
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, this.style, this.suffix = ''});

  final int value;
  final TextStyle? style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    if (_still(context)) return Text('$value$suffix', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}

/// Animates any 0..1 value (progress bars, rings, chart bars) from 0, and smoothly on later changes.
class Grow extends StatelessWidget {
  const Grow({super.key, required this.value, required this.builder, this.duration = const Duration(milliseconds: 900)});

  final double value;
  final Widget Function(BuildContext context, double value) builder;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (_still(context)) return builder(context, value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => builder(context, v),
    );
  }
}

/// Shrinks a little while pressed, like a physical button.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: widget.onTap == null ? null : (_) => _set(true),
    onTapUp: widget.onTap == null ? null : (_) => _set(false),
    onTapCancel: () => _set(false),
    onTap: widget.onTap,
    child: AnimatedScale(scale: _down ? 0.97 : 1, duration: const Duration(milliseconds: 120), curve: Curves.easeOut, child: widget.child),
  );
}

/// Gently floats up and down forever (for the illustration on the Today card).
class Bob extends StatefulWidget {
  const Bob({super.key, required this.child, this.height = 6, this.period = const Duration(seconds: 3)});

  final Widget child;
  final double height;
  final Duration period;

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_still(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, -widget.height * Curves.easeInOut.transform(_c.value)), child: child),
      child: widget.child,
    );
  }
}

/// Grey placeholder blocks with a light sweeping across, shown while data loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget block(double height, {double? width, double radius = 18}) => Container(
      height: height,
      width: width,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(radius)),
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          colors: [base, Colors.white.withValues(alpha: 0.6), base],
          stops: const [0.35, 0.5, 0.65],
          begin: Alignment(-1 - 2 + 4 * _c.value, -0.3),
          end: Alignment(1 - 2 + 4 * _c.value, 0.3),
        ).createShader(rect),
        child: child,
      ),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          block(20, width: 220, radius: 8),
          block(200, radius: 26),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
                    child: block(110),
                  ),
                ),
            ],
          ),
          for (var i = 0; i < 4; i++) block(72),
        ],
      ),
    );
  }
}

/// A one-shot burst of confetti falling from the top.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  final _pieces = List.generate(70, (i) {
    final r = Random(i);
    return (
      x: r.nextDouble(),
      drift: (r.nextDouble() - 0.5) * 0.4,
      speed: 0.6 + r.nextDouble() * 0.7,
      spin: r.nextDouble() * 12,
      size: 5 + r.nextDouble() * 6,
      color: const [Color(0xFF7C5CFF), Color(0xFFF59E0B), Color(0xFF16A34A), Color(0xFFEF4444), Color(0xFF0EA5E9)][i % 5],
    );
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_still(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_pieces, _c.value)),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<({double x, double drift, double speed, double spin, double size, Color color})> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final y = -0.1 + t * p.speed * 1.3;
      if (y > 1.1) continue;
      paint.color = p.color.withValues(alpha: (1 - t).clamp(0, 1));
      canvas.save();
      canvas.translate((p.x + p.drift * t) * size.width, y * size.height);
      canvas.rotate(p.spin * t);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
