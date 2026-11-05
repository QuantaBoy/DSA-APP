import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/prefs.dart';
import '../data/sounds.dart';
import '../logic/ascension.dart';
import 'roadmap_page.dart';

/// The worn title's name, or null.
String? wornLabel(String? id, Set<String> earned) => earned.contains(id) ? titleById(id)?.name : null;

/// Your current power, worked out on the home screen from your data. Null until the data loads.
typedef Power = ({
  int xp,
  Level level,
  Rank rank,
  Set<String> titles,
  ({HunterTitle title, Progress progress})? next,
  Map<String, Progress> progress, // per title id
});

final power = ValueNotifier<Power?>(null);

/// The rank badge: a hexagon with the level, wrapped in a living aura that gets wilder each rank.
class RankBadge extends StatefulWidget {
  const RankBadge({super.key, required this.rank, required this.level, this.size = 120, this.animate = true, this.glow = true});

  final Rank rank;
  final int level;
  final double size;
  final bool animate;
  final bool glow; // soft blurred light behind the badge

  @override
  State<RankBadge> createState() => _RankBadgeState();
}

class _RankBadgeState extends State<RankBadge> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void initState() {
    super.initState();
    if (widget.animate) unawaited(_spin.repeat());
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final [glow, core] = widget.rank.colors;
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, child) => CustomPaint(
          painter: _AuraPainter(t: _spin.value, glow: glow, power: widget.rank.index, soft: widget.glow),
          child: child,
        ),
        child: Center(
          child: ClipPath(
            clipper: _Hexagon(),
            child: Container(
              width: widget.size * 0.62,
              height: widget.size * 0.62,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [glow, core], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              alignment: Alignment.center,
              child: Text(
                '${widget.level}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: widget.size * 0.22,
                  shadows: [Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 6)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hexagon extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width / 2, 0)
    ..lineTo(s.width, s.height * 0.25)
    ..lineTo(s.width, s.height * 0.75)
    ..lineTo(s.width / 2, s.height)
    ..lineTo(0, s.height * 0.75)
    ..lineTo(0, s.height * 0.25)
    ..close();

  @override
  bool shouldReclip(_Hexagon old) => false;
}

/// Glow that breathes, a spinning energy ring, then sparks (rank 2+), orbiting shards (3+) and rising flames (4+).
class _AuraPainter extends CustomPainter {
  _AuraPainter({required this.t, required this.glow, required this.power, this.soft = true});

  final bool soft;

  final double t; // 0..1, loops
  final Color glow;
  final int power; // rank index 0..6

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final breathe = 0.5 + 0.5 * sin(t * 2 * pi * 2);
    if (soft) {
      canvas.drawCircle(
        c,
        r * (0.62 + 0.06 * breathe),
        Paint()
          ..color = glow.withValues(alpha: 0.25 + 0.08 * power + 0.15 * breathe)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
      );
    }
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.78),
      t * 2 * pi,
      pi * (1 + power / 6),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [glow.withValues(alpha: 0), glow],
          transform: GradientRotation(t * 2 * pi),
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final rnd = Random(power);
    final spark = Paint()..color = glow;
    if (power >= 2) {
      for (var i = 0; i < 4 + power * 2; i++) {
        final a = rnd.nextDouble() * 2 * pi + t * 2 * pi * (i.isEven ? 1 : -1);
        final d = r * (0.7 + 0.25 * rnd.nextDouble());
        canvas.drawCircle(c + Offset(cos(a), sin(a)) * d, r * 0.02 * (1 + rnd.nextDouble()), spark);
      }
    }
    if (power >= 3) {
      final shard = Paint()..color = glow.withValues(alpha: 0.85);
      for (var i = 0; i < power; i++) {
        final a = i * 2 * pi / power - t * 2 * pi;
        final p = c + Offset(cos(a), sin(a)) * r * 0.9;
        canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy - r * 0.07)
            ..lineTo(p.dx + r * 0.03, p.dy)
            ..lineTo(p.dx, p.dy + r * 0.07)
            ..lineTo(p.dx - r * 0.03, p.dy)
            ..close(),
          shard,
        );
      }
    }
    if (power >= 4) {
      for (var i = 0; i < 6 + power * 2; i++) {
        final x = (rnd.nextDouble() - 0.5) * r * 1.3;
        final life = (t * (1 + rnd.nextDouble()) + rnd.nextDouble()) % 1;
        canvas.drawCircle(
          c + Offset(x, r * 0.55 - life * r * 1.3),
          r * 0.035 * (1 - life),
          Paint()
            ..color = Color.lerp(glow, Colors.white, life)!.withValues(alpha: 1 - life)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_AuraPainter old) => old.t != t || old.glow != glow || old.power != power;
}

/// Gold fire for titles.
const _goldFire = (Color(0xFF7C2D12), Color(0xFFF59E0B), Color(0xFFFDE047));

/// Shows each level-up, rank-up and new title since last time, one System window after another.
/// Level-ups burn in your rank's fire (violet at the start), rank-ups in the new rank's fire, titles in gold.
Future<void> celebrate(BuildContext context, Power before, Power now) async {
  if (now.level.level > before.level.level) {
    await _systemWindow(
      context,
      fire: _fire[now.rank]!,
      tag: 'LEVEL UP',
      header: 'You reached Level ${now.level.level}',
      lines: ['Your power grows. Keep going.'],
      big: '${now.level.level}',
    );
  }
  if (now.rank.index > before.rank.index && context.mounted) {
    await _systemWindow(
      context,
      fire: _fire[now.rank]!,
      tag: 'RANK UP',
      header: now.rank.title,
      lines: ['You have ascended to a new rank.'],
      badge: now,
    );
  }
  for (final id in now.titles.difference(before.titles)) {
    final t = titleById(id);
    if (t == null || !context.mounted) continue;
    await _systemWindow(
      context,
      fire: _goldFire,
      tag: 'TITLE ACQUIRED',
      header: t.name,
      lines: ['${t.topic} conquered. Wear it with pride.'],
      titleId: t.id,
    );
  }
}

Future<void> _systemWindow(
  BuildContext context, {
  required (Color, Color, Color) fire,
  required String tag,
  required String header,
  required List<String> lines,
  String? big,
  Power? badge,
  String? titleId,
}) {
  unawaited(HapticFeedback.heavyImpact());
  play(Sound.levelUp);
  unawaited(Future<void>.delayed(const Duration(milliseconds: 180), HapticFeedback.heavyImpact));
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: tag,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    transitionDuration: const Duration(milliseconds: 500),
    transitionBuilder: (context, a, _, child) {
      final v = Curves.easeOutCubic.transform(a.value);
      return Opacity(
        opacity: a.value,
        child: Transform.scale(scale: 0.92 + 0.08 * v, child: child),
      );
    },
    pageBuilder: (context, _, _) =>
        _SystemWindow(fire: fire, tag: tag, header: header, lines: lines, big: big, badge: badge, titleId: titleId),
  );
}

class _SystemWindow extends StatefulWidget {
  const _SystemWindow({
    required this.fire,
    required this.tag,
    required this.header,
    required this.lines,
    this.big,
    this.badge,
    this.titleId,
  });

  final (Color, Color, Color) fire;
  final String tag;
  final String header;
  final List<String> lines;
  final String? big;
  final Power? badge;
  final String? titleId;

  @override
  State<_SystemWindow> createState() => _SystemWindowState();
}

class _SystemWindowState extends State<_SystemWindow> with SingleTickerProviderStateMixin {
  // One light sweep across the card as it lands.
  late final _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (_, flame, hot) = widget.fire;
    final text = widget.lines.join('\n');
    final width = min(320.0, MediaQuery.sizeOf(context).width - 48);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: const Color(0xFF0E0F1A),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: flame.withValues(alpha: 0.45)),
            boxShadow: [BoxShadow(color: flame.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 2)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Accent bar along the top.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [flame, hot, flame])),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(color: flame.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          widget.tag,
                          style: TextStyle(color: hot, fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.6, end: 1),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutBack,
                        builder: (context, s, child) => Transform.scale(scale: s, child: child),
                        child: switch (widget) {
                          _SystemWindow(:final big?) => ShaderMask(
                            shaderCallback: (r) => LinearGradient(
                              colors: [hot, flame],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(r),
                            child: Text(
                              big,
                              style: const TextStyle(color: Colors.white, fontSize: 84, height: 1, fontWeight: FontWeight.w900),
                            ),
                          ),
                          _SystemWindow(:final badge?) => RankBadge(rank: badge.rank, level: badge.level.level, size: 130, glow: false),
                          _ => Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [hot, flame], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            ),
                            child: const Icon(Icons.military_tech_rounded, color: Colors.white, size: 54),
                          ),
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.header,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14, height: 1.45),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          if (widget.titleId != null) ...[
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                                  minimumSize: const Size.fromHeight(46),
                                ),
                                onPressed: () {
                                  Prefs.equipTitle(widget.titleId);
                                  Navigator.pop(context);
                                },
                                child: const Text('Equip', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: flame,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(46),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Light sweep, once.
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _sweep,
                      builder: (context, _) => FractionalTranslation(
                        translation: Offset(-1.2 + 2.4 * Curves.easeInOut.transform(_sweep.value), 0),
                        child: Transform.rotate(
                          angle: 0.3,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, Colors.white.withValues(alpha: 0.12), Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Flames licking outward from all four sides of the box, plus embers floating up.
class _WindowFirePainter extends CustomPainter {
  _WindowFirePainter({
    required this.t,
    required this.flame,
    required this.hot,
    this.inset = const EdgeInsets.fromLTRB(36, 70, 36, 28),
    this.heights = const (64, 28, 20), // top, sides, bottom
    this.radius = 0,
    this.embers = 18,
  });

  final double t;
  final Color flame, hot;
  final EdgeInsets inset; // where the box sits inside the painted area
  final (double, double, double) heights;
  final double radius; // rounded box: flames start inside the corners
  final int embers;

  @override
  void paint(Canvas canvas, Size size) {
    final box = inset.deflateRect(Offset.zero & size).deflate(radius * 0.3);
    final (top, side, bottom) = heights;
    if (top == 0) {
      // No tongues on top: a glowing heat haze instead, pulsing with the fire.
      final pulse = 0.6 + 0.4 * sin(t * 2 * pi * 2);
      final haze = Rect.fromLTRB(box.left + 8, box.top - 14, box.right - 8, box.top + 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(haze, const Radius.circular(8)),
        Paint()
          ..shader = LinearGradient(
            colors: [
              flame.withValues(alpha: 0),
              flame.withValues(alpha: 0.55 * pulse),
              hot.withValues(alpha: 0.9 * pulse),
            ],
            stops: const [0, 0.6, 1],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(haze),
      );
    }
    for (final (layer, color, scale) in [(0, flame.withValues(alpha: 0.85), 1.0), (1, hot.withValues(alpha: 0.9), 0.5)]) {
      final paint = Paint()..color = color;
      // Top edge burns tallest; sides and bottom shorter.
      _edge(canvas, paint, box.topLeft, box.topRight, const Offset(0, -1), top * scale, layer, 0);
      _edge(canvas, paint, box.topRight, box.bottomRight, const Offset(1, 0), side * scale, layer, 1);
      _edge(canvas, paint, box.bottomRight, box.bottomLeft, const Offset(0, 1), bottom * scale, layer, 2);
      _edge(canvas, paint, box.bottomLeft, box.topLeft, const Offset(-1, 0), side * scale, layer, 3);
    }
    // Embers rising above the box.
    final rnd = Random(3);
    for (var i = 0; i < embers; i++) {
      final x = box.left + rnd.nextDouble() * box.width;
      final life = (t + rnd.nextDouble()) % 1;
      final y = box.top - top * 0.3 - life * top * 1.4;
      canvas.drawCircle(
        Offset(x + sin(life * 6 + i) * 6, y),
        2.5 * (1 - life),
        Paint()..color = Color.lerp(hot, flame, life)!.withValues(alpha: 1 - life),
      );
    }
  }

  /// Pointed flame tongues along one edge, each its own height, flickering and leaning in the heat.
  void _edge(Canvas canvas, Paint paint, Offset a, Offset b, Offset out, double tall, int layer, int side) {
    final length = (b - a).distance;
    final count = max(5, (length / 22).round());
    final along = (b - a) / length;
    final rnd = Random(side * 31 + layer);
    final path = Path()..moveTo(a.dx, a.dy);
    for (var i = 0; i < count; i++) {
      final p0 = a + along * (length * i / count);
      final p1 = a + along * (length * (i + 1) / count);
      final mid = (p0 + p1) / 2;
      final flicker = 0.5 + 0.5 * sin(t * 2 * pi * (2 + layer) + i * 2.3 + side * 1.3).abs();
      final h = tall * (0.55 + 0.45 * rnd.nextDouble()) * flicker;
      final lean = along * sin(t * 2 * pi + i) * h * 0.25;
      final tip = mid + out * h + lean;
      // Curved sides meeting in a sharp tip, like a real flame.
      path
        ..quadraticBezierTo(p0.dx + out.dx * h * 0.5, p0.dy + out.dy * h * 0.5, tip.dx, tip.dy)
        ..quadraticBezierTo(p1.dx + out.dx * h * 0.5, p1.dy + out.dy * h * 0.5, p1.dx, p1.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WindowFirePainter old) => old.t != t || old.flame != flame;
}

/// Fire colours per rank: (deep glow, flame, white-hot core). Violet fire at the start, gold and crimson at the top.
const _fire = <Rank, (Color, Color, Color)>{
  Rank.awakened: (Color(0xFF4C1D95), Color(0xFF8B5CF6), Color(0xFFE9D5FF)),
  Rank.shadowInitiate: (Color(0xFF1F2937), Color(0xFF94A3B8), Color(0xFFF1F5F9)),
  Rank.bladeOfLogic: (Color(0xFF0C4A6E), Color(0xFF38BDF8), Color(0xFFE0F2FE)),
  Rank.voidArchitect: (Color(0xFF1E1B4B), Color(0xFF22D3EE), Color(0xFFECFEFF)),
  Rank.abyssSovereign: (Color(0xFF581C87), Color(0xFFE879F9), Color(0xFFFDF4FF)),
  Rank.eclipseEmperor: (Color(0xFF7C2D12), Color(0xFFF97316), Color(0xFFFDE047)),
  Rank.monarch: (Color(0xFF7F1D1D), Color(0xFFEF4444), Color(0xFFFFD700)),
};

const _battleCries = ['NO MERCY. KEEP SOLVING.', 'EVERY PROBLEM MAKES YOU STRONGER.', 'THEY REST. YOU RISE.', 'BREAK YOUR LIMITS TODAY.'];

/// Home strip: a black card burning with your rank's fire. Flames rise from the bottom edge,
/// a lightning streak races around the border, and both get bigger and faster with each rank.
class PowerStrip extends StatefulWidget {
  const PowerStrip({super.key});

  @override
  State<PowerStrip> createState() => _PowerStripState();
}

class _PowerStripState extends State<PowerStrip> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  final _cry = _battleCries[DateTime.now().day % _battleCries.length]; // one battle cry per day

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: power,
    builder: (context, p, _) {
      if (p == null) return const SizedBox.shrink();
      final (deep, flame, hot) = _fire[p.rank]!;
      final strength = p.rank.index; // 0..6
      final left = p.level.needed - p.level.into;
      // Flames burn around the outside of the card, taller and wilder each rank.
      final (top, side, bottom) = (14.0 + strength * 3, 9.0 + strength * 2, 12.0 + strength * 3);
      final room = EdgeInsets.fromLTRB(side + 2, top + 2, side + 2, bottom + 2);
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16 - side - 2 > 4 ? 16 - side - 2 : 4),
        child: AnimatedBuilder(
          animation: _spin,
          builder: (context, child) => CustomPaint(
            painter: _WindowFirePainter(
              t: _spin.value,
              flame: flame,
              hot: hot,
              inset: room,
              heights: (top, side, bottom),
              radius: 20,
              embers: 0,
            ),
            child: child,
          ),
          child: Padding(
            padding: room,
            child: GestureDetector(
              onTap: () => unawaited(Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const RoadmapPage()))),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: flame, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedBuilder(
                    animation: _spin,
                    builder: (context, child) => CustomPaint(
                      painter: _FirePainter(t: _spin.value, deep: deep, flame: flame, hot: hot, strength: strength),
                      foregroundPainter: _EdgePainter(t: (_spin.value * (1 + strength * 0.3)) % 1, color: hot, power: strength),
                      child: child,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
                      child: Row(
                        children: [
                          RankBadge(rank: p.rank, level: p.level.level, size: 62, glow: false),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LV ${p.level.level}  ·  ${p.rank.title.toUpperCase()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: hot, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 11),
                                ),
                                const SizedBox(height: 2),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '$left XP ',
                                        style: TextStyle(color: hot, fontSize: 24),
                                      ),
                                      TextSpan(text: 'TO LEVEL ${p.level.level + 1}'),
                                    ],
                                  ),
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                    letterSpacing: 0.5,
                                    shadows: [Shadow(color: Colors.black, offset: Offset(2, 2))],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _Bar(value: p.level.into / p.level.needed, from: flame, to: hot, t: _spin),
                                const SizedBox(height: 6),
                                Text(
                                  switch (p.next) {
                                    final n? => '🏅 ${n.progress.total - n.progress.done} MORE TO ${n.title.name.toUpperCase()}',
                                    null => _cry,
                                  },
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Black base, a slash of the rank's colour, speed lines, and flame tongues licking up from the bottom.
class _FirePainter extends CustomPainter {
  _FirePainter({required this.t, required this.deep, required this.flame, required this.hot, required this.strength});

  final double t;
  final Color deep, flame, hot;
  final int strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xFF05030A), deep, const Color(0xFF05030A)],
          stops: const [0.15, 0.6, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );
    // Speed lines slashing across, like a power-up.
    final lines = Paint()
      ..color = flame.withValues(alpha: 0.14)
      ..strokeWidth = 2;
    for (var i = 0; i < 7; i++) {
      final x = ((i / 7 + t) % 1) * size.width * 1.4 - size.width * 0.2;
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height * 0.8, 0), lines);
    }
  }

  @override
  bool shouldRepaint(_FirePainter old) => old.t != t || old.flame != flame || old.strength != strength;
}

/// A bright streak racing around the rounded border, sharp (no blur). Length, width and count grow with rank.
class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.t, required this.color, required this.power});

  final double t;
  final Color color;
  final int power;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: 0.5),
    );
    final head = 0.14 + power * 0.04;
    for (final offset in [0.0, if (power >= 3) pi]) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 + power * 0.4
          ..shader = SweepGradient(
            colors: [Colors.transparent, color, Colors.white, Colors.transparent],
            stops: [0, head * 0.8, head, head + 0.01],
            transform: GradientRotation(t * 2 * pi + offset),
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.t != t || old.color != color || old.power != power;
}

/// XP bar: fire gradient fill with a shine sweeping along it.
class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.from, required this.to, required this.t});

  final double value;
  final Color from, to;
  final Animation<double> t;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(
      height: 8,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => AnimatedBuilder(
          animation: t,
          builder: (context, _) => CustomPaint(
            painter: _BarPainter(v: v, from: from, to: to, shine: t.value),
          ),
        ),
      ),
    ),
  );
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.v, required this.from, required this.to, required this.shine});

  final double v, shine;
  final Color from, to;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: 0.15));
    final fill = Rect.fromLTWH(0, 0, size.width * v, size.height);
    if (fill.width <= 0) return;
    canvas.drawRect(fill, Paint()..shader = LinearGradient(colors: [from, to]).createShader(fill));
    canvas.drawRect(
      Rect.fromLTWH(fill.width * shine - 14, 0, 28, size.height).intersect(fill),
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.v != v || old.shine != shine || old.from != from;
}

/// Top-right of Home: your title (the one you wear, else the latest earned) in a dark pill with a gold
/// streak racing round it. With no title yet it shows how close the next one is. Tap: the titles roadmap slides in.
class TitlePill extends StatefulWidget {
  const TitlePill({super.key});

  @override
  State<TitlePill> createState() => _TitlePillState();
}

class _TitlePillState extends State<TitlePill> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([power, Prefs.equippedTitle]),
    builder: (context, _) {
      final p = power.value;
      if (p == null) return const SizedBox.shrink();
      final worn = titleById(Prefs.equippedTitle.value);
      final title = worn != null && p.titles.contains(worn.id) ? worn : titles.where((t) => p.titles.contains(t.id)).lastOrNull;
      final next = p.next;
      const gold = Color(0xFFFDE047);
      final label = title?.name ?? (next == null ? 'Titles' : '${next.progress.total - next.progress.done} more to ${next.title.name}');
      return GestureDetector(
        onTap: () => unawaited(
          Navigator.push(
            context,
            PageRouteBuilder<void>(
              pageBuilder: (_, _, _) => const RoadmapPage(),
              transitionsBuilder: (_, a, _, child) => SlideTransition(
                position: Tween(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                child: child,
              ),
            ),
          ),
        ),
        child: AnimatedBuilder(
          animation: _spin,
          builder: (context, child) => CustomPaint(
            foregroundPainter: _EdgePainter(t: _spin.value, color: title == null ? Colors.white54 : gold, power: 2),
            child: child,
          ),
          child: Container(
            height: 40,
            constraints: const BoxConstraints(maxWidth: 200),
            padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
            decoration: BoxDecoration(color: const Color(0xFF0B0A14), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  title == null ? Icons.lock_outline_rounded : Icons.military_tech_rounded,
                  color: title == null ? Colors.white54 : gold,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: title == null ? Colors.white70 : gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Top-bar streak: just the flame and the number, bouncing in when it changes. Tap for the streak page.
class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.days, this.onTap});

  final int days;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: days > 0 ? const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF97316)]) : null,
        color: days > 0 ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔥', style: TextStyle(fontSize: 16, color: days > 0 ? null : Colors.grey)),
          const SizedBox(width: 4),
          TweenAnimationBuilder<double>(
            key: ValueKey(days),
            tween: Tween(begin: 1.6, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, s, child) => Transform.scale(scale: s, child: child),
            child: Text(
              '$days',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: days > 0 ? Colors.white : null),
            ),
          ),
        ],
      ),
    ),
  );
}
