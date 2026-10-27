import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Hour (24h, phone's local time) of the daily "time to review" notification.
const reminderHour = 20;

final _notifications = FlutterLocalNotificationsPlugin();

/// Asks for notification permission (Android 13+) and schedules one notification every day.
/// Scheduling again replaces the old one, so this is safe to call on every launch. Android only.
Future<void> scheduleDailyReminder() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  tzdata.initializeTimeZones();
  await _notifications.initialize(
    settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );
  await _notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  final now = DateTime.now();
  var at = DateTime(now.year, now.month, now.day, reminderHour);
  if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
  // ponytail: repeats at a fixed UTC time, so it shifts an hour across daylight-saving changes;
  // use the flutter_timezone package to get the real zone if that matters.
  await _notifications.zonedSchedule(
    id: 0,
    title: 'Time to revise',
    body: 'Your problems are waiting. A few minutes now keeps them in memory.',
    scheduledDate: tz.TZDateTime.from(at, tz.UTC),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails('daily_review', 'Daily review reminder',
          channelDescription: 'One reminder a day to review due problems.'),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}
