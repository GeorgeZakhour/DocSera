import 'dart:async';
import 'dart:io';

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



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones(); // 👈 مهم جداً لمرة واحدة فقط

  await Supabase.initialize(
    url: SupabaseKeys.supabaseUrl,
    anonKey: SupabaseKeys.supabaseAnonKey,
  );


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

  // ✅ يحفّز ظهور نافذة Local Network على iOS
await Socket.connect('192.168.1.1', 80, timeout: const Duration(seconds: 1))
    .then((socket) {
  log('Connected to local network');
  socket.destroy();
}).catchError((e) {
  log('Failed to connect — still triggers prompt');
});



  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(create: (_) => AuthCubit()),
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
            context.read<AppointmentsCubit>().loadAppointments(context);
            context.read<DocumentsCubit>().listenToDocuments(context);
            context.read<NotesCubit>().listenToNotes(context);

            final userCubit = context.read<UserCubit>();
            userCubit.loadUserData(context, useCache: true);
            userCubit.startRealtimeUserListener(state.user.id);

            final userState = userCubit.state;
            if (userState is UserLoaded) {
              context.read<PatientSwitcherCubit>().switchToUser();
            }
          }
        },
        child: MyApp(savedLocale: savedLocale),
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

  const MyApp({super.key, required this.savedLocale});

  static _MyAppState? of(BuildContext context) => context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Locale _locale;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;


  @override
  void initState() {
    super.initState();
    _locale = Locale(widget.savedLocale);
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }


  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // 🔹 1) App opened from terminated state
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      log('❌ getInitialAppLink error: $e');
    }

    // 🔹 2) App already running
    _linkSub = _appLinks.uriLinkStream.listen(
          (uri) {
        _handleUri(uri);
      },
      onError: (err) {
        log('❌ uriLinkStream error: $err');
      },
    );
  }

  void _handleUri(Uri uri) {
    String? doctorToken;

    // docsera://doctor/<public_token>
    if (uri.scheme == 'docsera') {
      if (uri.host == 'doctor' && uri.pathSegments.isNotEmpty) {
        doctorToken = uri.pathSegments.first;
      }
    }

    // https://docsera.app/doctor/<public_token> (للمستقبل)
    if (uri.scheme.startsWith('http')) {
      if (uri.pathSegments.length >= 2 &&
          uri.pathSegments.first == 'doctor') {
        doctorToken = uri.pathSegments[1];
      }
    }

    if (doctorToken == null || doctorToken.isEmpty) {
      log('⚠️ Ignored deep link: $uri');
      return;
    }

    _resolveDoctorByPublicToken(doctorToken);
  }

  Future<void> _resolveDoctorByPublicToken(String token) async {
    try {
      final res = await Supabase.instance.client
          .from('doctors')
          .select('id')
          .eq('public_token', token)
          .maybeSingle();

      if (res == null) {
        log('❌ Invalid doctor public_token: $token');
        return;
      }

      final doctorId = res['id'] as String;

      _navigateToDoctor(doctorId);
    } catch (e) {
      log('❌ Failed to resolve doctor token: $e');
    }
  }

  void _navigateToDoctor(String doctorId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _navKey.currentState;
      if (nav == null) return;

      nav.push(
        MaterialPageRoute(
          builder: (_) => DoctorProfilePage(
            doctorId: doctorId,
          ),
        ),
      );
    });
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
