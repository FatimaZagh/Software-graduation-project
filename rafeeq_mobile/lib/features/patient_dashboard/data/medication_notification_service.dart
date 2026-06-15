import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules daily local notifications from server-backed reminder rows (Android/iOS).
/// Web is a no-op; reopening this screen reschedules from the latest list.
class MedicationNotificationService {
  MedicationNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static int notificationId(String reminderId, String doseTime) {
    return ('$reminderId|$doseTime').hashCode & 0x7fffffff;
  }

  static Future<void> ensureInitialized() async {
    if (kIsWeb || _inited) return;
    tzdata.initializeTimeZones();
    try {
      final native = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(native.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'rafeeq_med_reminders',
        'Medication reminders',
        description: 'Alerts when it is time to take a dose',
        importance: Importance.high,
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _inited = true;
  }

  static (int, int)? _parseTime(String s) {
    final parts = s.trim().split(':');
    if (parts.isEmpty) return null;
    final h = int.tryParse(parts[0]);
    if (h == null || h < 0 || h > 23) return null;
    final mi = parts.length >= 2 ? (int.tryParse(parts[1]) ?? 0) : 0;
    if (mi < 0 || mi > 59) return null;
    return (h, mi);
  }

  static tz.TZDateTime _firstFireTodayOrTomorrow(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!d.isAfter(now)) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  /// Replaces all pending medication notifications with the current server list.
  static Future<void> syncFromReminderList(List<dynamic> reminders) async {
    if (kIsWeb) return;
    await ensureInitialized();
    await _plugin.cancelAll();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'rafeeq_med_reminders',
        'Medication reminders',
        channelDescription: 'Alerts when it is time to take a dose',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    for (final raw in reminders) {
      final m = raw as Map<String, dynamic>;
      final id = m['_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final name = m['medicineName']?.toString() ?? 'Medication';
      final times = (m['doseTimes'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
      for (final t in times) {
        final parsed = _parseTime(t);
        if (parsed == null) continue;
        final scheduled = _firstFireTodayOrTomorrow(parsed.$1, parsed.$2);
        await _plugin.zonedSchedule(
          id: notificationId(id, t),
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: name,
          body: 'Time to take your dose.',
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }
  }
}
