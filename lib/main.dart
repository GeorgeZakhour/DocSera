import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:docsera/Business_Logic/Account_page/danger/account_danger_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/profile/account_profile_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/relatives/relatives_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/security/account_security_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/user_cubit.dart';
import 'package:docsera/Business_Logic/Appointments_page/appointments_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart' as custom_auth;
import 'package:docsera/Business_Logic/Available_appointments_page/doctor_schedule_cubit.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_cubit.dart';
import 'package:docsera/Business_Logic/Documents_page/notes/notes_cubit.dart';
import 'package:docsera/Business_Logic/Health_page/patient_switcher_cubit.dart';
import 'package:docsera/Business_Logic/Main_page/main_screen_cubit.dart';
import 'package:docsera/Business_Logic/Messages_page/messages_cubit.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:docsera/services/supabase/user/account_relatives_service.dart';
import 'package:docsera/services/notifications/notification_service.dart';
import 'package:docsera/splash_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/auth/login/login_page.dart';
import 'package:docsera/screens/auth/identification_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'Business_Logic/Account_page/user_state.dart';
import 'Business_Logic/Authentication/auth_cubit.dart';
import 'app/const.dart';
import 'services/supabase/user/account_danger_service.dart';
import 'services/supabase/user/account_profile_service.dart';
import 'services/supabase/user/account_security_service.dart';
import 'services/supabase/user/supabase_user_service.dart';
import 'dart:developer';
import 'package:app_links/app_links.dart';


import 'services/navigation/deep_link_service.dart';
import 'services/connectivity/connectivity_service.dart'; // ✅ Import Connectivity Service
import 'widgets/offline_banner.dart'; // ✅ Import Offline Banner

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones(); // 👈 مهم جداً لمرة واحدة فقط

  // ✅ Syria-Proof Configuration: 30s Timeout
  await Supabase.initialize(
    url: SupabaseKeys.supabaseUrl,
    anonKey: SupabaseKeys.supabaseAnonKey,
    httpClient: _SyriaClient(), // Custom client with extended timeout
  );




  ConnectivityService().initialize();
  // ✅ Initialize Notifications
  // Moved to MyApp to access NavigatorKey
  // await NotificationService.instance.init(context: null); 


  SharedPreferences prefs = await SharedPreferences.getInstance();
  final supabaseService = SupabaseUserService();

  // ✅ تحميل اللغة المحفوظة مسبقًا
  final savedLocale = await getSavedLocale();


  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );




  runApp(
    RepositoryProvider.value(
      value: supabaseService,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(create: (_) => AuthCubit(prefs: prefs)),
          BlocProvider<MainScreenCubit>(
            create: (context) => MainScreenCubit(supabaseService, prefs),
          ),
          BlocProvider(create: (context) => AppointmentsCubit(supabaseService, prefs)),
          BlocProvider(create: (context) => MessagesCubit()),
          BlocProvider(create: (context) => DocumentsCubit()),
          BlocProvider(create: (context) => UserCubit(supabaseService, prefs)),
          BlocProvider(
            create: (_) => AccountProfileCubit(
              service: AccountProfileService(),
            ),
          ),

          BlocProvider(
            create: (_) => RelativesCubit(AccountRelativesService()),
          ),

          BlocProvider(
            create: (_) => AccountSecurityCubit(service: AccountSecurityService()),
          ),
          BlocProvider(
            create: (_) => AccountDangerCubit(service: AccountDangerService()),
          ),
          BlocProvider(create: (context) => DoctorScheduleCubit()),
          BlocProvider(create: (context) => NotesCubit()),
          BlocProvider(create: (_) => PatientSwitcherCubit()),


        ],
        child: BlocListener<AuthCubit, custom_auth.AppAuthState>(
          listenWhen: (previous, current) {
            // 🔴 امنع التنفيذ عند tokenRefreshed
            if (previous is custom_auth.AuthAuthenticated &&
                current is custom_auth.AuthAuthenticated) {
              return false;
            }
            return true;
          },
          listener: (context, state) {
            if (state is custom_auth.AuthAuthenticated) {
              // 🔹 هذه تُستدعى مرة واحدة فقط
              context.read<MainScreenCubit>().loadMainScreen(context);
              context.read<AppointmentsCubit>().loadAppointments(context: context);
              context.read<DocumentsCubit>().listenToDocuments(context: context);
              context.read<NotesCubit>().listenToNotes(context);

              final userCubit = context.read<UserCubit>();
              userCubit.loadUserData(context: context, useCache: true);
              userCubit.startRealtimeUserListener(state.user.id);

              final userState = userCubit.state;
              if (userState is UserLoaded) {
                context.read<PatientSwitcherCubit>().switchToUser();
              }
            }
          },
          child: MyApp(
            savedLocale: savedLocale,
            supabaseClient: Supabase.instance.client, // Pass client here
          ),
        ),

      ),
    ),
  );
}

Future<String> getSavedLocale() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString('locale') ?? 'ar';// ✅ تعيين اللغة الافتراضية إلى الإنجليزية
}

class MyApp extends StatefulWidget {
  final String savedLocale;
  final SupabaseClient? supabaseClient; // Optional for testing

  const MyApp({
    super.key,
    required this.savedLocale,
    this.supabaseClient,
  });

  static _MyAppState? of(BuildContext context) => context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Locale _locale;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  late final DeepLinkService _deepLinkService;

  @override
  void initState() {
    super.initState();
    _locale = Locale(widget.savedLocale);
    
    // Initialize DeepLinkService only if client is provided (or use singleton as fallback)
    final client = widget.supabaseClient ?? Supabase.instance.client;
    _deepLinkService = DeepLinkService(client, _navKey);
    _deepLinkService.initDeepLinks();
    
    // ✅ Initialize Notifications with Navigator Key
    NotificationService.instance.init(navKey: _navKey);
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }







  /// ✅ `getter` عام لإتاحة `_locale` خارج `MyAppState`
  Locale get currentLocale => _locale;

  /// ✅ دالة تغيير اللغة مع حفظها في `SharedPreferences`
  void changeLanguage(String languageCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', languageCode);
    setState(() {
      _locale = Locale(languageCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit( // ✅ Initialize ScreenUtil
      designSize: const Size(375, 812), // ✅ Standard reference size (iPhone X)
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Directionality(
          textDirection: _locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: MaterialApp(
              builder: (context, child) {
                // ✅ Use Builder to get context for Connectivity
                return Stack(
                  children: [
                    child!,
                    StreamBuilder<ConnectionStatus>(
                      stream: ConnectivityService().connectionStream,
                      initialData: ConnectionStatus.online,
                      builder: (context, snapshot) {
                        final isOffline = snapshot.data == ConnectionStatus.offline;
                        return Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: OfflineBanner(isOffline: isOffline),
                        );
                      },
                    ),
                  ],
                );
              },
              navigatorKey: _navKey,
              debugShowCheckedModeBanner: false,
              theme: ThemeData(

                cupertinoOverrideTheme: const NoDefaultCupertinoThemeData(
                  primaryColor: AppColors.main,
                ),

                primarySwatch: Colors.teal,

                // ✅ تأثير الضغط المطول لكل الأزرار
                textButtonTheme: TextButtonThemeData(
                  style: ButtonStyle(
                    overlayColor: WidgetStateProperty.all(AppColors.main.withOpacity(0.08)),
                  ),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: ButtonStyle(
                    overlayColor: WidgetStateProperty.all(AppColors.main.withOpacity(0.08)),
                  ),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(AppColors.main),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
                    overlayColor: WidgetStateProperty.all(AppColors.main.withOpacity(0.08)),
                  ),
                ),

                splashColor: AppColors.main.withOpacity(0.1),
                highlightColor: AppColors.main.withOpacity(0.05),
                splashFactory: InkRipple.splashFactory,

                /// ✅ Use responsive font family based on the selected language
                fontFamily: _locale.languageCode == 'ar' ? 'Cairo' : 'Montserrat',

                popupMenuTheme: PopupMenuThemeData(
                  color: Colors.white.withOpacity(0.95),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  textStyle: TextStyle(
                    fontSize: 12.sp,
                    fontFamily: _locale.languageCode == 'ar' ? 'Cairo' : 'Montserrat',
                    color: Colors.black87,
                  ),
                  elevation: 4,
                ),
                /// ✅ Global Input Field Theme
                inputDecorationTheme: InputDecorationTheme(
                  labelStyle: TextStyle(color: Colors.grey, fontSize: 12.sp), // ✅ لون اللابل دائمًا رمادي
                  floatingLabelStyle: const TextStyle(color: AppColors.main),
                  hintStyle: const TextStyle(color: Colors.grey),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.r),
                    borderSide: const BorderSide(color: AppColors.main, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.r),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                ),

                /// ✅ Set Cursor and Selection Color
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: AppColors.main, // 🔹 لون المؤشر
                  selectionColor: AppColors.main.withOpacity(0.25), // 🔹 لون خلفية التحديد (بدل البنفسجي)
                  selectionHandleColor: AppColors.main, // 🔹 لون المقابض الصغيرة عند تحديد النص
                ),
              ),

              // ✅ Localization setup
              locale: _locale,
              supportedLocales: const [Locale('en'), Locale('ar')],
              // localizationsDelegates: AppLocalizations.localizationsDelegates,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                quill.FlutterQuillLocalizations.delegate, // لازم تعمل import لـ flutter_quill
              ],


              // ✅ Fallback for unsupported locales
              localeResolutionCallback: (locale, supportedLocales) {
                if (locale == null) return const Locale('en');
                for (var supportedLocale in supportedLocales) {
                  if (supportedLocale.languageCode == locale.languageCode) {
                    return supportedLocale;
                  }
                }
                return const Locale('en'); // ✅ Default to English
              },

              // ✅ Make the app title support localization
              onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,

              home: const SplashScreen(),

              routes: {
                "/login": (context) => const LogInPage(),
                "/identification": (context) => const IdentificationPage(),
              },
            ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// 🇸🇾 Custom HTTP Client for Syria (Slow Internet Resilience)
// -----------------------------------------------------------------------------
class _SyriaClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Force 30-second timeout on all requests
    return _inner.send(request).timeout(const Duration(seconds: 30));
  }
}
