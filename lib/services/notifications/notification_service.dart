// lib/services/notifications/notification_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:pushy_flutter/pushy_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/screens/home/messages/conversation/conversation_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/Business_Logic/Messages_page/conversation_cubit.dart';
import 'package:docsera/services/supabase/supabase_conversation_service.dart';
import 'package:docsera/services/navigation/app_lifecycle.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:docsera/Business_Logic/Health_page/patient_switcher_cubit.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/visit_reports_page.dart';

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

  GlobalKey<NavigatorState>? navigatorKey;

  Future<void> init({required GlobalKey<NavigatorState> navKey}) async {
    navigatorKey = navKey;
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
      onDidReceiveNotificationResponse: (resp) => _handleNotificationTap(resp.payload),
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
    await _initPushy();

    _initialized = true;
  }

  Future<void> _initPushy() async {
    // استقبال الإشعارات (خلفية/مقدمة)
    Pushy.setNotificationListener(backgroundNotificationListener);

    // Start listening for notifications
    Pushy.listen();


    // عند الضغط على الإشعار
    Pushy.setNotificationClickListener((Map<String, dynamic> data) {
      final payload = (data['payload'] ?? '') as String?;
      _handleNotificationTap(payload);
      // امسح الشارة على iOS
      Pushy.clearBadge();
    });

    try {
      // تسجيل الجهاز والحصول على التوكن
      final token = await Pushy.register();
      debugPrint('✅ Pushy Registration Success: $token');
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
      debugPrint('❌ Pushy register error: $e');
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
    
    debugPrint('✅ Pushy Token saved to Supabase for user: $userId');
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

  void _handleNotificationTap(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    
    // ✅ Wait for Main Screen to be ready (Cold Start Fix)
    await AppLifecycle.waitForAppReady();

    debugPrint("🔔 Notification Tapped with payload: $payload");

    final nav = navigatorKey?.currentState;
    if (nav == null) {
      debugPrint("⚠️ Navigator State is null, cannot navigate");
      return;
    }

    if (payload.startsWith('conversation:')) {
      final conversationId = payload.split(':').last;
      
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) return;

        // ✅ FIX: Clear stack & Switch to Messages Tab
        final navState = navigatorKey?.currentState;
        if (navState != null) {
          navState.popUntil((route) => route.isFirst);

          final mainScreenState = CustomBottomNavigationBar.globalKey.currentState;
          if (mainScreenState != null) {
            mainScreenState.switchTab(3); // Index 3 = Messages
          }
        }
        
        // Small delay to ensure tab switch completes
        await Future.delayed(const Duration(milliseconds: 150));

        final response = await Supabase.instance.client
            .from('conversations')
            .select()
            .eq('id', conversationId)
            .maybeSingle();

        if (response != null) {
          final doctorName = response['doctor_name'] ?? 'Doctor';
          final patientName = response['patient_name'] ?? 'Patient';
          final accountHolder = response['account_holder_name'] ?? patientName;
          
          final String? docUrl = response['doctor_image'];
          final ImageProvider avatar = (docUrl != null && docUrl.isNotEmpty)
              ? NetworkImage(docUrl)
              : const NetworkImage('https://via.placeholder.com/150');

          navigatorKey?.currentState?.push(
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (_) => ConversationCubit(ConversationService()),
                child: ConversationPage(
                  conversationId: conversationId,
                  doctorName: doctorName,
                  doctorAvatar: avatar,
                  accountHolderName: accountHolder,
                  patientName: patientName,
                ),
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint("Error navigating to conversation: $e");
      }
    } else if (payload.startsWith('appointment:')) {
        debugPrint("📅 Navigating to Appointments Tab");
        
        final nav = navigatorKey?.currentState;
        if (nav != null) {
          nav.popUntil((route) => route.isFirst);
          
          // ✅ Switch to Appointments Tab (Index 1)
          final mainScreenState = CustomBottomNavigationBar.globalKey.currentState;
          if (mainScreenState != null) {
             mainScreenState.switchTab(1); // Appointments is usually index 1
          }
        }
    } else if (payload.startsWith('document:')) {
        debugPrint("📄 Navigating to Documents");
        
        final nav = navigatorKey?.currentState;
        if (nav != null) {
          nav.popUntil((route) => route.isFirst);
          
           // ✅ Switch to Documents/Health Tab (Index 3 or 2 depending on layout)
           // Assuming Health Page is Index 2
          final mainScreenState = CustomBottomNavigationBar.globalKey.currentState;
          if (mainScreenState != null) {
             mainScreenState.switchTab(2); 
          }
        }
    } else if (payload.startsWith('report:')) {
        debugPrint("📄 Navigating to Visit Reports Page");
        
        final nav = navigatorKey?.currentState;
        if (nav != null) {
          // 1. Parsing Payload: report:recordId:relativeId:patientName
          final parts = payload.split(':'); 
          if (parts.length >= 4) {
             final relativeId = parts[2];
             final patientName = parts[3];
             
             // 2. Switch Patient Context
             final context = navigatorKey?.currentContext;
             if (context != null) {
                 final switcher = context.read<PatientSwitcherCubit>();
                 
                 debugPrint("🔄 Switching patient context to: ${relativeId == 'null' ? 'Main User' : patientName}");
                 
                 if (relativeId == 'null' || relativeId == 'undefined' || relativeId.isEmpty) {
                     switcher.switchToUser();
                 } else {
                     switcher.switchToRelative(
                         relativeId: relativeId, 
                         relativeName: patientName
                     );
                 }
             }
          }

          // Small delay to ensure state propagation
           await Future.delayed(const Duration(milliseconds: 100));

          // 3. Navigate
          nav.push(
            MaterialPageRoute(
               builder: (_) => const VisitReportsPage(),
            ),
          );
        }
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

  String _fallbackTz() => 'Asia/Damascus';
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse resp) {
  // لا يوجد context هنا
}

@pragma('vm:entry-point')
Future<void> backgroundNotificationListener(Map<String, dynamic> data) async {
  debugPrint('🔔 Pushy Background Listener Received: $data');
  // Initialize Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();

  final title = (data['title'] ?? 'DocSera') as String;
  final body = (data['body'] ?? '') as String;
  final payload = (data['payload'] ?? '') as String;

  // We need to initialize local notifications plugin here because this runs in a separate isolate
  final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  const settings = InitializationSettings(android: androidInit, iOS: iosInit);
  await fln.initialize(settings);

  // Show local notification
  const androidDetails = AndroidNotificationDetails(
    'docsera_default',
    'General Notifications',
    importance: Importance.high,
    priority: Priority.high,
  );
  const iosDetails = DarwinNotificationDetails();

  await fln.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    const NotificationDetails(android: androidDetails, iOS: iosDetails),
    payload: payload,
  );

  // Clear badge on iOS
  Pushy.clearBadge();
}
