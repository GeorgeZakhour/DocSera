import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/models/sign_up_info.dart';

void main() {
  group('SignUpInfo', () {
    test('default constructor produces phone-OTP method with no fields set',
        () {
      final s = SignUpInfo();
      expect(s.authMethod, AuthMethod.phoneOtp);
      expect(s.email, isNull);
      expect(s.phoneNumber, isNull);
      expect(s.firstName, isNull);
      expect(s.lastName, isNull);
      expect(s.dateOfBirth, isNull);
      expect(s.gender, isNull);
      expect(s.termsAccepted, false);
      expect(s.marketingChecked, false);
      expect(s.isCrossApp, false);
      expect(s.emailVerified, false);
      expect(s.phoneVerified, false);
    });

    test('AuthMethod enum has expected values', () {
      expect(AuthMethod.values, [AuthMethod.phoneOtp, AuthMethod.emailPassword]);
    });

    test('mutable fields can be set after construction', () {
      final s = SignUpInfo()
        ..authMethod = AuthMethod.emailPassword
        ..email = 'x@y.com'
        ..firstName = 'Jane'
        ..termsAccepted = true
        ..emailVerified = true;
      expect(s.authMethod, AuthMethod.emailPassword);
      expect(s.email, 'x@y.com');
      expect(s.firstName, 'Jane');
      expect(s.termsAccepted, true);
      expect(s.emailVerified, true);
    });

    test('constructor named args populate fields', () {
      final s = SignUpInfo(
        email: 'a@b.c',
        phoneNumber: '+963',
        firstName: 'A',
        lastName: 'B',
        gender: 'female',
        termsAccepted: true,
        marketingChecked: true,
        isCrossApp: true,
        referralCode: 'R1',
      );
      expect(s.email, 'a@b.c');
      expect(s.phoneNumber, '+963');
      expect(s.firstName, 'A');
      expect(s.lastName, 'B');
      expect(s.gender, 'female');
      expect(s.termsAccepted, true);
      expect(s.marketingChecked, true);
      expect(s.isCrossApp, true);
      expect(s.referralCode, 'R1');
    });
  });
}
