import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/leaderboard.dart';
import '../data/prefs.dart';
import 'motion.dart';
import 'widgets.dart';

const _medals = [Color(0xFFFBBF24), Color(0xFFCBD5E1), Color(0xFFF59E0B)]; // gold, silver, bronze

/// Opt-in leaderboard: a podium for the top three and a ranked list, by streak or problems solved.
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key, required this.uid, required this.name, required this.streak, required this.solved, this.board});

  final String uid;
  final String name; // first name only
  final int streak;
  final int solved;
  final Leaderboard? board; // tests pass one over a fake Firestore

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late final _board = widget.board ?? Leaderboard();
  Ranking _by = Ranking.streak;
  late final Map<Ranking, Stream<List<LeaderboardEntry>>> _streams = {for (final r in Ranking.values) r: _board.top(r)};

  Future<void> _join() async {
    unawaited(HapticFeedback.mediumImpact());
    Prefs.setLeaderboard(true);
    await _board.publish(uid: widget.uid, name: widget.name, streak: widget.streak, solved: widget.solved);
  }

  Future<void> _leave() async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Leave the leaderboard?'),
        content: const Text('Your entry is deleted. You can join again any time.'),
        actions: [
          adaptiveAction(context, 'Cancel', () => Navigator.pop(context, false)),
          adaptiveAction(context, 'Leave', () => Navigator.pop(context, true), destructive: true),
        ],
      ),
    );
    if (ok != true) return;
    Prefs.setLeaderboard(false);
    await _board.leave(widget.uid);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Leaderboard'),
      actions: [
        ValueListenableBuilder(
          valueListenable: Prefs.leaderboard,
          builder: (context, joined, _) => joined ? TextButton(onPressed: _leave, child: const Text('Leave')) : const SizedBox.shrink(),
        ),
      ],
    ),
    body: ValueListenableBuilder(
      valueListenable: Prefs.leaderboard,
      builder: (context, joined, _) => joined ? _ranking(context) : _joinCard(context),
    ),
  );

  Widget _joinCard(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            children: [
              Bob(child: Image.asset('assets/illustrations/trophy.png', width: 150, height: 150)),
              const SizedBox(height: 8),
              Text('Climb the leaderboard', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                'See how your streak and solved count compare with other Memory Stack users.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('What others will see', style: TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Name: ${widget.name}'),
                      Text('Streak: ${widget.streak} days · Solved: ${widget.solved}'),
                      const SizedBox(height: 8),
                      Text(
                        'Never your email, notes or code. Leave any time and your entry is deleted.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                onPressed: _join,
                icon: const Icon(Icons.emoji_events_rounded),
                label: const Text('Join the leaderboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ranking(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SegmentedButton<Ranking>(
          showSelectedIcon: false,
          segments: [for (final r in Ranking.values) ButtonSegment(value: r, label: Text(r.label))],
          selected: {_by},
          onSelectionChanged: (s) => setState(() => _by = s.single),
        ),
      ),
      Expanded(
        child: StreamBuilder<List<LeaderboardEntry>>(
          stream: _streams[_by],
          builder: (context, snap) {
            if (snap.hasError) return const Center(child: Text('Could not load the leaderboard.'));
            final entries = snap.data;
            if (entries == null) return const Center(child: CircularProgressIndicator());
            int value(LeaderboardEntry e) => _by == Ranking.streak ? e.streak : e.solved;
            final unit = _by == Ranking.streak ? 'days' : 'solved';
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (entries.isNotEmpty)
                  Rise(
                    child: _Podium(top: entries.take(3).toList(), value: value, unit: unit, me: widget.uid),
                  ),
                for (final (i, e) in entries.indexed.skip(3))
                  Rise(
                    index: i - 2,
                    child: _Row(rank: i + 1, entry: e, value: value(e), unit: unit, isMe: e.uid == widget.uid),
                  ),
                if (!entries.any((e) => e.uid == widget.uid))
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      "You're not in the top ${Leaderboard.size} yet. Keep your streak going!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top, required this.value, required this.unit, required this.me});

  final List<LeaderboardEntry> top;
  final int Function(LeaderboardEntry) value;
  final String unit;
  final String me;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Visual order: 2nd, 1st, 3rd, with 1st tallest.
    final order = [if (top.length > 1) 1, 0, if (top.length > 2) 2];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final i in order)
            Expanded(
              child: Column(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: _medals[i], size: i == 0 ? 34 : 26),
                  CircleAvatar(
                    radius: i == 0 ? 34 : 26,
                    backgroundColor: _medals[i],
                    child: CircleAvatar(
                      radius: i == 0 ? 30 : 23,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        top[i].name.characters.first.toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: i == 0 ? 24 : 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    top[i].uid == me ? '${top[i].name} (you)' : top[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text('${value(top[i])} $unit', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Container(
                    height: [92.0, 66.0, 48.0][i],
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_medals[i], _medals[i].withValues(alpha: 0.6)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.entry, required this.value, required this.unit, required this.isMe});

  final int rank;
  final LeaderboardEntry entry;
  final int value;
  final String unit;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      color: isMe ? colors.primaryContainer : null,
      child: ListTile(
        leading: SizedBox(
          width: 32,
          child: Text(
            '$rank',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
        title: Text(isMe ? '${entry.name} (you)' : entry.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: Text('$value $unit', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}
