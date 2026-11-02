import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen party when today's goal is done: Aru (our own chibi mascot) dances and cheers,
/// confetti rains, and the streak flame counts up.
class GoalCelebration extends StatefulWidget {
  const GoalCelebration({super.key, required this.streak, required this.solvedToday});

  final int streak;
  final int solvedToday;

  @override
  State<GoalCelebration> createState() => _GoalCelebrationState();
}

const _cheers = ['You did it!! ✨', 'Sugoi! Goal cleared!', 'Your brain is on fire 🔥', 'See you tomorrow, hero!'];

class _GoalCelebrationState extends State<GoalCelebration> with TickerProviderStateMixin {
  late final _dance = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  late final _confetti = AnimationController(vsync: this, duration: const Duration(seconds: 5))..forward();
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  late final Timer _cheerTimer;
  int _cheer = 0;

  @override
  void initState() {
    super.initState();
    unawaited(HapticFeedback.heavyImpact());
    _cheerTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (mounted) setState(() => _cheer = (_cheer + 1) % _cheers.length);
    });
  }

  @override
  void dispose() {
    _cheerTimer.cancel();
    _dance.dispose();
    _confetti.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pop = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.5, curve: Curves.elasticOut),
    );
    final rise = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutBack),
    );
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6C4EF5), Color(0xFFB04DF0), Color(0xFFFF6FB5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_confetti.value)),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Spacer(),
                        ScaleTransition(
                          scale: pop,
                          child: const Text(
                            'GOAL CLEARED!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              shadows: [Shadow(color: Color(0x88000000), offset: Offset(0, 4), blurRadius: 0)],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Speech bubble that changes what Aru says.
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                          child: Container(
                            key: ValueKey(_cheer),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              _cheers[_cheer],
                              style: const TextStyle(color: Color(0xFF6C4EF5), fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 240,
                          height: 300,
                          child: AnimatedBuilder(
                            animation: _dance,
                            builder: (context, _) => CustomPaint(painter: _AruPainter(_dance.value)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SlideTransition(
                          position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(rise),
                          child: FadeTransition(
                            opacity: rise,
                            child: _StreakBadge(streak: widget.streak),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${widget.solvedToday} new solved today · every review cleared',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF6C4EF5),
                            minimumSize: const Size.fromHeight(54),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Let's go!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flame with the streak counting up to today's number.
class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(30)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🔥', style: TextStyle(fontSize: 30)),
        const SizedBox(width: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: max(0, streak - 1).toDouble(), end: streak.toDouble()),
          duration: const Duration(milliseconds: 1200),
          curve: const Interval(0.5, 1, curve: Curves.easeOutBack),
          builder: (context, v, _) => Text(
            '${v.round()} day streak',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

/// Aru: an original chibi girl with violet twin tails who bounces, sways and waves both arms.
/// Drawn on a 240 × 300 canvas; [t] loops 0..1 once per dance beat.
class _AruPainter extends CustomPainter {
  _AruPainter(this.t);

  final double t;

  static const _skin = Color(0xFFFFE0CC);
  static const _hair = Color(0xFF5B3FD6);
  static const _hairDark = Color(0xFF3B2A99);
  static const _dress = Color(0xFFFF6FB5);
  static const _eye = Color(0xFF3B2A99);

  @override
  void paint(Canvas canvas, Size size) {
    final beat = sin(t * 2 * pi);
    final hop = -beat.abs() * 14; // bounce on every half beat
    final sway = beat * 0.09;
    canvas
      ..save()
      ..translate(size.width / 2, size.height * 0.62 + hop)
      ..rotate(sway);
    final fill = Paint();

    // Shadow under her feet stays on the floor.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, 112 - hop), width: 90 - beat.abs() * 20, height: 12),
      fill..color = Colors.black.withValues(alpha: 0.18),
    );

    // Legs, kicking in turn.
    for (final side in [-1, 1]) {
      final kick = max(0.0, beat * side) * 0.5;
      canvas
        ..save()
        ..translate(side * 14.0, 60)
        ..rotate(side * kick);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-6, 0, 12, 42), const Radius.circular(6)), fill..color = _skin);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-8, 36, 18, 10), const Radius.circular(5)), fill..color = _hairDark);
      canvas.restore();
    }

    // Dress with a frilly hem.
    final dress = Path()
      ..moveTo(-24, -10)
      ..lineTo(24, -10)
      ..lineTo(42, 62)
      ..lineTo(-42, 62)
      ..close();
    canvas.drawPath(
      dress,
      fill
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF9CCB), _dress],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(const Rect.fromLTWH(-42, -10, 84, 72)),
    );
    fill.shader = null;
    for (var x = -36.0; x <= 36; x += 12) {
      canvas.drawCircle(Offset(x, 62), 6, fill..color = Colors.white);
    }
    canvas.drawCircle(const Offset(0, 4), 5, fill..color = Colors.white); // bow

    // Head, tilting with the beat.
    canvas
      ..save()
      ..translate(0, -52)
      ..rotate(-sway * 1.6);

    // Twin tails swinging the other way.
    for (final side in [-1, 1]) {
      canvas
        ..save()
        ..translate(side * 50.0, -22)
        ..rotate(-side * 0.45 - beat * 0.35);
      canvas.drawOval(const Rect.fromLTWH(-14, 0, 28, 74), fill..color = _hair);
      canvas.drawCircle(Offset.zero, 8, fill..color = _dress); // hair tie
      canvas.restore();
    }

    canvas.drawCircle(const Offset(0, -6), 50, fill..color = _hair); // back hair
    canvas.drawCircle(Offset.zero, 44, fill..color = _skin); // face

    // Bangs: three soft points over the forehead.
    final bangs = Path()
      ..moveTo(-48, -6)
      ..quadraticBezierTo(-46, -54, 0, -54)
      ..quadraticBezierTo(46, -54, 48, -6)
      ..quadraticBezierTo(34, -26, 22, -10)
      ..quadraticBezierTo(12, -30, 0, -12)
      ..quadraticBezierTo(-12, -30, -22, -10)
      ..quadraticBezierTo(-34, -26, -48, -6)
      ..close();
    canvas.drawPath(bangs, fill..color = _hair);

    // Star hair clip.
    canvas.drawPath(_star(const Offset(-30, -34), 9), fill..color = const Color(0xFFFFD54F));

    // Big sparkly eyes; a quick blink once per loop.
    final blink = t > 0.92;
    for (final side in [-1, 1]) {
      final c = Offset(side * 17.0, 6);
      if (blink) {
        canvas.drawArc(
          Rect.fromCenter(center: c, width: 18, height: 10),
          0,
          pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = _eye,
        );
      } else {
        canvas.drawOval(Rect.fromCenter(center: c, width: 18, height: 24), fill..color = _eye);
        canvas.drawOval(Rect.fromCenter(center: c + const Offset(0, 4), width: 12, height: 12), fill..color = const Color(0xFF8B7CFF));
        canvas.drawCircle(c + const Offset(-3, -5), 4, fill..color = Colors.white);
        canvas.drawCircle(c + const Offset(3, 5), 2, fill..color = Colors.white);
      }
    }

    // Blush and a big open smile.
    for (final side in [-1, 1]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(side * 28.0, 22), width: 14, height: 8), fill..color = const Color(0x66FF6FB5));
    }
    final mouth = Path()
      ..moveTo(-9, 20)
      ..quadraticBezierTo(0, 36 + beat.abs() * 4, 9, 20)
      ..close();
    canvas.drawPath(mouth, fill..color = const Color(0xFFB0244F));
    canvas.drawCircle(const Offset(0, 28), 4, fill..color = const Color(0xFFFF8FA3));

    canvas.restore(); // head

    // Arms waving above her head, out of step with each other.
    for (final side in [-1, 1]) {
      final wave = sin(t * 4 * pi + (side == 1 ? pi : 0)) * 0.35;
      canvas
        ..save()
        ..translate(side * 24.0, -4)
        ..rotate(-side * (2.15 + wave)); // up and out, like a cheer
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, 0, 10, 44), const Radius.circular(5)), fill..color = _skin);
      canvas.drawCircle(const Offset(0, 46), 8, fill..color = _skin);
      canvas.restore();
    }

    canvas.restore(); // body

    // Sparkles popping around her.
    final sparkle = Paint()..color = Colors.white;
    for (var i = 0; i < 6; i++) {
      final phase = (t + i / 6) % 1;
      final a = i * pi / 3;
      final p = Offset(size.width / 2 + cos(a) * 105, size.height * 0.4 + sin(a) * 90);
      canvas.drawPath(_star(p, 4 + 6 * sin(phase * pi)), sparkle..color = Colors.white.withValues(alpha: sin(phase * pi)));
    }
  }

  static Path _star(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final rr = i.isEven ? r : r * 0.4;
      final a = i * pi / 4 - pi / 2;
      final p = c + Offset(cos(a), sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_AruPainter old) => old.t != t;
}

/// Confetti burst from the top, falling with gravity and spinning.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);

  final double t; // 0..1 over the burst

  static const _colors = [Color(0xFFFFD54F), Color(0xFF4ADE80), Color(0xFF38BDF8), Color(0xFFFFFFFF), Color(0xFFFF6FB5), Color(0xFFF97316)];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(7);
    final paint = Paint();
    for (var i = 0; i < 110; i++) {
      final x0 = rnd.nextDouble() * size.width;
      final vx = (rnd.nextDouble() - 0.5) * 120;
      final delay = rnd.nextDouble() * 0.35;
      final speed = 0.6 + rnd.nextDouble() * 0.6;
      final spin = rnd.nextDouble() * 10;
      final color = _colors[i % _colors.length];
      final life = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (life <= 0) continue;
      final y = -20 + life * life * size.height * 1.2 * speed + life * 60;
      final x = x0 + vx * life + sin(life * 12 + i) * 14;
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(spin * life * 6);
      canvas.drawRect(const Rect.fromLTWH(-4, -7, 8, 14), paint..color = color.withValues(alpha: 1 - life * 0.3));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
