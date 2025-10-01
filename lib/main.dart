import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'firebase_options.dart';
import 'core/notifications/notification_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();
  await NotificationService.showRemoteMessage(message);
}

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Set timezone to Czech Republic
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Prague'));

      // Set locale to Czech
      Intl.defaultLocale = 'cs_CZ';
      await initializeDateFormatting('cs_CZ');

      await NotificationService.initialize();
      // Register background handler only on mobile platforms where it's
      // supported by the plugin.
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
      }
      await _configureMessaging();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
      };

      runApp(const ProviderScope(child: NmsApp()));
    },
    (error, stackTrace) => debugPrint('Uncaught error: $error\n$stackTrace'),
  );
}

Future<void> _configureMessaging() async {
  final messaging = FirebaseMessaging.instance;
  // Request permissions and subscribe to topics only on Android/iOS. The
  // firebase_messaging plugin does not expose topic subscription on desktop
  // platforms (Windows/macOS/Linux) nor web in the same way.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await messaging.subscribeToTopic('announcements');
  }

  // Listen for foreground messages on all platforms; the handler is a no-op
  // on Windows to avoid using the Windows native notifications plugin.
  FirebaseMessaging.onMessage.listen(NotificationService.showRemoteMessage);

  // Only request a token on mobile platforms and web where the plugin
  // provides an implementation. Desktop platforms currently don't implement
  // this method and will throw a MissingPluginException.
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    await messaging.getToken();
  }
}
