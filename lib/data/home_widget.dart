import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

int? _lastDue, _lastStreak;

/// Shows today's due reviews and the streak on the Android home screen widget (ReviewWidgetProvider).
/// Only writes when a number changed; never throws, since a widget must not break the app.
Future<void> updateHomeWidget({required int due, required int streak}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  if (due == _lastDue && streak == _lastStreak) return;
  _lastDue = due;
  _lastStreak = streak;
  try {
    await HomeWidget.saveWidgetData<int>('due', due);
    await HomeWidget.saveWidgetData<int>('streak', streak);
    await HomeWidget.updateWidget(androidName: 'ReviewWidgetProvider');
  } catch (_) {
    // no widget on the home screen, or the launcher refused: nothing to do
  }
}
