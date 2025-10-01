import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Avoid initializing the native Windows plugin due to occasional AOT/FFI
    // snapshot errors seen in release builds. If Windows notifications are
    // needed later, implement a Windows-specific path that is exercised and
    // tested separately.
    if (Platform.isWindows) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );
    await _plugin.initialize(settings);
  }

  static Future<void> showRemoteMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    if (Platform.isWindows) {
      // Skip showing a local notification via the Windows plugin to avoid
      // triggering the FFI-related AOT crash. Implement a separate Windows
      // notification flow if needed.
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'announcements_channel',
      'Oznámení administrátora',
      channelDescription: 'Zobrazování oznámení od administrátora',
      importance: Importance.max,
      priority: Priority.high,
    );

    final iOSDetails = DarwinNotificationDetails();
    final windowsDetails = WindowsNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
      windows: windowsDetails,
    );

    await _plugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
    );
  }
}
