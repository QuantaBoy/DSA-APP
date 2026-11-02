import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/prefs.dart';
import '../logic/ascension.dart';

/// The worn title with its stars, e.g. "Array Executioner ★★", or null.
String? wornLabel(String? id, Set<String> earned) {
  final t = titleById(id);
  return t == null ? null : titleLabel(t, tierOf(t.id, earned));
}

/// Your current power, worked out on the home screen from your data. Null until the data loads.
typedef Power = ({int xp, Level level, Rank rank, Set<String> titles, ({HunterTitle title, Progress progress})? next});

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

/// Every topic title with its stars, for the profile: earned ones in gold (tap Equip to wear), locked ones say how to earn them.
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
                  final tier = tierOf(t.id, earned);
                  final has = tier > 0;
                  return ListTile(
                    leading: Icon(has ? Icons.military_tech_rounded : Icons.lock_outline_rounded, color: has ? gold : colors.outline),
                    title: Text(
                      has ? titleLabel(t, tier) : t.name,
                      style: TextStyle(fontWeight: FontWeight.w800, color: has ? null : colors.onSurfaceVariant),
                    ),
                    subtitle: Text(has ? '${t.topic} · tier $tier of ${t.fullOnly ? 1 : 3}' : howToEarn(t)),
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
    final tier = int.parse(id.split('#').last);
    if (t == null || tier < tierOf(t.id, now.titles) || !context.mounted) continue; // only the highest new tier
    await _systemWindow(context, header: tier == 1 ? 'TITLE ACQUIRED' : 'TITLE UPGRADED', lines: [titleLabel(t, tier)], titleId: t.id);
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

/// Home card in the app's own style: an XP ring around your level, your rank, XP left, and the next title.
/// Titles live in Profile.
class PowerStrip extends StatelessWidget {
  const PowerStrip({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: power,
    builder: (context, p, _) {
      if (p == null) return const SizedBox.shrink();
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      // Rank colour that reads on the card: the bright one on dark, the deep one on light (Awakened uses the brand colour).
      final ink = p.rank.index == 0 ? colors.primary : p.rank.colors[theme.brightness == Brightness.dark ? 0 : 1];
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 64,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: p.level.into / p.level.needed),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                          color: ink,
                          backgroundColor: ink.withValues(alpha: 0.12),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'LV',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: colors.onSurfaceVariant, height: 1),
                            ),
                            Text(
                              '${p.level.level}',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ink, height: 1.1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: ink.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          p.rank.title.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: ink),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${p.level.needed - p.level.into} XP',
                              style: TextStyle(color: ink),
                            ),
                            TextSpan(text: ' to Level ${p.level.level + 1}'),
                          ],
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      if (p.next case final next?)
                        Text(
                          'Next title: ${next.title.name} · ${next.progress.done}/${next.progress.total}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                        ),
                    ],
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
