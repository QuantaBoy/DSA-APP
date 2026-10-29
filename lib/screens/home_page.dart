import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/prefs.dart';
import '../data/reminder.dart';
import '../data/sheet.dart';
import '../data/store.dart';
import 'add_problem_page.dart';
import 'library_page.dart';
import 'motion.dart';
import 'profile_page.dart';
import 'sheet_page.dart';
import 'today_page.dart';

/// Signed-in shell: Home, Sheet, Library and Profile. Bottom bar on phones, sidebar on wide screens.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.user});

  final User user;

  @override
  State<HomePage> createState() => _HomePageState();
}

const _tabs = [
  (title: 'Home', icon: Icons.home_outlined, selected: Icons.home_rounded),
  (title: 'Sheet', icon: Icons.menu_book_outlined, selected: Icons.menu_book_rounded),
  (title: 'Library', icon: Icons.layers_outlined, selected: Icons.layers_rounded),
  (title: 'Profile', icon: Icons.person_outline_rounded, selected: Icons.person_rounded),
];

const _home = 0, _sheet = 1, _library = 2, _profile = 3;

class _HomePageState extends State<HomePage> {
  late final store = Store(widget.user.uid);
  late final Stream<UserData> _data = store.data();
  int _tab = _home;

  @override
  void initState() {
    super.initState();
    // Neither may ever break the app: a missing reminder or a failed upgrade is retried next launch.
    unawaited(scheduleDailyReminder(Prefs.reminderMinutes.value).catchError((Object _) {}));
    unawaited(store.upgrade().catchError((Object _) {}));
  }

  void _go(int tab) {
    if (tab == _tab) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<UserData>(
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
          _home => TodayPage(
            store: store,
            problems: data.problems,
            stats: data.stats,
            onOpenSheet: () => _go(_sheet),
            onSeeAll: () => _go(_library),
          ),
          _sheet => SheetPage(store: store, problems: data.problems),
          _library => LibraryPage(store: store, problems: data.problems),
          _ => ProfilePage(user: widget.user, store: store, problems: data.problems, stats: data.stats),
        };
      }
      final content = AnimatedSwitcher(
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
      final Widget title = _tab == _sheet
          ? ValueListenableBuilder(
              valueListenable: Prefs.sheetId,
              builder: (context, id, _) => Text(sheets.firstWhere((s) => s.id == id, orElse: () => sheets.first).name),
            )
          : Text(_tab == _home ? 'Hi, ${firstName(widget.user)} 👋' : _tabs[_tab].title);
      final avatar = Padding(
        padding: const EdgeInsets.only(right: 12),
        child: IconButton(
          tooltip: 'Profile',
          onPressed: () => _go(_profile),
          icon: CircleAvatar(
            radius: 17,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(firstName(widget.user).characters.first.toUpperCase()),
          ),
        ),
      );
      final fab = _tab == _library
          ? FloatingActionButton.extended(
              onPressed: () => unawaited(Navigator.push(context, MaterialPageRoute<void>(builder: (_) => AddProblemPage(store: store)))),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add problem'),
            )
          : null;

      if (MediaQuery.sizeOf(context).width >= 840) {
        // Tablet / PC: full-height sidebar, page header, content centred.
        return Scaffold(
          body: Row(
            children: [
              _Sidebar(user: widget.user, tab: _tab, onTab: _go),
              Expanded(
                child: Column(
                  children: [
                    AppBar(title: title, automaticallyImplyLeading: false, actions: [if (_tab != _profile) avatar]),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: content),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: fab,
        );
      }
      return Scaffold(
        appBar: AppBar(title: title, actions: [if (_tab != _profile) avatar]),
        body: content,
        floatingActionButton: fab,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _go,
          destinations: [for (final t in _tabs) NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selected), label: t.title)],
        ),
      );
    },
  );
}

/// Desktop sidebar: logo, the four sections, dark mode switch and who is signed in.
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.user, required this.tab, required this.onTab});

  final User user;
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border(right: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5))),
      ),
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/illustrations/logo.png', width: 36, height: 36),
              ),
              const SizedBox(width: 10),
              Text('Memory Stack', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 28),
          for (final (i, t) in _tabs.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: i == tab
                    ? colors.primaryContainer.withValues(alpha: theme.brightness == Brightness.dark ? 1 : 0.6)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onTab(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(i == tab ? t.selected : t.icon, size: 22, color: i == tab ? colors.primary : colors.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Text(
                          t.title,
                          style: TextStyle(
                            fontWeight: i == tab ? FontWeight.w700 : FontWeight.w500,
                            color: i == tab ? colors.onSurface : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          ValueListenableBuilder(
            valueListenable: Prefs.themeMode,
            builder: (context, mode, _) {
              final isDark =
                  mode == ThemeMode.dark || (mode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Icon(Icons.dark_mode_outlined, size: 20, color: colors.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Dark mode',
                        style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Switch.adaptive(value: isDark, onChanged: (v) => Prefs.setThemeMode(v ? ThemeMode.dark : ThemeMode.light)),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 24),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTab(_profile),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  child: Text(firstName(user).characters.first.toUpperCase()),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstName(user),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.email ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
