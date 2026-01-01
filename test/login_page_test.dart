import 'package:bloc_test/bloc_test.dart';
import 'package:docsera/Business_Logic/Account_page/user_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/user_state.dart';
import 'package:docsera/screens/auth/login/login_page.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

// Mocks
class MockSupabaseUserService extends Mock implements SupabaseUserService {}
class MockUserCubit extends MockCubit<UserState> implements UserCubit {}

void main() {
  late MockSupabaseUserService mockUserService;
  late MockUserCubit mockUserCubit;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(NotLogged());
    const MethodChannel('plugins.flutter.io/local_auth').setMockMethodCallHandler((MethodCall methodCall) async {
      return <String>[];
    });
  });

  setUp(() {
    mockUserService = MockSupabaseUserService();
    mockUserCubit = MockUserCubit();

    // Mock getCurrentUser to return null (not logged in)
    when(() => mockUserService.getCurrentUser()).thenReturn(null);
  });

  Widget createWidgetUnderTest() {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, child) => MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        locale: const Locale('en'),
        home: RepositoryProvider<SupabaseUserService>.value(
          value: mockUserService,
          child: BlocProvider<UserCubit>.value(
            value: mockUserCubit,
            child: const LogInPage(),
          ),
        ),
      ),
    );
  }

  testWidgets('LoginPage renders correctly', (WidgetTester tester) async {
    // Handling MissingPluginException for BiometricStorage is tricky.
    // We assume the test environment might ignore it or we might need to mock channel.
    // For now, let's try to run and see. If it fails, we will mock the channel.

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsWidgets); // Title and Header
    expect(find.text('Email or Phone Number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('Login button is disabled initially and enabled when input is valid', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.enabled, isFalse);

    await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.pump();

    final buttonEnabled = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(buttonEnabled.enabled, isTrue);
  });
}
