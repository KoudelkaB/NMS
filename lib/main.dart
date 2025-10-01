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
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
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
  if (!kIsWeb) {
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  await messaging.subscribeToTopic('announcements');

  FirebaseMessaging.onMessage.listen(NotificationService.showRemoteMessage);

  await messaging.getToken();
}
