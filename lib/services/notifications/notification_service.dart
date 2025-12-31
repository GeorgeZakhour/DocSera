// lib/services/notifications/notification_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:pushy_flutter/pushy_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _pushyDeviceToken;

  static const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
    'docsera_default',
    'General Notifications',
    description: 'General notifications for DocSera',
    importance: Importance.high,
  );

  Future<void> init({required BuildContext context}) async {
    if (_initialized) return;

    // 1) Timezones
    tz.initializeTimeZones();
    // استخدم أي fallback منطقي لبيئتك
    tz.setLocalLocation(tz.getLocation(_fallbackTz()));

    // 2) تهيئة flutter_local_notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // سنعرض الإشعار يدويًا عبر showLocal
      defaultPresentAlert: false,
      defaultPresentBadge: false,
      defaultPresentSound: false,
    );

    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _fln.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) => _handleNotificationTap(context, resp.payload),
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // قناة أندرويد
    await _fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_defaultChannel);

    // 3) طلب سماح iOS (اختياري، أغلبه تم في DarwinInitializationSettings)
    await _fln
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // 4) Pushy (مهم: تأكد من استدعاء Pushy.listen() في main.dart داخل initState)
    await _initPushy(context);

    _initialized = true;
  }

  Future<void> _initPushy(BuildContext context) async {
    // استقبال الإشعارات (خلفية/مقدمة)
    Pushy.setNotificationListener((Map<String, dynamic> data) async {
      final title = (data['title'] ?? 'DocSera') as String;
      final body = (data['body'] ?? '') as String;
      final payload = (data['payload'] ?? '') as String;
      await showLocal(title: title, body: body, payload: payload);

      // امسح شارة iOS عند الاستلام إذا كان مناسب لسيناريوك
      Pushy.clearBadge();
    });

    // عند الضغط على الإشعار
    Pushy.setNotificationClickListener((Map<String, dynamic> data) {
      final payload = (data['payload'] ?? '') as String?;
      _handleNotificationTap(context, payload);
      // امسح الشارة على iOS
      Pushy.clearBadge();
    });

    try {
      // تسجيل الجهاز والحصول على التوكن
      final token = await Pushy.register();
      _pushyDeviceToken = token;

      // بانر داخل التطبيق على iOS (اختياري)
      if (Platform.isIOS) {
        Pushy.toggleInAppBanner(false);
        // لا توجد setBadge في Pushy؛ استخدم clearBadge لمسح الشارة
        Pushy.clearBadge();
      }

      await _saveDeviceTokenToSupabase(token);
    } catch (e) {
      // يمكنك تسجيل الخطأ
      debugPrint('Pushy register error: $e');
    }
  }

  Future<void> _saveDeviceTokenToSupabase(String token) async {
    final session = Supabase.instance.client.auth.currentSession;
    final userId = session?.user.id;
    if (userId == null) return;

    await Supabase.instance.client.from('user_devices').upsert({
      'user_id': userId,
      'token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
    }, onConflict: 'user_id,token');
  }

  Future<void> showLocal({
    required String title,
    required String body,
    String? payload,
  }) async {
    final android = AndroidNotificationDetails(
      _defaultChannel.id,
      _defaultChannel.name,
      channelDescription: _defaultChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _fln.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
      payload: payload,
    );
  }

  Future<void> scheduleReminder({
    required DateTime whenLocal,
    required String title,
    required String body,
    String? payload,
    bool allowWhileIdle = true,
  }) async {
    if (whenLocal.isBefore(DateTime.now())) return;

    final android = AndroidNotificationDetails(
      _defaultChannel.id,
      _defaultChannel.name,
      channelDescription: _defaultChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // ملاحظة: في v18+ تم حذف uiLocalNotificationDateInterpretation و enum المرتبط
    await _fln.zonedSchedule(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      tz.TZDateTime.from(whenLocal, tz.local),
      NotificationDetails(android: android, iOS: ios),
      androidScheduleMode: allowWhileIdle
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexact,
      // لا ترسل هذا البراميتر بعد الآن:
      // uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  void _handleNotificationTap(BuildContext context, String? payload) {
    if (payload == null || payload.isEmpty) return;

    // أمثلة: 'conversation:{id}' أو 'appointment:{id}'
    if (payload.startsWith('conversation:')) {
      final id = payload.split(':').last;
      // TODO: افتح صفحة المحادثة
      // Navigator.push(context, MaterialPageRoute(builder: (_) => MessagesPage(conversationId: id)));
    } else if (payload.startsWith('appointment:')) {
      final id = payload.split(':').last;
      // TODO: افتح صفحة الموعد
    }
  }

  Future<void> clearBadge() async {
    if (Platform.isIOS) {
      // لا يوجد setBadge في Pushy، استخدم clearBadge لمسح العداد
      Pushy.clearBadge();
    }
  }

  /// تفعيل/إيقاف استقبال إشعارات Pushy على هذا الجهاز
  Future<void> setPushEnabled(bool enabled) async {
    try {
      // الطريقة الصحيحة في pushy_flutter هي toggleNotifications
      Pushy.toggleNotifications(enabled);

      if (enabled && _pushyDeviceToken == null) {
        final token = await Pushy.register();
        _pushyDeviceToken = token;
        await _saveDeviceTokenToSupabase(token);
      }

      if (!enabled) {
        _pushyDeviceToken = null;
      }
    } catch (e) {
      debugPrint('setPushEnabled error: $e');
    }
  }

  String _fallbackTz() => 'Europe/Berlin';
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse resp) {
  // لا يوجد context هنا
}
