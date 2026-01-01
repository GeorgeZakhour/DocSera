
import 'package:bloc_test/bloc_test.dart';
import 'package:docsera/Business_Logic/Account_page/danger/account_danger_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/profile/account_profile_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/relatives/relatives_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/security/account_security_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/user_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/user_state.dart';
import 'package:docsera/Business_Logic/Appointments_page/appointments_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Available_appointments_page/doctor_schedule_cubit.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart' as custom_auth;
import 'package:docsera/Business_Logic/Documents_page/notes/notes_cubit.dart';
import 'package:docsera/Business_Logic/Health_page/patient_switcher_cubit.dart';
import 'package:docsera/Business_Logic/Main_page/main_screen_cubit.dart';
import 'package:docsera/Business_Logic/Messages_page/messages_cubit.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/main.dart';
import 'package:docsera/services/supabase/user/account_danger_service.dart';
import 'package:docsera/services/supabase/user/account_profile_service.dart';
import 'package:docsera/screens/auth/login/login_start.dart';
import 'package:docsera/services/supabase/user/account_relatives_service.dart';
import 'package:docsera/services/supabase/user/account_security_service.dart';
import 'package:docsera/widgets/main_screen_widgets.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mocks
class MockSupabaseUserService extends Mock implements SupabaseUserService {}
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockAuth extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {
  @override
  String get id => 'test-user-id';
}
// Mock Services needed for other Cubits
class MockAccountProfileService extends Mock implements AccountProfileService {}
class MockAccountRelativesService extends Mock implements AccountRelativesService {}
class MockAccountSecurityService extends Mock implements AccountSecurityService {}
class MockAccountDangerService extends Mock implements AccountDangerService {}

void main() {
  late MockSupabaseUserService mockUserService;
  late MockSupabaseClient mockSupabaseClient;
  late MockAuth mockAuth;
  late SharedPreferences mockPrefs;
  
  const authUser = User(
      id: "test-user-id",
      appMetadata: {},
      userMetadata: {},
      aud: "authenticated",
      createdAt: "2024-01-01",
  );

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    
    // Mock Package Info
    const MethodChannel('dev.fluttercommunity.plus/package_info').setMockMethodCallHandler((MethodCall methodCall) async {
      return <String, dynamic>{
        'appName': 'DocSera',
        'packageName': 'com.docsera.app',
        'version': '1.0.0',
        'buildNumber': '1',
      };
    });

    // Mock App Links methods (getInitialLink often uses method channel)
    const MethodChannel('com.llfbandit.app_links/methods').setMockMethodCallHandler((MethodCall methodCall) async {
       return null;
    });
    
    // Existing mocks...
    const MethodChannel('plugins.flutter.io/local_auth').setMockMethodCallHandler((MethodCall methodCall) async {
      return <String>[];
    });
    const MethodChannel('com.llfbandit.app_links/events').setMockMethodCallHandler((MethodCall methodCall) async {
      return null;
    });
    const MethodChannel('com.llfbandit.app_links/messages').setMockMethodCallHandler((MethodCall methodCall) async {
      return null;
    });

    registerFallbackValue(NotLogged());
  });

  setUp(() async {
    mockUserService = MockSupabaseUserService();
    mockSupabaseClient = MockSupabaseClient();
    mockAuth = MockAuth();
    mockPrefs = await SharedPreferences.getInstance();

    when(() => mockSupabaseClient.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(null);
    when(() => mockAuth.currentSession).thenReturn(null);
    when(() => mockAuth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    when(() => mockUserService.getCurrentUser()).thenReturn(null);
    
    // Auth Mock
    when(() => mockUserService.signInWithPassword(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => AuthResponse(
              session: Session(accessToken: 'token', tokenType: 'bearer', user: MockUser()),
              user: MockUser(),
            ));
            
    // User Data Mock
    when(() => mockUserService.getUserData(any())).thenAnswer((_) async => {'first_name': 'Test', 'last_name': 'User', 'points': 100});
    when(() => mockUserService.getLoginInfoByEmailOrPhone(any()))
        .thenAnswer((_) async => {'email': 'test@docsera.com', 'is_active': true, 'user_id': 'test-user'});
    when(() => mockUserService.getMySecurityState())
        .thenAnswer((_) async => {'two_factor_auth_enabled': false, 'trusted_devices': [], 'phone_number': '123456'});
  });

  Widget createWidgetUnderTest() {
    return RepositoryProvider<SupabaseUserService>.value(
      value: mockUserService,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(create: (_) => AuthCubit(prefs: mockPrefs, supabase: mockSupabaseClient)),
          BlocProvider<MainScreenCubit>(create: (_) => MainScreenCubit(mockUserService, mockPrefs)),
          BlocProvider(create: (_) => AppointmentsCubit(mockUserService, mockPrefs)),
          BlocProvider(create: (_) => MessagesCubit(supabase: mockSupabaseClient)),
          BlocProvider(create: (_) => DocumentsCubit()),
          BlocProvider(create: (_) => UserCubit(mockUserService, mockPrefs)),
          BlocProvider(create: (_) => AccountProfileCubit(service: MockAccountProfileService())),
          BlocProvider(create: (_) => RelativesCubit(MockAccountRelativesService())),
          BlocProvider(create: (_) => AccountSecurityCubit(service: MockAccountSecurityService())),
          BlocProvider(create: (_) => AccountDangerCubit(service: MockAccountDangerService())),
          BlocProvider(create: (_) => DoctorScheduleCubit()),
          BlocProvider(create: (_) => NotesCubit()),
          BlocProvider(create: (_) => PatientSwitcherCubit()),
        ],
        child: BlocListener<AuthCubit, custom_auth.AppAuthState>(
          listener: (context, state) {
             if (state is custom_auth.AuthAuthenticated) {
              context.read<MainScreenCubit>().loadMainScreen(context);
             }
          },
          child: MyApp(
             savedLocale: 'en',
             supabaseClient: mockSupabaseClient,
          ),
        ),
      ),
    );
  }

  testWidgets('Integration: Login Flow', (WidgetTester tester) async {
    // Set a realistic screen size (iPhone 14 Pro ish)
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;

    // Reset view on tear down
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Seed Banner Color Cache to avoid 15s timer
    BannerColorCache.seedCache({
       'assets/images/worker.webp': Colors.blue,
       'assets/images/professional.jpg': Colors.orange,
    }); // Add seeded colors

    await tester.pumpWidget(createWidgetUnderTest());
    // Splash Screen has ~4 seconds of animation
    await tester.pump(const Duration(seconds: 6)); 
    await tester.pump(); // Pump one frame to ensure navigation completes

    // 1. Verify Login Page
    // "Log in" appears in title and button.
    expect(find.text('Log in'), findsAtLeastNWidgets(1)); 
    
    // 2. Interact
    // Input fields: Email/Phone (first), Password (second/last)
    // There are 2 TextFields.
    await tester.enterText(find.byType(TextField).at(0), 'test@docsera.com');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    
    // Tap Login Button
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    
    // Simulate Auth State Change
    when(() => mockAuth.currentUser).thenReturn(authUser);
    when(() => mockUserService.getCurrentUser()).thenReturn(authUser);

    await tester.pump(); // Start process
    
    // 3. Verify Navigation
    // Login is async (calls service). pump(Duration) to wait for async work.
    await tester.pump(const Duration(milliseconds: 200)); 
    // Advance time for navigation animation and banner loop (3 * 300ms)
    await tester.pump(const Duration(seconds: 3)); 
    await tester.pump(); 

    // Expect to be on Home Screen (CustomBottomNavigationBar)
    expect(find.byType(CustomBottomNavigationBar), findsOneWidget);
    
    // LoginPage should be gone.
    expect(find.byType(LoginPage), findsNothing);

    // 4. Force Disposal of everything to kill periodic timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
