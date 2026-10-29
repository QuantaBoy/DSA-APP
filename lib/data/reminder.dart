import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final _notifications = FlutterLocalNotificationsPlugin();
const _reminderId = 0;

bool get _supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Schedules the daily "time to revise" notification at [minutesOfDay] (phone's local time),
/// or cancels it when null. Scheduling again replaces the old one, so it is safe on every launch.
Future<void> scheduleDailyReminder(int? minutesOfDay) async {
  if (!_supported) return;
  tzdata.initializeTimeZones();
  await _notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    ),
  );
  await _notifications.cancel(id: _reminderId);
  if (minutesOfDay == null) return;

  await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  await _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
    alert: true,
    sound: true,
  );

  final now = DateTime.now();
  var at = DateTime(now.year, now.month, now.day, minutesOfDay ~/ 60, minutesOfDay % 60);
  if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
  // ponytail: repeats at a fixed UTC time, so it shifts an hour across daylight-saving changes;
  // use the flutter_timezone package to get the real zone if that matters.
  await _notifications.zonedSchedule(
    id: _reminderId,
    title: 'Time to revise',
    body: 'Your problems are waiting. A few minutes now keeps them in memory.',
    scheduledDate: tz.TZDateTime.from(at, tz.UTC),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_review',
        'Daily review reminder',
        channelDescription: 'One reminder a day to review due problems.',
      ),
      iOS: DarwinNotificationDetails(),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}
