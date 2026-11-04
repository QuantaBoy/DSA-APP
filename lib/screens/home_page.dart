import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/home_widget.dart';
import '../data/leaderboard.dart';
import '../data/leetcode.dart';
import '../data/prefs.dart';
import '../data/reminder.dart';
import '../data/sheet.dart';
import '../data/store.dart';
import '../logic/ascension.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'add_problem_page.dart';
import 'aptitude_page.dart';
import 'ascension_view.dart';
import 'library_page.dart';
import 'motion.dart';
import 'profile_page.dart';
import 'sheet_page.dart';
import 'today_page.dart';

/// Signed in but away 13+ days on this device: sign out, so a lost or shared phone does not stay logged in.
/// Runs at start and whenever the app comes back to the front; otherwise records that you were here.
Future<void> signOutIfAway() async {
  final away = Prefs.lastActive;
  if (FirebaseAuth.instance.currentUser != null && away != null && DateTime.now().difference(away) >= const Duration(days: 13)) {
    await FirebaseAuth.instance.signOut();
  }
  Prefs.markActive(DateTime.now());
}

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
  late final StreamSubscription<UserData> _widgetFeed;
  late final _life = AppLifecycleListener(onResume: () => unawaited(signOutIfAway()));
  int _tab = _home;

  @override
  void initState() {
    super.initState();
    _life; // start listening for the app coming back
    // Neither may ever break the app: a missing reminder or a failed upgrade is retried next launch.
    unawaited(scheduleDailyReminder(Prefs.reminderMinutes.value).catchError((Object _) {}));
    unawaited(store.upgrade().catchError((Object _) {}));
    // Keep the home screen widget, your level and (if joined) the leaderboard entry current.
    _widgetFeed = store.data().listen((d) {
      _last = d;
      final now = today();
      unawaited(
        updateHomeWidget(
          due: d.problems.where((p) => p.isDue(now)).length,
          streak: streakWithFreezes(activeDays(d.problems, d.stats), now),
        ),
      );
      unawaited(_updatePower());
      final active = activeDays(d.problems, d.stats);
      unawaited(scheduleStreakSaver(streak: streakWithFreezes(active, now), activeToday: active.contains(now)).catchError((Object _) {}));
      _syncLeetCode();
    }, onError: (Object _) {});
    _aptFeed = store.aptCards().listen((c) {
      _apt = c;
      unawaited(_updatePower());
    }, onError: (Object _) {});
    Prefs.equippedTitle.addListener(_publishLeaderboard);
  }

  UserData? _last;
  List<AptCard> _apt = const [];
  late final StreamSubscription<List<AptCard>> _aptFeed;
  late final Future<Sheet?> _a2z = loadSheet('a2z').then<Sheet?>((s) => s, onError: (Object _) => null);
  bool _celebrating = false;

  Future<void> _updatePower() async {
    final d = _last;
    if (d == null) return;
    final aptCorrect = _apt.fold(0, (a, c) => a + c.remembered);
    final deeds = (
      problems: d.problems,
      stats: d.stats,
      aptCorrect: aptCorrect,
      aptWrong: _apt.fold(0, (a, c) => a + c.reviews) - aptCorrect,
    );
    final xp = totalXp(deeds);
    final level = levelFor(xp);
    final a2z = await _a2z;
    final now = (
      xp: xp,
      level: level,
      rank: Rank.of(level.level),
      titles: earnedTitles(deeds, a2z),
      next: nextTitle(deeds, a2z),
      progress: {for (final t in titles) t.id: t.progress(deeds, a2z)},
    );
    power.value = now;
    _publishLeaderboard();
    // Celebrate what is new since the last look. Seen never goes down, so a slow first load
    // (or a reset) does not replay old level-ups.
    final seenLevel = max(Prefs.seenLevel, 1);
    final fresh = now.level.level > seenLevel || !Prefs.seenTitles.containsAll(now.titles);
    if (!fresh || _celebrating || !mounted) return;
    _celebrating = true;
    final before = (
      xp: 0,
      level: (level: seenLevel, into: 0, needed: 0),
      rank: Rank.of(seenLevel),
      titles: Prefs.seenTitles,
      next: null,
      progress: const <String, Progress>{},
    );
    Prefs.markSeen(max(seenLevel, now.level.level), {...Prefs.seenTitles, ...now.titles});
    await celebrate(context, before, now);
    _celebrating = false;
  }

  (int, int, int, String?)? _published; // last values sent to the leaderboard, so unchanged ones cost no write

  void _publishLeaderboard() {
    final d = _last, p = power.value;
    if (d == null || p == null || !Prefs.leaderboard.value) return;
    final streak = streakWithFreezes(activeDays(d.problems, d.stats), today());
    final title = wornLabel(Prefs.equippedTitle.value, power.value?.titles ?? const {});
    final values = (streak, d.problems.length, p.level.level, title);
    if (_published == values) return;
    _published = values;
    unawaited(
      Leaderboard()
          .publish(
            uid: widget.user.uid,
            name: firstName(widget.user),
            streak: streak,
            solved: d.problems.length,
            level: p.level.level,
            title: title,
          )
          .catchError((Object _) {}),
    );
  }

  bool _leetCodeSynced = false; // once per app start, on the first data

  void _syncLeetCode() {
    final username = Prefs.leetcodeUser.value;
    if (_leetCodeSynced || username == null || kIsWeb) return; // LeetCode blocks requests from web pages
    _leetCodeSynced = true;
    unawaited(
      syncLeetCode(username: username, store: store, sheetId: Prefs.sheetId.value).then((added) {
        if (added > 0 && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Imported $added new LeetCode ${added == 1 ? 'problem' : 'problems'} into your stack.')));
        }
      }, onError: (Object _) {}), // offline or LeetCode down: try again next start
    );
  }

  @override
  void dispose() {
    unawaited(_widgetFeed.cancel());
    _life.dispose();
    unawaited(_aptFeed.cancel());
    Prefs.equippedTitle.removeListener(_publishLeaderboard);
    super.dispose();
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
          _library => LibraryPage(store: store, problems: data.problems, gateCovered: data.stats.gateCovered),
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
              _Sidebar(user: widget.user, tab: _tab, onTab: _go, onScan: () => showScanSheet(context, store)),
              Expanded(
                child: Column(
                  children: [
                    AppBar(
                      title: title,
                      automaticallyImplyLeading: false,
                      actions: [
                        if (_tab == _home)
                          const Padding(padding: EdgeInsets.only(right: 12), child: TitlePill())
                        else if (_tab != _profile)
                          avatar,
                      ],
                    ),
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
        appBar: AppBar(
          title: title,
          actions: [
            if (_tab == _home) const Padding(padding: EdgeInsets.only(right: 12), child: TitlePill()) else if (_tab != _profile) avatar,
          ],
        ),
        body: content,
        floatingActionButton: fab,
        bottomNavigationBar: _BottomBar(tab: _tab, onTab: _go, onScan: () => showScanSheet(context, store)),
      );
    },
  );
}

/// Phone bottom bar: two tabs each side of a raised scan button, on a floating card with a bump.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.tab, required this.onTab, required this.onScan});

  final int tab;
  final ValueChanged<int> onTab;
  final VoidCallback onScan;

  static const _height = 68.0, _bump = 14.0, _button = 60.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    Widget item(int i) {
      final t = _tabs[i];
      final on = i == tab;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          label: t.title,
          child: InkResponse(
            onTap: () => onTab(i),
            radius: 32,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: on ? 1.12 : 1,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: Icon(on ? t.selected : t.icon, color: on ? colors.onSurface : colors.onSurfaceVariant, size: 26),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: on ? 6 : 0,
                  height: 6,
                  decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: SizedBox(
          height: _height + _bump,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _BarPainter(
                    color: dark ? const Color(0xFF1A1B26) : Colors.white,
                    shadow: Colors.black.withValues(alpha: dark ? 0.5 : 0.1),
                    bump: _bump,
                  ),
                ),
              ),
              SizedBox(
                height: _height,
                child: Row(
                  children: [
                    item(0),
                    item(1),
                    const SizedBox(width: _button + 24),
                    item(2),
                    item(3),
                  ],
                ),
              ),
              Positioned(
                top: _bump - _button / 2 + 6,
                child: Semantics(
                  button: true,
                  label: 'Scan an aptitude question',
                  child: Pressable(
                    onTap: onScan,
                    child: Container(
                      width: _button,
                      height: _button,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF8B73FF), Color(0xFF5B3FE6)],
                        ),
                        boxShadow: [BoxShadow(color: colors.primary.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 6))],
                      ),
                      child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar's card: rounded rectangle whose top edge rises in a smooth bump behind the centre button.
class _BarPainter extends CustomPainter {
  const _BarPainter({required this.color, required this.shadow, required this.bump});

  final Color color;
  final Color shadow;
  final double bump;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 26.0, half = 62.0;
    final w = size.width, h = size.height, top = bump, cx = w / 2;
    final path = Path()
      ..moveTo(0, top + r)
      ..quadraticBezierTo(0, top, r, top)
      ..lineTo(cx - half, top)
      ..cubicTo(cx - half / 2, top, cx - half / 2, 0, cx, 0)
      ..cubicTo(cx + half / 2, 0, cx + half / 2, top, cx + half, top)
      ..lineTo(w - r, top)
      ..quadraticBezierTo(w, top, w, top + r)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..close();
    canvas
      ..drawShadow(path, shadow, 10, false)
      ..drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.color != color || old.shadow != shadow;
}

/// Desktop sidebar: logo, the four sections, dark mode switch and who is signed in.
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.user, required this.tab, required this.onTab, required this.onScan});

  final User user;
  final int tab;
  final ValueChanged<int> onTab;
  final VoidCallback onScan;

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
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: onScan,
            icon: const Icon(Icons.document_scanner_rounded),
            label: const Text('Scan question'),
          ),
          const SizedBox(height: 16),
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
