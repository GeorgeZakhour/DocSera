
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';
import 'package:docsera/services/supabase/repositories/auth_repository.dart';
import 'package:docsera/services/supabase/repositories/user_repository.dart';
import 'package:docsera/services/supabase/repositories/favorites_repository.dart';
import 'package:docsera/services/supabase/repositories/appointment_repository.dart';

// Mocks
class MockAuthRepository extends Mock implements AuthRepository {}
class MockUserRepository extends Mock implements UserRepository {}
class MockFavoritesRepository extends Mock implements FavoritesRepository {}
class MockAppointmentRepository extends Mock implements AppointmentRepository {}

void main() {
  late MockAuthRepository mockAuth;
  late MockUserRepository mockUser;
  late MockFavoritesRepository mockFavorites;
  late MockAppointmentRepository mockAppointments;
  late SupabaseUserService userService;

  setUp(() {
    mockAuth = MockAuthRepository();
    mockUser = MockUserRepository();
    mockFavorites = MockFavoritesRepository();
    mockAppointments = MockAppointmentRepository();
    
    userService = SupabaseUserService(
      auth: mockAuth,
      user: mockUser,
      favorites: mockFavorites,
      appointments: mockAppointments,
    );
  });

  group('SupabaseUserService - Facade Delegation', () {
    test('deleteUserAccount delegates to AuthRepository', () async {
      // Arrange
      when(() => mockAuth.deleteUserAccount()).thenAnswer((_) async {});

      // Act
      await userService.deleteUserAccount();

      // Assert
      verify(() => mockAuth.deleteUserAccount()).called(1);
    });

    test('getUserData delegates to UserRepository', () async {
      // Arrange
      when(() => mockUser.getUserData(any())).thenAnswer((_) async => {});

      // Act
      await userService.getUserData('123');

      // Assert
      verify(() => mockUser.getUserData('123')).called(1);
    });

    test('getFavoriteDoctors delegates to FavoritesRepository', () async {
       // Arrange
      when(() => mockFavorites.getFavoriteDoctors()).thenAnswer((_) async => []);

      // Act
      await userService.getFavoriteDoctors();

      // Assert
      verify(() => mockFavorites.getFavoriteDoctors()).called(1);
    });

    test('getUserAppointments delegates to AppointmentRepository', () async {
       // Arrange
      when(() => mockAppointments.getUserAppointments(any())).thenAnswer((_) async => {'upcoming': [], 'past': []});

      // Act
      await userService.getUserAppointments('123');

      // Assert
      verify(() => mockAppointments.getUserAppointments('123')).called(1);
    });
  });
}
