import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'core/notifications/notification_service.dart';

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test App',
      home: Scaffold(
        appBar: AppBar(title: const Text('Test App')),
        body: const Center(
          child: Text('Hello World! Firebase is disabled for testing.'),
        ),
      ),
    );
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();
  await NotificationService.showRemoteMessage(message);
}

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('Firebase initialized successfully');

        // Set Firebase Auth language to Czech
        await FirebaseAuth.instance.setLanguageCode('cs');
      } catch (e, stack) {
        debugPrint('Firebase initialization failed: $e\n$stack');
        // Continue with test app
        runApp(const TestApp());
        return;
      }

      // Set Firestore settings before any Firestore operations on Windows
      if (defaultTargetPlatform == TargetPlatform.windows) {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: false, // Disable persistence on desktop
        );
      }

  // Use device timezone; no explicit override

      // Set locale to Czech
      Intl.defaultLocale = 'cs_CZ';
      await initializeDateFormatting('cs_CZ');

      try {
        await NotificationService.initialize();
        debugPrint('Notification service initialized');
      } catch (e, stack) {
        debugPrint('Notification service initialization failed: $e\n$stack');
      }

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
  try {
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
  } catch (e, stack) {
    debugPrint('Messaging configuration failed: $e\n$stack');
  }
}
