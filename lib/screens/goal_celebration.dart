import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/sounds.dart';

/// Full-screen party when today's goal is done: a big check pops in, confetti rains,
/// and the streak flame counts up.
class GoalCelebration extends StatefulWidget {
  const GoalCelebration({super.key, required this.streak, required this.solvedToday});

  final int streak;
  final int solvedToday;

  @override
  State<GoalCelebration> createState() => _GoalCelebrationState();
}

const _cheers = ['You did it!! ✨', 'Sugoi! Goal cleared!', 'Your brain is on fire 🔥', 'See you tomorrow, hero!'];

class _GoalCelebrationState extends State<GoalCelebration> with TickerProviderStateMixin {
  late final _confetti = AnimationController(vsync: this, duration: const Duration(seconds: 5))..forward();
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  late final Timer _cheerTimer;
  int _cheer = 0;

  @override
  void initState() {
    super.initState();
    unawaited(HapticFeedback.heavyImpact());
    play(Sound.goal);
    _cheerTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (mounted) setState(() => _cheer = (_cheer + 1) % _cheers.length);
    });
  }

  @override
  void dispose() {
    _cheerTimer.cancel();
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
                builder: (context, _) => CustomPaint(painter: ConfettiPainter(_confetti.value)),
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
                        // Speech bubble with a changing cheer.
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
                        // A big check that pops in, ringed by the streak colour.
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.elasticOut,
                          builder: (context, v, child) => Transform.scale(scale: v, child: child),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 28),
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 6)],
                            ),
                            child: const Icon(Icons.check_rounded, size: 100, color: Color(0xFF6C4EF5)),
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

/// Confetti burst from the top, falling with gravity and spinning.
class ConfettiPainter extends CustomPainter {
  ConfettiPainter(this.t);

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
  bool shouldRepaint(ConfettiPainter old) => old.t != t;
}

/// A two-second confetti shower over the whole screen, for small wins (a GATE subtopic ticked).
void confettiBurst(BuildContext context) {
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 2200),
        onEnd: () => entry.remove(),
        builder: (context, t, _) => CustomPaint(size: MediaQuery.sizeOf(context), painter: ConfettiPainter(t)),
      ),
    ),
  );
  Overlay.of(context).insert(entry);
}

/// A coloured badge that pops in the middle of the screen, floats up and fades: "Nailed it! +10 XP".
void cheer(BuildContext context, {required IconData icon, required String text, required Color color, int? xp}) {
  final entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1100),
          builder: (context, t, child) => Opacity(
            opacity: t < 0.75 ? 1 : (1 - t) * 4,
            child: Transform.translate(
              offset: Offset(0, -40 * t),
              child: Transform.scale(scale: Curves.elasticOut.transform((t * 2.2).clamp(0, 1)), child: child),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    text,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  if (xp != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      '+$xp XP',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w800),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Overlay.of(context).insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 1150), entry.remove);
}
