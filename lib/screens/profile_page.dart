import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/leaderboard.dart';
import '../data/leetcode.dart';
import '../data/prefs.dart';
import '../data/reminder.dart';
import '../data/store.dart';
import '../logic/ascension.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'ascension_view.dart';
import 'leaderboard_page.dart';
import 'motion.dart';
import 'open_link.dart';
import 'roadmap_page.dart';
import 'stats_page.dart';
import 'streak_page.dart';
import 'widgets.dart';

/// Shown in Profile → About. Keep in step with `version:` in pubspec.yaml.
const appVersion = '1.28.0';

/// First name for greetings, falling back to the email name.
String firstName(User user) {
  final name = user.displayName?.trim();
  if (name != null && name.isNotEmpty) return name.split(' ').first;
  return user.email?.split('@').first ?? 'there';
}

/// You: streak and progress at a glance, the activity heatmap, detailed stats, and every setting.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.user, required this.store, required this.problems, required this.stats});

  final User user;
  final Store store;
  final List<Problem> problems;
  final Stats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = today();
    final days = streakWithFreezes(activeDays(problems, stats), now);
    void open(Widget page) => unawaited(Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page)));

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      children: [
        Rise(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  child: Text(
                    firstName(user).characters.first.toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : firstName(user),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(user.email ?? '', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Rise(
          index: 1,
          child: StatRow(
            children: [
              StatTile(
                icon: Icons.local_fire_department_rounded,
                value: '$days',
                label: 'Day streak',
                color: Accent.orange,
                onTap: () => open(StreakPage(days: activeDays(problems, stats))),
              ),
              StatTile(icon: Icons.check_circle_rounded, value: '${problems.length}', label: 'Solved', color: Accent.green),
              StatTile(
                icon: Icons.psychology_rounded,
                value: stats.recall == null ? '–' : '${(stats.recall! * 100).round()}%',
                label: 'Recall',
                color: Accent.violet,
              ),
            ],
          ),
        ),
        const SectionTitle('Activity'),
        Rise(
          index: 2,
          child: ActivityHeatmap(
            stats: Stats(days: activityPerDay(problems, stats)),
            today: now,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: OutlinedButton.icon(
            onPressed: () => open(
              Scaffold(
                appBar: AppBar(title: const Text('Stats')),
                body: StatsPage(problems: problems, stats: stats),
              ),
            ),
            icon: const Icon(Icons.insights_rounded),
            label: const Text('Detailed stats'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: OutlinedButton.icon(
            onPressed: () => open(LeaderboardPage(uid: user.uid, name: firstName(user), streak: days, solved: problems.length)),
            icon: const Icon(Icons.leaderboard_rounded),
            label: const Text('Leaderboard'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ),
        const SectionTitle('Titles'),
        _SettingsCard(
          children: [
            ValueListenableBuilder(
              valueListenable: power,
              builder: (context, p, _) => ListTile(
                leading: const Icon(Icons.route_rounded),
                title: const Text('Titles roadmap'),
                subtitle: Text('${p?.titles.length ?? 0} of ${titles.length} unlocked'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => open(const RoadmapPage()),
              ),
            ),
          ],
        ),
        const SectionTitle('Goal & reminder'),
        _SettingsCard(
          children: [
            ValueListenableBuilder(
              valueListenable: Prefs.dailyNewGoal,
              builder: (context, goal, _) => ListTile(
                leading: const Icon(Icons.flag_rounded),
                title: const Text('New problems a day'),
                subtitle: const Text('Plus all reviews that are due'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(onPressed: goal > 0 ? () => Prefs.setDailyNewGoal(goal - 1) : null, icon: const Icon(Icons.remove_rounded)),
                    Text('$goal', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    IconButton(onPressed: goal < 10 ? () => Prefs.setDailyNewGoal(goal + 1) : null, icon: const Icon(Icons.add_rounded)),
                  ],
                ),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: Prefs.reminderMinutes,
              builder: (context, minutes, _) => ListTile(
                leading: const Icon(Icons.notifications_active_rounded),
                title: const Text('Daily reminder'),
                subtitle: Text(
                  minutes == null
                      ? 'Off. Switch on and pick your time'
                      : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context),
                ),
                onTap: minutes == null ? null : () => _pickReminder(context, minutes),
                trailing: Switch.adaptive(
                  value: minutes != null,
                  onChanged: (on) => on ? _pickReminder(context, 20 * 60) : _setReminder(null),
                ),
              ),
            ),
          ],
        ),
        const SectionTitle('LeetCode'),
        _SettingsCard(children: [_LeetCodeTile(store: store)]),
        const SectionTitle('App'),
        _SettingsCard(
          children: [
            ValueListenableBuilder(
              valueListenable: Prefs.themeMode,
              builder: (context, mode, _) => ListTile(
                leading: const Icon(Icons.palette_rounded),
                title: const Text('Appearance'),
                trailing: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded)),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded)),
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_iphone_rounded)),
                  ],
                  selected: {mode},
                  onSelectionChanged: (m) => Prefs.setThemeMode(m.single),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.tips_and_updates_rounded),
              title: const Text('Replay tips'),
              subtitle: const Text('Show the screen-by-screen walkthrough again'),
              onTap: () {
                Prefs.resetTips();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tips will show again on each screen.')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_rounded),
              title: const Text('Privacy policy'),
              onTap: () => openLink(context, 'https://memory-stack-e6990.web.app/privacy.html'),
            ),
            const ListTile(leading: Icon(Icons.info_rounded), title: Text('Version'), trailing: Text(appVersion)),
          ],
        ),
        const SectionTitle('Account'),
        _SettingsCard(
          children: [
            ListTile(leading: const Icon(Icons.logout_rounded), title: const Text('Sign out'), onTap: () => _confirmSignOut(context)),
            ListTile(
              leading: const Icon(Icons.restart_alt_rounded),
              title: const Text('Reset progress'),
              subtitle: const Text('Start fresh, keep the account'),
              onTap: () => _resetProgress(context),
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: colors.error),
              title: Text('Delete account', style: TextStyle(color: colors.error)),
              onTap: () => _deleteAccount(context),
            ),
          ],
        ),
      ],
    );
  }

  void _setReminder(int? minutes) {
    Prefs.setReminder(minutes);
    unawaited(scheduleDailyReminder(minutes).catchError((Object _) {}));
  }

  Future<void> _pickReminder(BuildContext context, int minutes) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked != null) _setReminder(picked.hour * 60 + picked.minute);
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Sign out?'),
        content: const Text('Your progress stays saved in your account.'),
        actions: [
          adaptiveAction(context, 'Cancel', () => Navigator.pop(context, false)),
          adaptiveAction(context, 'Sign out', () => Navigator.pop(context, true), primary: true),
        ],
      ),
    );
    if (ok == true) await FirebaseAuth.instance.signOut();
  }

  Future<void> _resetProgress(BuildContext context) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Reset all progress?'),
        content: const Text(
          'Your streak, solved problems, solution cards and aptitude questions are deleted for good. Your account stays. This cannot be undone.',
        ),
        actions: [
          adaptiveAction(context, 'Cancel', () => Navigator.pop(context, false)),
          adaptiveAction(context, 'Reset', () => Navigator.pop(context, true), destructive: true),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await store.deleteEverything();
      messenger.showSnackBar(const SnackBar(content: Text('Progress reset. Fresh start!')));
    } on FirebaseException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not reset (${e.code}). Check your internet and retry.')));
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Delete your account?'),
        content: const Text(
          'All your problems, solution cards and review history are deleted for good, then you are signed out. This cannot be undone.',
        ),
        actions: [
          adaptiveAction(context, 'Cancel', () => Navigator.pop(context, false)),
          adaptiveAction(context, 'Delete', () => Navigator.pop(context, true), destructive: true),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    // Firebase only deletes accounts that signed in recently; check first so data is never deleted without the account.
    final signedIn = user.metadata.lastSignInTime;
    if (signedIn == null || DateTime.now().difference(signedIn) > const Duration(minutes: 4)) {
      messenger.showSnackBar(const SnackBar(content: Text('For your security, sign out, sign in again, then delete the account.')));
      return;
    }
    try {
      if (Prefs.leaderboard.value) {
        await Leaderboard().leave(user.uid);
        Prefs.setLeaderboard(false);
      }
      await store.deleteEverything();
      await user.delete();
    } on FirebaseException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not delete the account (${e.code}). Sign in again and retry.')));
    }
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (final (i, c) in children.indexed) ...[if (i > 0) const Divider(height: 1, indent: 56), c],
      ],
    ),
  );
}

/// The last 18 weeks as a grid of days, darker on days with more reviews (like a contribution graph).
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({super.key, required this.stats, required this.today, this.weeks = 18});

  final Stats stats;
  final DateTime today;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final start = addDays(today, -(weeks * 7 - 1) - (today.weekday - 1)); // a Monday, so rows are weekdays
    final most = stats.days.values.fold(1, (a, b) => a > b ? a : b);
    final active = stats.days.entries.where((e) => !e.key.isBefore(start) && e.value > 0).length;
    Color shade(int n) => n == 0
        ? colors.surfaceContainerHighest.withValues(alpha: 0.7)
        : Color.lerp(colors.primary.withValues(alpha: 0.3), colors.primary, (n / most).clamp(0.0, 1.0))!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$active active days in the last $weeks weeks',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, box) {
                final cell = ((box.maxWidth - (weeks - 1) * 3) / weeks).clamp(6.0, 16.0);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var w = 0; w < weeks; w++)
                      Padding(
                        padding: EdgeInsets.only(left: w == 0 ? 0 : 3),
                        child: Column(
                          children: [
                            for (var d = 0; d < 7; d++)
                              Builder(
                                builder: (context) {
                                  final day = addDays(start, w * 7 + d);
                                  final future = day.isAfter(today);
                                  return Container(
                                    width: cell,
                                    height: cell,
                                    margin: const EdgeInsets.only(bottom: 3),
                                    decoration: BoxDecoration(
                                      color: future ? Colors.transparent : shade(stats.reviewsOn(day)),
                                      borderRadius: BorderRadius.circular(3),
                                      border: day == today ? Border.all(color: colors.primary, width: 1.5) : null,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Connect a LeetCode username; problems accepted there are added to your stack.
class _LeetCodeTile extends StatefulWidget {
  const _LeetCodeTile({required this.store});

  final Store store;

  @override
  State<_LeetCodeTile> createState() => _LeetCodeTileState();
}

class _LeetCodeTileState extends State<_LeetCodeTile> {
  bool _busy = false;
  String? _status;

  Future<void> _sync(String username) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    String status;
    try {
      final added = await syncLeetCode(username: username, store: widget.store, sheetId: Prefs.sheetId.value);
      status = switch (added) {
        0 => 'Up to date',
        1 => '1 new problem added',
        _ => '$added new problems added',
      };
    } on LeetCodeException catch (e) {
      status = e.message;
    } on Exception {
      status = 'You seem to be offline. Try again later.';
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _status = status;
      });
    }
  }

  Future<void> _edit(String? current) async {
    final field = TextEditingController(text: current);
    final result = await showAdaptiveDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('LeetCode username'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Problems you solve on LeetCode are added to your stack, dated the day you solved them.'),
            const SizedBox(height: 12),
            TextField(
              controller: field,
              autofocus: true,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Username', hintText: 'e.g. neal_wu'),
              onSubmitted: (v) => Navigator.pop(context, v.trim()),
            ),
          ],
        ),
        actions: [
          if (current != null) TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Disconnect')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, field.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    field.dispose();
    if (result == null || !mounted) return;
    if (result.isEmpty) {
      Prefs.setLeetcodeUser(null);
      setState(() => _status = null);
    } else if (!isLeetCodeUsername(result)) {
      setState(() => _status = 'That does not look like a LeetCode username.');
    } else {
      Prefs.setLeetcodeUser(result);
      await _sync(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const ListTile(
        leading: Icon(Icons.sync_rounded),
        title: Text('Import from LeetCode'),
        subtitle: Text('Works in the phone app'),
        enabled: false,
      );
    }
    return ValueListenableBuilder(
      valueListenable: Prefs.leetcodeUser,
      builder: (context, user, _) => ListTile(
        leading: const Icon(Icons.sync_rounded),
        title: Text(user == null ? 'Import from LeetCode' : 'LeetCode: $user'),
        subtitle: Text(_status ?? (user == null ? 'Add your username to import solved problems' : 'Syncs each time you open the app')),
        onTap: _busy ? null : () => _edit(user),
        trailing: user == null
            ? const Icon(Icons.chevron_right_rounded)
            : _busy
            ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
            : IconButton(tooltip: 'Sync now', icon: const Icon(Icons.refresh_rounded), onPressed: () => _sync(user)),
      ),
    );
  }
}
