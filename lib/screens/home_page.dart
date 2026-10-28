import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/reminder.dart';
import '../data/store.dart';
import '../main.dart' show themeMode, setThemeMode;

import 'add_problem_page.dart';
import 'sheet_page.dart';
import 'stack_page.dart';
import 'stats_page.dart';
import 'motion.dart';
import 'today_page.dart';

/// Shown in the account menu. Keep in step with `version:` in pubspec.yaml.
const appVersion = '1.3.0';

/// Signed-in shell: bottom tabs for today's reviews, the A2Z sheet, your stack and stats.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.user});

  final User user;

  @override
  State<HomePage> createState() => _HomePageState();
}

const _tabs = [
  (title: 'Today', icon: Icons.today_outlined, selected: Icons.today),
  (title: 'A2Z Sheet', icon: Icons.menu_book_outlined, selected: Icons.menu_book),
  (title: 'My stack', icon: Icons.layers_outlined, selected: Icons.layers),
  (title: 'Stats', icon: Icons.insights_outlined, selected: Icons.insights),
];

class _HomePageState extends State<HomePage> {
  late final store = Store(widget.user.uid);
  late final Stream<UserData> _data = store.data();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    scheduleDailyReminder().catchError((_) {}); // a missing reminder must never break the app
    store.upgrade().catchError((_) {}); // moves old-layout data once; retried next launch if it fails
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserData>(
      stream: _data,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final Widget body;
        if (snapshot.hasError) {
          body = Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Could not load your data.\n${snapshot.error}', textAlign: TextAlign.center),
            ),
          );
        } else if (data == null) {
          body = const Skeleton();
        } else {
          body = switch (_tab) {
            0 => TodayPage(store: store, problems: data.problems, stats: data.stats, onOpenSheet: () => setState(() => _tab = 1)),
            1 => SheetPage(store: store, problems: data.problems),
            2 => StackPage(store: store, problems: data.problems),
            _ => StatsPage(problems: data.problems, stats: data.stats),
          };
        }
        final wide = MediaQuery.sizeOf(context).width >= 840; // tablet or PC: side rail instead of bottom bar
        final switcher = AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(data == null ? -1 : _tab), child: body),
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(_tab == 0 ? 'Hi, ${_firstName(widget.user)}' : _tabs[_tab].title),
            actions: [_AccountMenu(user: widget.user, store: store)],
          ),
          body: !wide
              ? switcher
              : Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _tab,
                      onDestinationSelected: (i) => setState(() => _tab = i),
                      labelType: NavigationRailLabelType.all,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                      indicatorShape: const StadiumBorder(),
                      groupAlignment: -0.85,
                      destinations: [
                        for (final t in _tabs)
                          NavigationRailDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selected), label: Text(t.title)),
                      ],
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: switcher),
                      ),
                    ),
                  ],
                ),
          floatingActionButton: _tab == 2
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddProblemPage(store: store))),
                  icon: const Icon(Icons.add),
                  label: const Text('Add problem'),
                )
              : null,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  destinations: [
                    for (final t in _tabs) NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selected), label: t.title),
                  ],
                ),
        );
      },
    );
  }
}

String _firstName(User user) {
  final name = user.displayName?.trim();
  if (name != null && name.isNotEmpty) return name.split(' ').first;
  return user.email?.split('@').first ?? 'there';
}

/// Avatar button with the signed-in email, sign out, and delete account.
class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.user, required this.store});

  final User user;
  final Store store;

  Future<void> _chooseTheme(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Appearance'),
      content: ValueListenableBuilder(
        valueListenable: themeMode,
        builder: (context, mode, _) => SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
            ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
            ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android_outlined), label: Text('System')),
          ],
          selected: {mode},
          onSelectionChanged: (m) => setThemeMode(m.single),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
    ),
  );

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Delete your account?'),
        content: const Text(
          'All your problems, notes and review history are deleted for good, then you are signed out. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
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
      await store.deleteEverything();
      await user.delete();
    } on FirebaseException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not delete the account (${e.code}). Sign in again and retry.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial = _firstName(user).characters.first.toUpperCase();
    return PopupMenuButton<String>(
      tooltip: 'Account',
      onSelected: (v) => switch (v) {
        'theme' => _chooseTheme(context),
        'out' => FirebaseAuth.instance.signOut(),
        _ => _deleteAccount(context),
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Text('${user.email ?? ''}\nMemory Stack v$appVersion', style: TextStyle(color: colors.onSurfaceVariant)),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'theme',
          child: ListTile(leading: Icon(Icons.palette_outlined), title: Text('Appearance'), contentPadding: EdgeInsets.zero),
        ),
        const PopupMenuItem(
          value: 'out',
          child: ListTile(leading: Icon(Icons.logout), title: Text('Sign out'), contentPadding: EdgeInsets.zero),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: colors.error),
            title: Text('Delete account', style: TextStyle(color: colors.error)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: CircleAvatar(
          radius: 17,
          backgroundColor: colors.primaryContainer,
          child: Text(initial, style: TextStyle(color: colors.onPrimaryContainer)),
        ),
      ),
    );
  }
}
