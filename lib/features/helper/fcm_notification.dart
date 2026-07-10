import 'package:firebase_messaging/firebase_messaging.dart';

class FcmNotification {

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  void requestNotificationPermission()async{
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if(settings.authorizationStatus == AuthorizationStatus.authorized){
      print("permission allowed");
    }else{
      print("permission denied");
    }
  }

  void token()async{
    String? token = await FirebaseMessaging.instance.getToken();
    print("Mera FCM Token: $token");
  }
}