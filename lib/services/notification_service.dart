import 'dart:convert';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🔔 Handling a background message: ${message.messageId}");

  if (message.data.isNotEmpty && message.notification == null) {
    final type = message.data['type'] ?? 'general';
    final isEmergency = type == 'emergency';
    
    final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      isEmergency ? 'emergency_channel' : 'fcm_channel',
      isEmergency ? 'Emergency Requests' : 'Push Notifications',
      importance: Importance.max,
      priority: Priority.high,
      color: const Color(0xFFE53935),
    );
    
    await plugin.show(
      id: message.hashCode,
      title: message.data['title'] ?? (isEmergency ? '🚨 URGENT' : 'Notification'),
      body: message.data['body'] ?? 'New update received.',
      notificationDetails: NotificationDetails(android: androidDetails),
    );
  }
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final DateTime _appStartTime = DateTime.now();
  final Set<String> _notifiedDocIds = {};

  Future<void> initialize() async {
    if (_initialized) return;
    print("🔔 Initializing NotificationService...");

    // 1. OneSignal Setup (For Background/Killed state notifications)
    final oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'];
    if (oneSignalAppId != null && oneSignalAppId.isNotEmpty) {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(oneSignalAppId);
      OneSignal.Notifications.requestPermission(true);
      
      // Sync external user ID for targeted notifications later if needed
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        OneSignal.login(user.uid);
      }
    }
    
    // 2. Local Notifications Setup
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: darwinSettings, macOS: darwinSettings);
    
    await _plugin.initialize(settings: initSettings);
    
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      
      const AndroidNotificationChannel fcmChannel = AndroidNotificationChannel(
        'fcm_channel',
        'Push Notifications',
        description: 'General push notifications from the app',
        importance: Importance.max,
        playSound: true,
      );
      
      const AndroidNotificationChannel emergencyChannel = AndroidNotificationChannel(
        'emergency_channel',
        'Emergency Requests',
        description: 'Notifications for urgent blood requests',
        importance: Importance.max,
        playSound: true,
      );

      await androidPlugin.createNotificationChannel(fcmChannel);
      await androidPlugin.createNotificationChannel(emergencyChannel);
    }

    // 3. Firebase Messaging Setup
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await messaging.subscribeToTopic('emergencies');

    String? token = await messaging.getToken();
    if (token != null) {
      _saveTokenToFirestore(token);
    }

    messaging.onTokenRefresh.listen(_saveTokenToFirestore);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final docId = message.data['id'];
      if (docId != null && _notifiedDocIds.contains(docId)) {
        return;
      }

      if (message.notification != null) {
        _showFcmNotification(message.notification!, message.data);
      }
    });
    
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        OneSignal.login(user.uid);
        String? token = await messaging.getToken();
        if (token != null) _saveTokenToFirestore(token);
      }
    });

    _initialized = true;

    // 4. Firestore Real-time Listener (For Foreground only)
    FirebaseFirestore.instance
        .collection('emergencyBanners')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final data = change.doc.data();
          final docId = change.doc.id;

          if (data != null) {
            final Timestamp? createdTs = data['createdAt'] as Timestamp?;
            if (createdTs != null) {
              final createdAt = createdTs.toDate();
              final notificationThreshold = _appStartTime.subtract(const Duration(seconds: 30));
              
              if (createdAt.isAfter(notificationThreshold)) {
                final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
                final postedBy = data['postedBy'];
                
                if (!_notifiedDocIds.contains(docId)) {
                  if (postedBy != null && currentUserUid != null && postedBy == currentUserUid) {
                    _notifiedDocIds.add(docId);
                    continue;
                  }

                  _notifiedDocIds.add(docId);
                  _showEmergencyNotification(data);
                }
              } else {
                _notifiedDocIds.add(docId);
              }
            }
          }
        }
      }
    }, onError: (e) => print("❌ Notification Service Firestore Error: $e"));
  }

  /// Sends a notification to ALL users using OneSignal's REST API.
  /// This bypasses the need for Firebase Cloud Functions / Blaze Plan.
  Future<void> notifyAllUsers({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final appId = dotenv.env['ONESIGNAL_APP_ID'];
    final apiKey = dotenv.env['ONESIGNAL_REST_API_KEY'];

    if (appId == null || apiKey == null) {
      print("⚠️ OneSignal credentials missing. Notification not sent.");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $apiKey',
        },
        body: jsonEncode({
          'app_id': appId,
          'included_segments': ['All'], // Send to every user
          'headings': {'en': title},
          'contents': {'en': body},
          'data': data ?? {},
          'android_channel_id': data?['type'] == 'emergency' ? 'emergency_channel' : 'fcm_channel',
          'priority': 10,
        }),
      );

      if (response.statusCode == 200) {
        print("✅ OneSignal Notification Sent Successfully");
      } else {
        print("❌ OneSignal Error: ${response.body}");
      }
    } catch (e) {
      print("❌ OneSignal Exception: $e");
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      } catch (e) {
        print("❌ Failed to save FCM token: $e");
      }
    }
  }

  Future<void> _showFcmNotification(RemoteNotification notification, Map<String, dynamic> data) async {
    final type = data['type'] ?? 'general';
    final isEmergency = type == 'emergency';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      isEmergency ? 'emergency_channel' : 'fcm_channel',
      isEmergency ? 'Emergency Requests' : 'Push Notifications',
      importance: Importance.max,
      priority: Priority.high,
      color: const Color(0xFFE53935),
      playSound: true,
      enableVibration: true,
    );
    final NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
    );
  }

  Future<void> _showEmergencyNotification(Map<String, dynamic> data) async {
    final name = data['name'] ?? 'Someone';
    final bloodType = data['bloodType'] ?? 'Blood';
    final location = data['location'] ?? 'your area';

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'emergency_channel',
      'Emergency Requests',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFFE53935),
      playSound: true,
      enableVibration: true,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: data.hashCode,
      title: '🚨 URGENT: $bloodType Blood Needed!',
      body: '$name urgently needs $bloodType blood at $location. Tap to help.',
      notificationDetails: details,
    );
  }
}
