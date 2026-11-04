import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

int? _lastDue, _lastStreak;
String? _lastLevel;

/// Shows today's due reviews and the streak on the Android home screen widget (ReviewWidgetProvider).
/// Only writes when a number changed; never throws, since a widget must not break the app.
/// [level] is a line like "⚔ Lv 7 · Shadow Initiate", or null to leave it as it is.
Future<void> updateHomeWidget({required int due, required int streak, String? level}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  if (due == _lastDue && streak == _lastStreak && (level == null || level == _lastLevel)) return;
  _lastDue = due;
  _lastStreak = streak;
  if (level != null) _lastLevel = level;
  try {
    await HomeWidget.saveWidgetData<int>('due', due);
    await HomeWidget.saveWidgetData<int>('streak', streak);
    if (_lastLevel != null) await HomeWidget.saveWidgetData<String>('level', _lastLevel);
    await HomeWidget.updateWidget(androidName: 'ReviewWidgetProvider');
  } catch (_) {
    // no widget on the home screen, or the launcher refused: nothing to do
  }
}
