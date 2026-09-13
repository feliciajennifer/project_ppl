import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'app_navigator.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
      if (_initialized) return;
      _initialized = true;

      await _requestPermission();
      await _initLocalNotification();
      await _subscribeGlobalTopic();

      _setupForegroundHandler();
      _setupNotificationTapHandler();
    }

    static Future<void> _requestPermission() async {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    static Future<void> _initLocalNotification() async {
    const androidInit = AndroidInitializationSettings(
      '@drawable/ic_notification', // LOGO APP
    );

    await _localNotif.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          _handlePayload(response.payload!);
        }
      },
    );
  }

  static Future<void> _subscribeGlobalTopic() async {
    final token = await _fcm.getToken();
    if (token != null) {
      await _fcm.subscribeToTopic('vigilanter_alert');
      debugPrint("Subscribed to vigilanter_alert");
    }
  }

  static void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((message) {
      final notif = message.notification;
      if (notif == null) return;

      final data = message.data;

      _localNotif.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        notif.title,
        notif.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'vigilanter',
            'Peringatan Kejahatan',
            channelDescription: 'Notifikasi laporan kejahatan valid',
            importance: Importance.max,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(''),
          ),
        ),
        payload: _encodePayload(data),
      );
    });
  }

  static void _setupNotificationTapHandler() async {
      // App terminated
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessage(initialMessage);
      }

      // App background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    }

    static void _handleMessage(RemoteMessage message) {
      final data = message.data;

      if (!data.containsKey('latitude')) return;

      final lat = double.parse(data['latitude']);
      final lng = double.parse(data['longitude']);
      final reportId = data['report_id'];

      AppNavigator.toMap(
        latLng: LatLng(lat, lng),
        reportId: reportId,
      );
    }

    static String _encodePayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  static void _handlePayload(String payload) {
    final map = <String, String>{};

    for (final pair in payload.split('&')) {
      final kv = pair.split('=');
      if (kv.length == 2) map[kv[0]] = kv[1];
    }

    if (!map.containsKey('latitude')) return;

    final lat = double.parse(map['latitude']!);
    final lng = double.parse(map['longitude']!);
    final reportId = map['report_id'];

    AppNavigator.toMap(
      latLng: LatLng(lat, lng),
      reportId: reportId,
    );
  }

}
