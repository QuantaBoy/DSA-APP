import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

int? _lastDue, _lastStreak;
String? _lastLevel, _lastWeek;

/// Shows today's due reviews and the streak on the Android home screen widget (ReviewWidgetProvider).
/// Only writes when a number changed; never throws, since a widget must not break the app.
/// [level] is a line like "⚔ Lv 7 · Shadow Initiate", or null to leave it as it is.
/// [week] is 7 letters, Monday first: d done, m missed, t today, f ahead.
Future<void> updateHomeWidget({required int due, required int streak, String? level, String? week}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  if (due == _lastDue && streak == _lastStreak && (level == null || level == _lastLevel) && (week == null || week == _lastWeek)) return;
  _lastDue = due;
  _lastStreak = streak;
  if (level != null) _lastLevel = level;
  if (week != null) _lastWeek = week;
  try {
    await HomeWidget.saveWidgetData<int>('due', due);
    await HomeWidget.saveWidgetData<int>('streak', streak);
    if (_lastLevel != null) await HomeWidget.saveWidgetData<String>('level', _lastLevel);
    if (_lastWeek != null) await HomeWidget.saveWidgetData<String>('week', _lastWeek);
    await HomeWidget.updateWidget(androidName: 'ReviewWidgetProvider');
  } catch (_) {
    // no widget on the home screen, or the launcher refused: nothing to do
  }
}

/// This week for the widget, Monday first: d done, m missed, t today (nothing yet), f ahead.
String weekString(Set<DateTime> active, DateTime today) {
  final monday = DateTime.utc(today.year, today.month, today.day - (today.weekday - 1));
  return [
    for (var i = 0; i < 7; i++)
      switch (DateTime.utc(monday.year, monday.month, monday.day + i)) {
        final d when active.contains(d) => 'd',
        final d when d == today => 't',
        final d when d.isBefore(today) => 'm',
        _ => 'f',
      },
  ].join();
}
