import 'package:flutter/material.dart';

import '../data/prefs.dart';
import '../logic/ascension.dart';
import 'ascension_view.dart';

const _icons = <String, IconData>{
  'patterns': Icons.grid_view_rounded,
  'sorting': Icons.sort_rounded,
  'arrays': Icons.view_week_rounded,
  'hashing': Icons.tag_rounded,
  'bsearch': Icons.manage_search_rounded,
  'recursion': Icons.all_inclusive_rounded,
  'linked': Icons.link_rounded,
  'bits': Icons.memory_rounded,
  'greedy': Icons.local_dining_rounded,
  'window': Icons.width_normal_rounded,
  'stack': Icons.layers_rounded,
  'trees': Icons.account_tree_rounded,
  'bst': Icons.park_rounded,
  'heaps': Icons.filter_list_rounded,
  'graphs': Icons.hub_rounded,
  'dp': Icons.psychology_rounded,
  'tries': Icons.spellcheck_rounded,
  'strings': Icons.text_fields_rounded,
  'a2z': Icons.workspace_premium_rounded,
};

const _palette = [Color(0xFFFF6B6B), Color(0xFFF59E0B), Color(0xFF22C55E), Color(0xFF06B6D4), Color(0xFF6C4EF5), Color(0xFFEC4899)];

const _gold = Color(0xFFD4A017);

/// The titles as a path in A2Z order: cleared ones in colour, the one you are on now highlighted with
/// its progress, the rest locked. Tap Equip on a cleared title to wear it.
class RoadmapPage extends StatelessWidget {
  const RoadmapPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Titles roadmap')),
    body: ListenableBuilder(
      listenable: Listenable.merge([power, Prefs.equippedTitle]),
      builder: (context, _) {
        final p = power.value;
        final earned = p?.titles ?? const <String>{};
        final progress = p?.progress ?? const <String, Progress>{};
        final current = titles.where((t) => !earned.contains(t.id)).firstOrNull;
        final colors = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
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
                color: _palette[i % _palette.length],
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
    ),
  );
}

enum _State { cleared, current, locked }

class _Stop extends StatelessWidget {
  const _Stop({
    required this.title,
    required this.color,
    required this.state,
    required this.progress,
    required this.worn,
    required this.last,
  });

  final HunterTitle title;
  final Color color;
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
    final Widget box = switch (state) {
      _State.cleared => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.black, 0.25)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Stack(
          children: [
            Center(child: Icon(_icons[title.id], color: Colors.white, size: 36)),
            const Positioned(right: 6, top: 6, child: Icon(Icons.verified_rounded, color: Colors.white, size: 18)),
          ],
        ),
      ),
      _State.current => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF8B7CFF), Color(0xFF6C4EF5)]),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: const Color(0xFF6C4EF5).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: 70,
              child: CircularProgressIndicator(
                value: share,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
            Icon(_icons[title.id], color: Colors.white, size: 34),
          ],
        ),
      ),
      _State.locked => Container(
        decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(22)),
        child: Icon(Icons.lock_rounded, color: colors.outline, size: 28),
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
                    title.name.toUpperCase(),
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
