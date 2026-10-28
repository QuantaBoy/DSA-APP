import 'package:flutter/material.dart';

import '../logic/models.dart';
import '../logic/srs.dart';
import 'motion.dart';
import 'widgets.dart';

const _orange = Color(0xFFF97316);
const _red = Color(0xFFEF4444);
const _gold = Color(0xFFFBBF24);
const _fire = LinearGradient(colors: [Color(0xFFFF8A3D), Color(0xFFEF4444)], begin: Alignment.topCenter, end: Alignment.bottomCenter);
const _weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

/// The current week, Monday first, as dates.
List<DateTime> _thisWeek(DateTime today) => [for (var i = 0; i < 7; i++) addDays(today, i - (today.weekday - 1))];

/// Text painted with the fire gradient.
class _FireText extends StatelessWidget {
  const _FireText(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => _fire.createShader(r),
        child: child,
      );
}

/// The flame, gently breathing and floating.
class _LiveFlame extends StatefulWidget {
  const _LiveFlame({this.size = 150});

  final double size;

  @override
  State<_LiveFlame> createState() => _LiveFlameState();
}

class _LiveFlameState extends State<_LiveFlame> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flame = Image.asset('assets/illustrations/flame.png', width: widget.size, height: widget.size);
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return flame;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, -6 * t),
          child: Transform.scale(scale: 1 + 0.05 * t, alignment: Alignment.bottomCenter, child: child),
        );
      },
      child: flame,
    );
  }
}

/// Seven day chips for this week: flames on review days, today ringed.
class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.days, required this.today});

  final Set<DateTime> days;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final week = _thisWeek(today);
    return Row(children: [
      for (final (i, d) in week.indexed)
        Expanded(
          child: Column(children: [
            Text(_weekdays[i],
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: d == today ? _orange : theme.colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 8),
            _PopIn(
              delay: Duration(milliseconds: 120 + 70 * i),
              child: AspectRatio(
                aspectRatio: 0.78,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: days.contains(d) ? _orange.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: d == today ? _orange : (days.contains(d) ? _orange.withValues(alpha: 0.35) : theme.colorScheme.outlineVariant),
                      width: d == today ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: days.contains(d)
                      ? Image.asset('assets/illustrations/flame.png', width: 30, height: 30)
                      : d.isAfter(today)
                          ? null
                          : Icon(Icons.close_rounded, size: 16, color: theme.colorScheme.outline),
                ),
              ),
            ),
          ]),
        ),
    ]);
  }
}

/// Scales its child in with a little bounce after [delay].
class _PopIn extends StatefulWidget {
  const _PopIn({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return widget.child;
    return ScaleTransition(scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut), child: widget.child);
  }
}

/// Streak details: flame and count, this week, the next challenge, record and milestones.
class StreakPage extends StatelessWidget {
  const StreakPage({super.key, required this.stats});

  final Stats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final now = today();
    final days = stats.days.keys.map(dateOnly).toSet();
    final current = streak(days, now);
    final record = longestStreak(days);
    final started = streakStart(days, now);
    final goal = streakMilestones.firstWhere((m) => m > current, orElse: () => streakMilestones.last);
    final previousGoal = streakMilestones.lastWhere((m) => m <= current, orElse: () => 0);
    final reviewedToday = days.contains(now);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text('Streak'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filledTonal(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Warm header that fades into the page.
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + kToolbarHeight + 8, 20, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark ? [const Color(0xFF3A1A0A), colors.surface] : [const Color(0xFFFFE4CC), colors.surface],
              ),
            ),
            child: Column(children: [
              const _LiveFlame(),
              const SizedBox(height: 6),
              _FireText(CountUp(current, style: const TextStyle(fontSize: 76, height: 1, fontWeight: FontWeight.w900, letterSpacing: -2))),
              const SizedBox(height: 4),
              Text(current == 1 ? 'day streak!' : 'days streak!', style: const TextStyle(color: _orange, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                current == 0
                    ? 'Review one problem today to start a streak.'
                    : reviewedToday
                        ? "You've revised today. See you tomorrow!"
                        : 'Review today to keep your streak alive.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
            ]),
          ),
          Rise(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(padding: const EdgeInsets.fromLTRB(10, 16, 10, 16), child: _WeekRow(days: days, today: now)),
            ),
          ),
          const SectionTitle('Streak challenge'),
          Rise(
            index: 1,
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('$goal days challenge', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                    Text('Day ${current.clamp(0, goal)} of $goal', style: theme.textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant)),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    _GoalBadge(previousGoal, reached: true),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Grow(
                        value: goal == previousGoal ? 1 : ((current - previousGoal) / (goal - previousGoal)).clamp(0.0, 1.0),
                        builder: (context, v) => Container(
                          height: 14,
                          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(7)),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: v,
                            child: Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [_gold, _orange]), borderRadius: BorderRadius.circular(7))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _GoalBadge(goal, reached: current >= goal),
                  ]),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Rise(
            index: 2,
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: IntrinsicHeight(
                child: Row(children: [
                  Expanded(child: _Fact(value: started == null ? '—' : prettyDay(started), label: 'Streak started')),
                  VerticalDivider(width: 1, color: colors.outlineVariant),
                  Expanded(child: _Fact(value: '$record ${record == 1 ? 'day' : 'days'}', label: 'Streak record')),
                ]),
              ),
            ),
          ),
          const SectionTitle('Streak milestones'),
          for (final (i, m) in streakMilestones.indexed)
            Rise(index: 3 + i, child: _MilestoneRow(days: m, best: record, current: current)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _GoalBadge extends StatelessWidget {
  const _GoalBadge(this.days, {required this.reached});

  final int days;
  final bool reached;

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: reached ? _orange : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$days',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: reached ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(children: [
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.days, required this.best, required this.current});

  final int days;
  final int best; // record: a milestone stays unlocked even after the streak breaks
  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = best >= days;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Opacity(
            opacity: unlocked ? 1 : 0.9,
            child: Image.asset(unlocked ? 'assets/illustrations/flame.png' : 'assets/illustrations/flame_off.png', width: 44, height: 44),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$days days streak', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              Text(
                unlocked ? 'Unlocked' : '${days - current} ${days - current == 1 ? 'day' : 'days'} to go',
                style: theme.textTheme.bodySmall?.copyWith(color: unlocked ? Accent.green : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ]),
          ),
          Icon(unlocked ? Icons.verified_rounded : Icons.lock_outline_rounded, color: unlocked ? _orange : theme.colorScheme.outline),
        ]),
      ),
    );
  }
}

/// Shown after the first review of the day: the flame bursts in, the count ticks up,
/// this week's days fill in and today's day pops with a tick.
class StreakCelebration extends StatefulWidget {
  const StreakCelebration({super.key, required this.before, required this.reviewDays});

  final int before; // streak before today's review
  final Set<DateTime> reviewDays; // including today

  @override
  State<StreakCelebration> createState() => _StreakCelebrationState();
}

class _StreakCelebrationState extends State<StreakCelebration> {
  bool _ticked = false; // today's chip filled in

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _ticked = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = today();
    final after = widget.before + 1;
    final week = _thisWeek(now);
    final soFar = week.where((d) => !d.isAfter(now));
    final perfect = soFar.every(widget.reviewDays.contains);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Spacer(),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.elasticOut,
                  builder: (context, t, child) => Transform.scale(scale: t, child: child),
                  child: const _LiveFlame(size: 190),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: widget.before.toDouble(), end: after.toDouble()),
                  duration: const Duration(milliseconds: 900),
                  curve: const Interval(0.4, 1, curve: Curves.easeOutBack),
                  builder: (context, v, _) =>
                      _FireText(Text('${v.round()}', style: const TextStyle(fontSize: 96, height: 1, fontWeight: FontWeight.w900, letterSpacing: -3))),
                ),
                const Text('day streak', style: TextStyle(color: _orange, fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 36),
                Row(children: [
                  for (final (i, d) in week.indexed)
                    Expanded(
                      child: Column(children: [
                        Text(_weekdays[i],
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: d == now ? _red : theme.colorScheme.onSurfaceVariant,
                            )),
                        const SizedBox(height: 10),
                        _DayDot(
                          done: d == now ? _ticked : widget.reviewDays.contains(d),
                          delay: Duration(milliseconds: 250 + 90 * i),
                        ),
                      ]),
                    ),
                ]),
                const SizedBox(height: 28),
                Rise(
                  index: 6,
                  child: Text.rich(
                    TextSpan(children: [
                      if (perfect) ...[
                        const TextSpan(text: 'You earned a '),
                        const TextSpan(text: 'Perfect Streak', style: TextStyle(color: _orange, fontWeight: FontWeight.w900)),
                        TextSpan(text: ' for revising ${soFar.length} ${soFar.length == 1 ? 'day' : 'days'} in a row this week!'),
                      ] else
                        TextSpan(text: "You're on a $after day streak. Come back tomorrow to keep it going!"),
                    ]),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                  ),
                ),
                const Spacer(),
                Rise(
                  index: 8,
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: _orange, foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Continue'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round day marker: grey, or orange with a tick once done.
class _DayDot extends StatelessWidget {
  const _DayDot({required this.done, required this.delay});

  final bool done;
  final Duration delay;

  @override
  Widget build(BuildContext context) => _PopIn(
        delay: delay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          curve: Curves.elasticOut,
          width: done ? 44 : 38,
          height: done ? 44 : 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: done ? _fire : null,
            color: done ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
            border: done ? Border.all(color: _gold, width: 3) : null,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: done ? const Icon(Icons.check_rounded, key: ValueKey(1), color: Colors.white, size: 24) : const SizedBox(key: ValueKey(0)),
          ),
        ),
      );
}
