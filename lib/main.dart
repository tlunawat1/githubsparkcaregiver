import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app.dart';
import 'core/di/injection.dart';
import 'core/services/notification_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone data for notifications
  tz.initializeTimeZones();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize notification handler
  await NotificationHandler().initialize();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize dependency injection
  await configureDependencies();

  runApp(const ParentalCareApp());
}
