import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreOTPService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// **إرسال رمز OTP إلى رقم الهاتف**
  Future<String> sendOTPToPhone(String phoneNumber) async {
    try {
      final otp = _generateOTP();
      await _firestore.collection('otp').doc(phoneNumber).set({
        'otp': otp,
        'expiresAt': Timestamp.now().toDate().add(const Duration(minutes: 5)),
      });

      print('OTP sent to phone: $phoneNumber, Code: $otp');

      return otp;
    } catch (e) {
      throw Exception('Failed to send OTP to phone: $e');
    }
  }

  Future<String> sendOTPToEmail(String email) async {
    final otp = _generateOTP();
    try {
      await _firestore.collection('email_otp').doc(email).set({
        'otp': otp,
        'expiresAt': Timestamp.now().toDate().add(const Duration(minutes: 5)), // ✅ Consistent field
      });

      print('📧 OTP sent to email: $email, Code: $otp');
      return otp;
    } catch (e) {
      throw Exception('Failed to send OTP to Email: ${e.toString()}');
    }
  }

  Future<bool> validateOTP(String identifier, String otp) async {
    try {
      bool isEmail = identifier.contains('@');
      String collection = isEmail ? 'email_otp' : 'otp';

      final otpDoc = await _firestore.collection(collection).doc(identifier).get();

      if (!otpDoc.exists) return false;

      final data = otpDoc.data()!;
      final storedOTP = data['otp'];
      final expiresAt = data['expiresAt'];

      if (expiresAt == null) {
        print("❌ Missing expiresAt in Firestore document");
        return false;
      }

      bool isValid = storedOTP == otp && DateTime.now().isBefore((expiresAt as Timestamp).toDate());

      print("✅ Stored OTP: $storedOTP, Entered OTP: $otp, Valid: $isValid");

      return isValid;
    } catch (e) {
      throw Exception('Failed to validate OTP: $e');
    }
  }

  /// **توليد رمز OTP عشوائي مكون من 6 أرقام**
  String _generateOTP() {
    final random = Random();
    return (random.nextInt(900000) + 100000).toString();
  }
}