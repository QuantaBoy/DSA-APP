import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings kept on this device (not synced): appearance, reminder, daily goal, seen tips.
/// Screens listen to the notifiers; setters update them at once and save in the background.
abstract final class Prefs {
  static final themeMode = ValueNotifier(ThemeMode.light);
  static final seenOnboarding = ValueNotifier(false);

  /// Daily reminder time as minutes after midnight, or null when switched off.
  static final reminderMinutes = ValueNotifier<int?>(null);

  /// New problems to solve each day (reviews due are always part of the day's goal).
  static final dailyNewGoal = ValueNotifier(1);

  /// The sheet you follow (see sheets in sheet.dart).
  static final sheetId = ValueNotifier('a2z');

  /// Whether you joined the leaderboard on this device (the entry itself lives in Firestore).
  static final leaderboard = ValueNotifier(false);

  /// LeetCode username whose accepted problems are imported, or null.
  static final leetcodeUser = ValueNotifier<String?>(null);

  /// Sound effects on.
  static final sounds = ValueNotifier(false); // on by default once load() runs (tests never play sound)

  /// Title you wear (an id from ascension.dart), or null.
  static final equippedTitle = ValueNotifier<String?>(null);

  /// Level and titles already celebrated, so each level-up shows once. -1 before the first look.
  static int seenLevel = -1;

  /// Day (yyyy-mm-dd) the goal celebration last played, so it plays once a day.
  static String? goalCelebrated;

  /// Day (yyyy-mm-dd) the streak celebration last played.
  static String? streakCelebrated;

  /// When the app was last opened on this device (for signing out after a long break).
  static DateTime? lastActive;
  static Set<String> seenTitles = const {};

  /// Ids of walkthrough tips already shown.
  static final seenTips = ValueNotifier<Set<String>>(const {});

  static const _theme = 'themeMode', _onboarding = 'seenOnboarding', _reminder = 'reminderMinutes';
  static const _goal = 'dailyNewGoal', _tips = 'seenTips', _sheet = 'sheetId', _board = 'leaderboard', _leetcode = 'leetcodeUser';
  static const _sounds = 'sounds', _streakDay = 'streakCelebrated';
  static const _goalDay = 'goalCelebrated', _active = 'lastActive';
  static const _title = 'equippedTitle', _seenLevel = 'seenLevel', _seenTitles = 'seenTitles';
  static const _reminderOff = -1;

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null; // storage unavailable (some private browser windows): keep defaults for this session
    }
  }

  static Future<void> load() async {
    final p = await _prefs();
    if (p == null) return;
    themeMode.value = ThemeMode.values.firstWhere((m) => m.name == p.getString(_theme), orElse: () => ThemeMode.light);
    seenOnboarding.value = p.getBool(_onboarding) ?? false;
    final minutes = p.getInt(_reminder);
    reminderMinutes.value = minutes == null || minutes == _reminderOff ? null : minutes; // off until you switch it on
    dailyNewGoal.value = (p.getInt(_goal) ?? 1).clamp(0, 10);
    seenTips.value = {...?p.getStringList(_tips)};
    sheetId.value = p.getString(_sheet) ?? 'a2z';
    leaderboard.value = p.getBool(_board) ?? false;
    leetcodeUser.value = p.getString(_leetcode);
    equippedTitle.value = p.getString(_title);
    sounds.value = p.getBool(_sounds) ?? true;
    seenLevel = p.getInt(_seenLevel) ?? -1;
    goalCelebrated = p.getString(_goalDay);
    streakCelebrated = p.getString(_streakDay);
    final active = p.getInt(_active);
    lastActive = active == null ? null : DateTime.fromMillisecondsSinceEpoch(active);
    seenTitles = {...?p.getStringList(_seenTitles)};
  }

  static void setSounds(bool on) {
    sounds.value = on;
    unawaited(_prefs().then((p) => p?.setBool(_sounds, on)));
  }

  static void markActive(DateTime now) {
    lastActive = now;
    unawaited(_prefs().then((p) => p?.setInt(_active, now.millisecondsSinceEpoch)));
  }

  static void markStreakCelebrated(String day) {
    streakCelebrated = day;
    unawaited(_prefs().then((p) => p?.setString(_streakDay, day)));
  }

  static void markGoalCelebrated(String day) {
    goalCelebrated = day;
    unawaited(_prefs().then((p) => p?.setString(_goalDay, day)));
  }

  static void equipTitle(String? id) {
    equippedTitle.value = id;
    unawaited(_prefs().then((p) => id == null ? p?.remove(_title) : p?.setString(_title, id)));
  }

  static void markSeen(int level, Set<String> titles) {
    seenLevel = level;
    seenTitles = titles;
    unawaited(
      _prefs().then((p) async {
        await p?.setInt(_seenLevel, level);
        await p?.setStringList(_seenTitles, titles.toList());
      }),
    );
  }

  static void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    unawaited(_prefs().then((p) => p?.setString(_theme, mode.name)));
  }

  static void finishOnboarding() {
    seenOnboarding.value = true;
    unawaited(_prefs().then((p) => p?.setBool(_onboarding, true)));
  }

  static void setReminder(int? minutes) {
    reminderMinutes.value = minutes;
    unawaited(_prefs().then((p) => p?.setInt(_reminder, minutes ?? _reminderOff)));
  }

  static void setDailyNewGoal(int goal) {
    dailyNewGoal.value = goal.clamp(0, 10);
    unawaited(_prefs().then((p) => p?.setInt(_goal, dailyNewGoal.value)));
  }

  static void setSheet(String id) {
    sheetId.value = id;
    unawaited(_prefs().then((p) => p?.setString(_sheet, id)));
  }

  static void setLeaderboard(bool joined) {
    leaderboard.value = joined;
    unawaited(_prefs().then((p) => p?.setBool(_board, joined)));
  }

  static void setLeetcodeUser(String? name) {
    leetcodeUser.value = name;
    unawaited(_prefs().then((p) => name == null ? p?.remove(_leetcode) : p?.setString(_leetcode, name)));
  }

  static void markTipSeen(String id) {
    seenTips.value = {...seenTips.value, id};
    unawaited(_prefs().then((p) => p?.setStringList(_tips, seenTips.value.toList())));
  }

  static void resetTips() {
    seenTips.value = const {};
    unawaited(_prefs().then((p) => p?.remove(_tips)));
  }
}
