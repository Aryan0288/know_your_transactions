import 'package:cloudinary_flutter/cloudinary_context.dart';
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/splash/page_splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:know_your_expenses/features/helper/notification_helper.dart';
import 'package:know_your_expenses/features/common_widgets/widget_connectivity_wrapper.dart';

Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
  await Firebase.initializeApp();

  // Initialize AdMob and Notifications
  await MobileAds.instance.initialize();
  await NotificationHelper.initialize();

  CloudinaryContext.cloudinary = Cloudinary.fromCloudName(
    cloudName: 'dl0b0wqdk',
  );

  // Make status bar transparent so splash looks full-bleed
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Know Your Expenses',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E8B57)),
      ),
      home: const SplashPage(),
      builder: (context, child) {
        return ConnectivityWrapper(child: child!);
      },
    );
  }
}
