import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/prefs.dart';
import '../logic/ascension.dart';

/// The worn title's name, or null.
String? wornLabel(String? id, Set<String> earned) => earned.contains(id) ? titleById(id)?.name : null;

/// Your current power, worked out on the home screen from your data. Null until the data loads.
typedef Power = ({int xp, Level level, Rank rank, Set<String> titles, ({HunterTitle title, Progress progress})? next});

final power = ValueNotifier<Power?>(null);

const _system = Color(0xFF38BDF8); // the System window blue
const _gold = Color(0xFFFFD54F);

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

/// Every topic title, for the profile: earned ones in gold (tap Equip to wear), locked ones say how to earn them.
class TitlesList extends StatelessWidget {
  const TitlesList({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([Prefs.equippedTitle, power]),
    builder: (context, _) {
      final worn = Prefs.equippedTitle.value;
      final earned = power.value?.titles ?? const <String>{};
      final colors = Theme.of(context).colorScheme;
      const gold = Color(0xFFD4A017);
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (i, t) in titles.indexed) ...[
              if (i > 0) const Divider(height: 1, indent: 56),
              Builder(
                builder: (context) {
                  final has = earned.contains(t.id);
                  return ListTile(
                    leading: Icon(has ? Icons.military_tech_rounded : Icons.lock_outline_rounded, color: has ? gold : colors.outline),
                    title: Text(
                      t.name,
                      style: TextStyle(fontWeight: FontWeight.w800, color: has ? null : colors.onSurfaceVariant),
                    ),
                    subtitle: Text(has ? '${t.topic} cleared' : howToEarn(t)),
                    trailing: !has
                        ? null
                        : worn == t.id
                        ? const Text(
                            'WORN',
                            style: TextStyle(color: gold, fontWeight: FontWeight.w900),
                          )
                        : TextButton(onPressed: () => Prefs.equipTitle(t.id), child: const Text('Equip')),
                  );
                },
              ),
            ],
          ],
        ),
      );
    },
  );
}

/// Shows each level-up, rank-up and new title since last time, one System window after another.
Future<void> celebrate(BuildContext context, Power before, Power now) async {
  if (now.level.level > before.level.level) {
    await _systemWindow(
      context,
      header: 'LEVEL UP',
      lines: ['You have reached Level ${now.level.level}.', 'Your power grows.'],
      big: '${now.level.level}',
    );
  }
  if (now.rank.index > before.rank.index && context.mounted) {
    await _systemWindow(context, header: 'RANK UP', lines: ['You have ascended.', 'You are now: ${now.rank.title}.'], badge: now);
  }
  for (final id in now.titles.difference(before.titles)) {
    final t = titleById(id);
    if (t == null || !context.mounted) continue;
    await _systemWindow(context, header: 'TITLE ACQUIRED', lines: [t.name], titleId: t.id);
  }
}

Future<void> _systemWindow(
  BuildContext context, {
  required String header,
  required List<String> lines,
  String? big,
  Power? badge,
  String? titleId,
}) {
  unawaited(HapticFeedback.heavyImpact());
  unawaited(Future<void>.delayed(const Duration(milliseconds: 180), HapticFeedback.heavyImpact));
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: header,
    barrierColor: Colors.black.withValues(alpha: 0.9),
    transitionDuration: const Duration(milliseconds: 450),
    transitionBuilder: (context, a, _, child) {
      // Glitch in: a thin line that snaps open, with a flicker.
      final v = Curves.easeOutExpo.transform(a.value);
      return Opacity(
        opacity: a.value < 0.15
            ? (a.value * 40).floor().isEven
                  ? 1
                  : 0.3
            : 1,
        child: Transform(alignment: Alignment.center, transform: Matrix4.diagonal3Values(1, max(0.02, v), 1), child: child),
      );
    },
    pageBuilder: (context, _, _) => _SystemWindow(header: header, lines: lines, big: big, badge: badge, titleId: titleId),
  );
}

class _SystemWindow extends StatelessWidget {
  const _SystemWindow({required this.header, required this.lines, this.big, this.badge, this.titleId});

  final String header;
  final List<String> lines;
  final String? big;
  final Power? badge;
  final String? titleId;

  @override
  Widget build(BuildContext context) {
    final text = lines.join('\n');
    final accent = titleId != null ? _gold : (badge?.rank.colors.first ?? _system);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
          decoration: BoxDecoration(
            color: const Color(0xEE050A18),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent, width: 1.5),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.7), blurRadius: 30),
              BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 80, spreadRadius: 10),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.priority_high_rounded, color: accent, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'SYSTEM',
                    style: TextStyle(color: accent, fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 12),
                  ),
                ],
              ),
              Divider(color: accent.withValues(alpha: 0.5)),
              const SizedBox(height: 6),
              Text(
                header,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  shadows: [Shadow(color: accent, blurRadius: 18)],
                ),
              ),
              if (big != null)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 2.4, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (context, s, child) => Transform.scale(scale: s, child: child),
                  child: Text(
                    big!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 84,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      shadows: [
                        Shadow(color: accent, blurRadius: 30),
                        Shadow(color: accent, blurRadius: 60),
                      ],
                    ),
                  ),
                ),
              if (badge != null)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.elasticOut,
                  builder: (context, s, child) => Transform.scale(scale: s, child: child),
                  child: RankBadge(rank: badge!.rank, level: badge!.level.level, size: 170),
                ),
              if (titleId != null) const _ShineIcon(),
              const SizedBox(height: 10),
              // Typed out letter by letter, like a System message.
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: text.length),
                duration: Duration(milliseconds: 35 * text.length),
                builder: (context, n, _) => Text(
                  text.substring(0, n),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: titleId != null ? _gold : Colors.white,
                    fontSize: titleId != null ? 22 : 16,
                    fontWeight: titleId != null ? FontWeight.w900 : FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (titleId != null)
                    TextButton(
                      onPressed: () {
                        Prefs.equipTitle(titleId);
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(foregroundColor: _gold),
                      child: const Text('EQUIP', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(foregroundColor: accent),
                    child: const Text('ACCEPT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A medal with a light sweep running across it.
class _ShineIcon extends StatefulWidget {
  const _ShineIcon();

  @override
  State<_ShineIcon> createState() => _ShineIconState();
}

class _ShineIconState extends State<_ShineIcon> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    unawaited(_c.repeat());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => ShaderMask(
      shaderCallback: (r) => LinearGradient(
        colors: const [_gold, Colors.white, _gold],
        stops: [(_c.value - 0.2).clamp(0, 1), _c.value, (_c.value + 0.2).clamp(0, 1)],
      ).createShader(r),
      child: child,
    ),
    child: const Icon(Icons.military_tech_rounded, size: 90, color: Colors.white),
  );
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: flame.withValues(alpha: 0.45), offset: const Offset(0, 6), blurRadius: 18)],
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
                            _cry,
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
    // Flame tongues: an outer flame and a white-hot inner layer, each tongue flickering on its own.
    final count = 14 + strength * 3;
    final tall = size.height * (0.35 + strength * 0.07);
    for (final (layer, color, scale) in [(0, flame.withValues(alpha: 0.55), 1.0), (1, hot.withValues(alpha: 0.5), 0.55)]) {
      final path = Path()..moveTo(0, size.height);
      for (var i = 1; i <= count; i++) {
        final x = size.width * i / count;
        final flicker = 0.55 + 0.45 * sin(t * 2 * pi * (2 + layer) + i * 1.7);
        final h = tall * scale * flicker;
        path.quadraticBezierTo(x - size.width / count / 2, size.height - h * 1.4, x, size.height - h * 0.2);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
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
