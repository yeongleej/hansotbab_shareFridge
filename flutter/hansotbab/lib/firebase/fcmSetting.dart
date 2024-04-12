// Foreground -> 핸들러 필요
// Backround (앱 꺼져있거나, background로 실행 중) -> 핸들러 필요 x
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("background 메시지 : ${message.messageId}");
}

Future<String?> fcmSetting() async {
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  print('권한여부 : ${settings.authorizationStatus}');

  // 안드로이드에서 foreground에서 푸시 알림 표시를 위한 알림 중요도 설정
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'hansotbab_notification', 'hansotbab_notification',
      description: "감사인사가 등록되었습니다.", importance: Importance.max);

  // foreground에서 푸시 알림 표시를 위한 local notifications 설정
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // foreground 푸시 알림 핸들링 설정
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    print("foreground에서 메시지 성공");
    print("Message data : ${message.data}");

    if (message.notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification?.title,
          notification?.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: android.smallIcon,
            ),
          ));
      print("알림과 함께 메시지도 잘 도착 : ${message.notification}");
    }
  });

  // firebase token 발급
  String? firebaseToken = await messaging.getToken();

  print("firebaseToken: ${firebaseToken}");
  return firebaseToken;

  // ignore: dead_code
  Future<void> sendTokenToServer(String email) async {
    String? token = await FirebaseMessaging.instance.getToken();

    String serverUrl = 'https://j10b209.p.ssafy.io/alarm/user';

    await http.post(
      Uri.parse(serverUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'token': token,
      }),
    );
  }
}
