import 'package:flutter/material.dart';

import '../data/prefs.dart';
import '../logic/ascension.dart';
import '../main.dart';
import 'ascension_view.dart';

const _grey = ColorFilter.matrix([
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

const _gold = Color(0xFFD4A017);

/// The titles as a path in A2Z order: cleared ones in colour, the one you are on now highlighted with
/// its progress, the rest locked. Tap Equip on a cleared title to wear it.
class RoadmapPage extends StatelessWidget {
  const RoadmapPage({super.key, this.initialTab = 0});

  final int initialTab; // 0 ranks, 1 titles

  @override
  Widget build(BuildContext context) => Theme(
    data: appTheme(Brightness.dark), // dark like the art, so the badges and banners glow
    child: DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ascension'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ranks'),
              Tab(text: 'Titles'),
            ],
          ),
        ),
        body: const TabBarView(children: [_Ranks(), _Titles()]),
      ),
    ),
  );
}

/// The seven rank banners, lowest first: ranks behind you lit, yours glowing, the rest in shadow.
class _Ranks extends StatelessWidget {
  const _Ranks();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: power,
    builder: (context, p, _) {
      final mine = p?.rank ?? Rank.awakened;
      var total = 0;
      final from = <int>[];
      for (var l = 1; l <= Rank.values.last.fromLevel; l++) {
        if (Rank.values.any((r) => r.fromLevel == l)) from.add(total);
        total += xpToNext(l);
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          for (final r in Rank.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Stack(
                children: [
                  Opacity(
                    opacity: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: r == mine ? Border.all(color: r.colors.first, width: 3) : null,
                        boxShadow: r == mine ? [BoxShadow(color: r.colors.first.withValues(alpha: 0.6), blurRadius: 16)] : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: r.index <= mine.index
                            ? Image.asset('assets/art/banner_${r.index}.webp')
                            : ColorFiltered(
                                colorFilter: const ColorFilter.mode(Color(0x99000000), BlendMode.srcATop), // in shadow until reached
                                child: ColorFiltered(colorFilter: _grey, child: Image.asset('assets/art/banner_${r.index}.webp')),
                              ),
                      ),
                    ),
                  ),
                  if (r == mine)
                    Positioned(
                      right: 8,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: r.colors.first, borderRadius: BorderRadius.circular(6)),
                        child: const Text(
                          'YOU ARE HERE',
                          style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// Every title in A2Z order as a path of badges.
class _Titles extends StatelessWidget {
  const _Titles();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([power, Prefs.equippedTitle]),
    builder: (context, _) {
      final p = power.value;
      final earned = p?.titles ?? const <String>{};
      final progress = p?.progress ?? const <String, Progress>{};
      final current = titles.where((t) => !earned.contains(t.id)).firstOrNull;
      final colors = Theme.of(context).colorScheme;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CLEAR A TOPIC, CLAIM ITS TITLE',
                  style: TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: colors.onSurfaceVariant),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${earned.length} / ${titles.length}',
                  style: TextStyle(fontWeight: FontWeight.w900, color: colors.onPrimaryContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (i, t) in titles.indexed)
            _Stop(
              title: t,
              state: earned.contains(t.id)
                  ? _State.cleared
                  : t == current
                  ? _State.current
                  : _State.locked,
              progress: progress[t.id] ?? (done: 0, total: 0),
              worn: Prefs.equippedTitle.value == t.id,
              last: i == titles.length - 1,
            ),
        ],
      );
    },
  );
}

enum _State { cleared, current, locked }

class _Stop extends StatelessWidget {
  const _Stop({required this.title, required this.state, required this.progress, required this.worn, required this.last});

  final HunterTitle title;
  final _State state;
  final Progress progress;
  final bool worn;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final big = state == _State.current;
    final tile = big ? 96.0 : 76.0;
    final share = progress.total == 0 ? 0.0 : progress.done / progress.total;
    final badge = Image.asset('assets/art/badge_${title.id}.webp', fit: BoxFit.contain);
    final Widget box = switch (state) {
      _State.cleared => badge,
      // The one you are on: the badge half-lit inside a ring that fills as you solve.
      _State.current => Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: share,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              color: const Color(0xFF8B5CF6),
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Opacity(opacity: 0.55 + 0.45 * share, child: badge),
          ),
        ],
      ),
      // Locked: the badge in grey shadow with a lock on it.
      _State.locked => Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.35,
            child: ColorFiltered(colorFilter: _grey, child: badge),
          ),
          Icon(Icons.lock_rounded, color: colors.outline, size: 26),
        ],
      ),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 104,
            child: Column(
              children: [
                SizedBox.square(dimension: tile, child: box),
                if (!last)
                  Expanded(
                    child: CustomPaint(painter: _Dots(colors.outline), child: const SizedBox(width: 4, height: 28)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: tile / 2 - 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state == _State.locked ? 'LOCKED' : title.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: big ? 18 : 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: state == _State.locked ? colors.outline : colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(switch (state) {
                    _State.cleared => '${title.topic} cleared',
                    _State.current => '${title.topic} · ${progress.done} / ${progress.total} solved',
                    _State.locked => title.topic,
                  }, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
                  if (state == _State.cleared)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: worn
                          ? const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'WORN',
                                style: TextStyle(color: _gold, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                              ),
                            )
                          : TextButton(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                              onPressed: () => Prefs.equipTitle(title.id),
                              child: const Text('Equip title'),
                            ),
                    ),
                  if (state == _State.current)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${progress.total - progress.done} more to claim it',
                        style: const TextStyle(color: Color(0xFF6C4EF5), fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dotted line joining the stops.
class _Dots extends CustomPainter {
  _Dots(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.6);
    for (var y = 6.0; y < size.height - 4; y += 9) {
      canvas.drawCircle(Offset(size.width / 2, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(_Dots old) => old.color != color;
}
