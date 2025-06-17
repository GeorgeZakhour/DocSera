import 'package:docsera/Business_Logic/Account_page/user_cubit.dart';
import 'package:docsera/Business_Logic/Appointments_page/appointments_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/Business_Logic/Available_appointments_page/doctor_schedule_cubit.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_cubit.dart';
import 'package:docsera/Business_Logic/Documents_page/notes/notes_cubit.dart';
import 'package:docsera/Business_Logic/Main_page/main_screen_cubit.dart';
import 'package:docsera/Business_Logic/Messages_page/messages_cubit.dart';
import 'package:docsera/services/firestore/firestore_user_service.dart';
import 'package:docsera/splash_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/auth/login/login_page.dart';
import 'package:docsera/screens/auth/identification_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'Business_Logic/Authentication/auth_cubit.dart';
import 'app/const.dart';
import 'package:firebase_app_check/firebase_app_check.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await FirebaseAppCheck.instance.activate(
    androidProvider: kReleaseMode
        ? AndroidProvider.playIntegrity
        : AndroidProvider.debug,
  );

  // ✅ اطبع التوكين لتتأكد إنو App Check شغال
  FirebaseAppCheck.instance.getToken(true).then((token) =>
      print("🔒 AppCheck token: $token"));

  SharedPreferences prefs = await SharedPreferences.getInstance();
  FirestoreUserService firestoreService = FirestoreUserService();
  // ✅ تحميل اللغة المحفوظة مسبقًا
  final savedLocale = await getSavedLocale();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(),
        ),
        BlocProvider<MainScreenCubit>(
          create: (context) => MainScreenCubit(firestoreService, prefs),
        ),
        BlocProvider(
          create: (context) => AppointmentsCubit(firestoreService, prefs),
        ),
        BlocProvider(create: (context) => MessagesCubit()),
        BlocProvider(create: (context) => DocumentsCubit()),
        BlocProvider(create: (context) => UserCubit(firestoreService, prefs)),
        BlocProvider(create: (context) => DoctorScheduleCubit()),
        BlocProvider(create: (context) => NotesCubit()),

      ],
      // ✅ هنا نلف الـ MyApp بـ BlocListener
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          context.read<MainScreenCubit>().loadMainScreen(context);
          context.read<AppointmentsCubit>().loadAppointments(context);
          context.read<DocumentsCubit>().listenToDocuments(context);
          context.read<NotesCubit>().listenToNotes(context);
          context.read<UserCubit>().loadUserData(context);
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

  @override
  void initState() {
    super.initState();
    _locale = Locale(widget.savedLocale);
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
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.teal,

              // ✅ تأثير الضغط المطول لكل الأزرار
              textButtonTheme: TextButtonThemeData(
                style: ButtonStyle(
                  overlayColor: MaterialStateProperty.all(AppColors.main.withOpacity(0.08)),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: ButtonStyle(
                  overlayColor: MaterialStateProperty.all(AppColors.main.withOpacity(0.08)),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(AppColors.main),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                  overlayColor: MaterialStateProperty.all(AppColors.main.withOpacity(0.08)),
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
                floatingLabelStyle: TextStyle(color: AppColors.main),
                hintStyle: TextStyle(color: Colors.grey),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.r),
                  borderSide: BorderSide(color: AppColors.main, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.r),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
              ),

              /// ✅ Set Cursor and Selection Color
              textSelectionTheme: TextSelectionThemeData(
                cursorColor: AppColors.main,
                selectionColor: AppColors.main.withOpacity(0.3),
                selectionHandleColor: AppColors.main,
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

            home: SplashScreen(),

            routes: {
              "/login": (context) => const LogInPage(),
              "/identification": (context) => const IdentificationPage(),
            },
          ),
        );
      },
    );
  }
}
