import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings kept on this device (not synced): appearance, reminder, daily goal, seen tips.
/// Screens listen to the notifiers; setters update them at once and save in the background.
abstract final class Prefs {
  static final themeMode = ValueNotifier(ThemeMode.light);
  static final seenOnboarding = ValueNotifier(false);

  /// Daily reminder time as minutes after midnight, or null when switched off.
  static final reminderMinutes = ValueNotifier<int?>(10 * 60);

  /// New problems to solve each day (reviews due are always part of the day's goal).
  static final dailyNewGoal = ValueNotifier(1);

  /// The sheet you follow (see sheets in sheet.dart).
  static final sheetId = ValueNotifier('a2z');

  /// Ids of walkthrough tips already shown.
  static final seenTips = ValueNotifier<Set<String>>(const {});

  static const _theme = 'themeMode', _onboarding = 'seenOnboarding', _reminder = 'reminderMinutes';
  static const _goal = 'dailyNewGoal', _tips = 'seenTips', _sheet = 'sheetId', _reminderOff = -1;

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
    reminderMinutes.value = minutes == null ? 10 * 60 : (minutes == _reminderOff ? null : minutes);
    dailyNewGoal.value = (p.getInt(_goal) ?? 1).clamp(0, 10);
    seenTips.value = {...?p.getStringList(_tips)};
    sheetId.value = p.getString(_sheet) ?? 'a2z';
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

  static void markTipSeen(String id) {
    seenTips.value = {...seenTips.value, id};
    unawaited(_prefs().then((p) => p?.setStringList(_tips, seenTips.value.toList())));
  }

  static void resetTips() {
    seenTips.value = const {};
    unawaited(_prefs().then((p) => p?.remove(_tips)));
  }
}
