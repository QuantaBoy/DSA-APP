import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/prefs.dart';
import '../logic/ascension.dart';

/// Your current power, worked out on the home screen from your data. Null until the data loads.
typedef Power = ({int xp, Level level, Rank rank, Set<String> titles});

final power = ValueNotifier<Power?>(null);

const _system = Color(0xFF38BDF8); // the System window blue
const _gold = Color(0xFFFFD54F);

/// The rank badge: a hexagon with the level, wrapped in a living aura that gets wilder each rank.
class RankBadge extends StatefulWidget {
  const RankBadge({super.key, required this.rank, required this.level, this.size = 120, this.animate = true});

  final Rank rank;
  final int level;
  final double size;
  final bool animate;

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
          painter: _AuraPainter(t: _spin.value, glow: glow, power: widget.rank.index),
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
  _AuraPainter({required this.t, required this.glow, required this.power});

  final double t; // 0..1, loops
  final Color glow;
  final int power; // rank index 0..6

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final breathe = 0.5 + 0.5 * sin(t * 2 * pi * 2);
    canvas.drawCircle(
      c,
      r * (0.62 + 0.06 * breathe),
      Paint()
        ..color = glow.withValues(alpha: 0.25 + 0.08 * power + 0.15 * breathe)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
    );
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

/// Small level chip for the home header.
class LevelChip extends StatelessWidget {
  const LevelChip({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: power,
    builder: (context, p, _) {
      if (p == null) return const SizedBox.shrink();
      return GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RankBadge(rank: p.rank, level: p.level.level, size: 40),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.rank.title.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: p.rank.colors.last),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: 70,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: p.level.into / p.level.needed, minHeight: 4, color: p.rank.colors.first),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// Profile card: badge with aura, level, rank, the title you wear, XP to the next level, and the title collection.
class PowerCard extends StatelessWidget {
  const PowerCard({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: power,
    builder: (context, p, _) {
      if (p == null) return const SizedBox.shrink();
      final theme = Theme.of(context);
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF0B0D1A), Color(0xFF1B1F3B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: p.rank.colors.first.withValues(alpha: 0.6)),
          boxShadow: [BoxShadow(color: p.rank.colors.first.withValues(alpha: 0.35), blurRadius: 24)],
        ),
        child: Column(
          children: [
            Row(
              children: [
                RankBadge(rank: p.rank, level: p.level.level, size: 110),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LEVEL ${p.level.level}',
                        style: const TextStyle(color: _system, fontWeight: FontWeight.w900, letterSpacing: 2),
                      ),
                      Text(
                        p.rank.title,
                        style: TextStyle(color: p.rank.colors.first, fontSize: 22, fontWeight: FontWeight.w900, height: 1.1),
                      ),
                      ValueListenableBuilder(
                        valueListenable: Prefs.equippedTitle,
                        builder: (context, id, _) => Text(
                          titleById(id)?.name ?? 'No title worn',
                          style: TextStyle(
                            color: id == null ? Colors.white54 : _gold,
                            fontWeight: FontWeight.w800,
                            shadows: id == null ? null : const [Shadow(color: _gold, blurRadius: 10)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: p.level.into / p.level.needed,
                minHeight: 8,
                color: _system,
                backgroundColor: Colors.white12,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${p.level.into} / ${p.level.needed} XP to Lv ${p.level.level + 1}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: _gold),
                onPressed: () => unawaited(Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const TitlesPage()))),
                icon: const Icon(Icons.military_tech_rounded),
                label: Text('Titles  ${p.titles.length} / ${titles.length}'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Every title: earned ones in gold (tap to wear), locked ones show how to earn them, secret ones stay hidden.
class TitlesPage extends StatelessWidget {
  const TitlesPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF07080F),
    appBar: AppBar(
      backgroundColor: const Color(0xFF07080F),
      foregroundColor: Colors.white,
      title: const Text(
        'Titles',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
    ),
    body: ValueListenableBuilder(
      valueListenable: Prefs.equippedTitle,
      builder: (context, worn, _) {
        final earned = power.value?.titles ?? const {};
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final t in titles)
              Builder(
                builder: (context) {
                  final has = earned.contains(t.id);
                  final hidden = t.secret && !has;
                  return Card(
                    color: has ? const Color(0xFF1A1630) : const Color(0xFF12131C),
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: worn == t.id ? _gold : (has ? _gold.withValues(alpha: 0.3) : Colors.white10)),
                    ),
                    child: ListTile(
                      leading: Icon(has ? Icons.military_tech_rounded : Icons.lock_rounded, color: has ? _gold : Colors.white24),
                      title: Text(
                        hidden ? '???' : t.name,
                        style: TextStyle(color: has ? _gold : Colors.white38, fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(hidden ? 'A secret. Keep going.' : t.how, style: const TextStyle(color: Colors.white38)),
                      trailing: !has
                          ? null
                          : worn == t.id
                          ? const Text(
                              'WORN',
                              style: TextStyle(color: _gold, fontWeight: FontWeight.w900),
                            )
                          : TextButton(onPressed: () => Prefs.equipTitle(t.id), child: const Text('Equip')),
                    ),
                  );
                },
              ),
          ],
        );
      },
    ),
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
    await _systemWindow(context, header: 'TITLE ACQUIRED', lines: [t.name], titleId: id);
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
