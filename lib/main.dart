import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app.dart';
import 'core/di/injection.dart';
import 'core/services/notification_handler.dart';
import 'core/utils/feedback_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone data (synchronous, fast)
  tz.initializeTimeZones();

  // Run the heaviest init calls in parallel:
  // - Firebase init (~2-3s cold)
  // - Preferred orientations (~50ms)
  // These have no interdependencies.
  await Future.wait([
    Firebase.initializeApp(),
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  ]);

  // Set up background message handler (must be after Firebase.initializeApp)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // System UI (synchronous, no await needed)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize dependency injection (needs to be done before runApp)
  await configureDependencies();

  // Launch app immediately — defer non-critical init to background
  runApp(const ParentalCareApp());

  // Non-blocking: prime feedback settings + notification channels after first frame
  FeedbackSettings.refresh();
  NotificationHandler().initialize();
}
