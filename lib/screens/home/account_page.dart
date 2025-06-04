import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/main.dart';
import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';
import 'package:docsera/utils/custom_clippers.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart'; //
import 'package:docsera/screens/home/account/user_profile_page.dart';
import 'package:docsera/screens/home/account/my_relatives.dart';
import 'package:docsera/services/firestore/firestore_otp_service.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/utils/input_decoration.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../Business_Logic/Account_page/user_cubit.dart';
import '../../Business_Logic/Account_page/user_state.dart';



class AccountScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const AccountScreen({super.key, required this.onLogout});

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool isFaceIdEnabled = false;
  final LocalAuthentication auth = LocalAuthentication();
  String biometricType = "Biometric Authentication"; // Default fallback
  IconData biometricIcon = Icons.fingerprint; // Default icon
  bool _biometricChecked = false;
  String currentLocale = "en"; // Default

  @override
  void initState() {
    super.initState();
    _loadFaceIdPreference();

    Future.delayed(Duration.zero, () async {
      final prefs = await SharedPreferences.getInstance();
      final userCubit = context.read<UserCubit>();
      await userCubit.loadUserData(context, useCache: true);
      userCubit.startListeningToUserChanges(); // ✅ Add this
    });
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    String newLocale = Localizations.localeOf(context).languageCode;

    if (!_biometricChecked || newLocale != currentLocale) {
      currentLocale = newLocale; // Update stored locale
      Future.delayed(Duration.zero, _detectBiometricType); // ✅ Ensure localization is loaded
      _biometricChecked = true;
    }
  }



  Future<void> _loadFaceIdPreference() async {
    final prefs = await SharedPreferences.getInstance();
    bool isEnabled = prefs.getBool('enableFaceID') ?? false;

    setState(() {
      isFaceIdEnabled = isEnabled;
    });

    print("🟢 [DEBUG] Face ID Enabled: $isFaceIdEnabled");
  }


  Future<void> _detectBiometricType() async {
    try {
      List<BiometricType> availableBiometrics = await auth.getAvailableBiometrics();
      if (!mounted) return;

      print("✅ Available Biometrics: $availableBiometrics");

      String detectedType;
      IconData detectedIcon;

      if (Platform.isIOS) {
        if (availableBiometrics.contains(BiometricType.face)) {
          detectedType = AppLocalizations.of(context)!.faceIdTitle;
          detectedIcon = Icons.face;
        } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
          detectedType = AppLocalizations.of(context)!.fingerprintTitle;
          detectedIcon = Icons.fingerprint;
        } else {
          detectedType = AppLocalizations.of(context)!.biometricTitle;
          detectedIcon = Icons.lock;
        }
      } else if (Platform.isAndroid) {
        if (availableBiometrics.contains(BiometricType.strong)) {
          detectedType = AppLocalizations.of(context)!.fingerprintTitle;
          detectedIcon = Icons.fingerprint;
        } else if (availableBiometrics.contains(BiometricType.weak)) {
          detectedType = AppLocalizations.of(context)!.faceIdTitle;
          detectedIcon = Icons.face;
        } else {
          detectedType = AppLocalizations.of(context)!.biometricTitle;
          detectedIcon = Icons.lock;
        }
      } else {
        detectedType = AppLocalizations.of(context)!.biometricTitle;
        detectedIcon = Icons.lock;
      }

      // ✅ Save biometric type in SharedPreferences for login page
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('biometricType', detectedType);

      setState(() {
        biometricType = detectedType;
        biometricIcon = detectedIcon;
      });

      print("✅ Biometric Type Set & Saved: $biometricType");
    } catch (e) {
      print("❌ Biometric detection error: $e");
    }
  }








  Future<bool> _authenticateWithFaceID() async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: AppLocalizations.of(context)!.faceIdPrompt,
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
      return authenticated;
    } catch (e) {
      print("❌ Face ID Error: $e");
      return false;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }


  ///====================================================///


  String _formatPhoneForDisplay(String rawPhone) {
    if (rawPhone.startsWith('00963')) {
      return '0${rawPhone.substring(5)}'; // يحول 0096398765432 → 098765432
    }
    return rawPhone;
  }

  String _formatPhoneForBackend(String input) {
    String phone = input.trim();
    if (phone.startsWith('09')) {
      phone = phone.substring(1); // Remove the 0
    } else if (phone.startsWith('9')) {
      // Do nothing
    } else {
      return phone; // Invalid format, return as-is to be handled by validation
    }
    return "00963$phone";
  }

  Future<bool> _isPhoneNumberDuplicate(String phone) async {
    String formatted = _formatPhoneForBackend(phone);
    String fakeEmail = "$formatted@docsera.com";
    final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(fakeEmail);
    return methods.isNotEmpty;
  }

  bool _isValidPhoneNumber(String input) {
    if (!input.startsWith('9') && !input.startsWith('09')) return false;
    int requiredLength = input.startsWith('09') ? 10 : 9;
    return input.length == requiredLength;
  }


  void _showEditFieldSheet(BuildContext context, String fieldType, String currentValue) {
    final state = context.read<UserCubit>().state;
    if (state is! UserLoaded) return;

    final TextEditingController fieldController = TextEditingController(
      text: fieldType == 'phoneNumber'
          ? _formatPhoneForDisplay(state.userPhone)
          : state.userEmail ?? '',
    );

    bool isFieldChanged = false;
    String? errorMessage;
    bool isChecking = false;
    bool isValidPhone = fieldType == 'phoneNumber'
        ? _isValidPhoneNumber(fieldController.text.trim())
        : false;
    bool isValidEmail = fieldType == 'email'
        ? RegExp(r'^[^@]+@[^@]+\.[^@]+\$').hasMatch(fieldController.text.trim())
        : false;

    String originalUnverifiedValue = fieldController.text;
    bool isNotVerified = (fieldType == 'phoneNumber' && !state.isPhoneVerified);

    String title = fieldType == 'phoneNumber'
        ? AppLocalizations.of(context)!.editPhoneNumber
        : AppLocalizations.of(context)!.editEmail;
    String hintText = fieldType == 'phoneNumber'
        ? AppLocalizations.of(context)!.newPhoneNumber
        : AppLocalizations.of(context)!.newEmailAddress;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Container(
            padding: EdgeInsets.all(16.w),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title, style: AppTextStyles.getTitle1(context)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: fieldController,
                      keyboardType: fieldType == 'phoneNumber'
                          ? TextInputType.phone
                          : TextInputType.emailAddress,
                      textDirection: detectTextDirection(fieldController.text),
                      textAlign: getTextAlign(context),
                      style: AppTextStyles.getText1(context),
                      maxLength: fieldType == 'phoneNumber' ? 10 : 100,
                      decoration: getInputDecoration(hintText: hintText).copyWith(
                        errorText: errorMessage,
                        counterText: "",
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (fieldType == 'phoneNumber' &&
                                fieldController.text.isNotEmpty &&
                                fieldController.text.trim() != _formatPhoneForDisplay(state.userPhone))
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6.w),
                                child: Container(
                                  width: 20.w,
                                  height: 20.w,
                                  decoration: BoxDecoration(
                                    color: isValidPhone ? AppColors.main.withOpacity(0.8) : AppColors.red.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isValidPhone ? Icons.check : Icons.close,
                                    color: Colors.white,
                                    size: 14.sp,
                                  ),
                                ),
                              ),
                            if (isNotVerified)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                                margin: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  color: AppColors.yellow.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.notVerified,
                                  style: AppTextStyles.getText3(context).copyWith(
                                      color: AppColors.yellow,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          isFieldChanged = value.trim().isNotEmpty;
                          errorMessage = null;
                          isValidPhone = fieldType == 'phoneNumber'
                              ? _isValidPhoneNumber(value.trim())
                              : false;

                          isNotVerified = (value.trim() == originalUnverifiedValue &&
                              fieldType == 'phoneNumber' &&
                              !state.isPhoneVerified);
                        });
                      },
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: !isChecking
                          ? () async {
                        String newValue = fieldController.text.trim();

                        if (fieldType == 'phoneNumber' &&
                            !_isValidPhoneNumber(newValue)) {
                          setState(() {
                            errorMessage = AppLocalizations.of(context)!
                                .invalidPhoneNumber;
                          });
                          return;
                        }

                        if (newValue == originalUnverifiedValue &&
                            isNotVerified &&
                            fieldType == 'phoneNumber') {
                          Navigator.pop(context);
                          _sendOTPAndShowSheet(context, newValue, fieldType,
                              originalUnverifiedValue,
                              allowSkip: true);
                          return;
                        }

                        if (newValue == originalUnverifiedValue &&
                            !isNotVerified) {
                          setState(() {
                            errorMessage = fieldType == 'phoneNumber'
                                ? 'This phone is the one you are currently using'
                                : 'This email is the one you are currently using';
                          });
                          return;
                        }

                        setState(() => isChecking = true);

                        bool isDuplicate = false;
                        if (fieldType == 'phoneNumber') {
                          isDuplicate = await _isPhoneNumberDuplicate(newValue);
                        }

                        setState(() => isChecking = false);

                        if (isDuplicate) {
                          setState(() {
                            errorMessage = fieldType == 'phoneNumber'
                                ? AppLocalizations.of(context)!.alreadyExistsPhone
                                : AppLocalizations.of(context)!.alreadyExistsEmail;
                          });
                        } else {
                          Navigator.pop(context);
                          _sendOTPAndShowSheet(context, newValue, fieldType,
                              originalUnverifiedValue,
                              allowSkip: fieldType == 'phoneNumber');
                        }
                      }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        isNotVerified && fieldType == 'phoneNumber'
                            ? AppColors.mainDark
                            : AppColors.main,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size(double.infinity, 50.h),
                      ),
                      child: isChecking
                          ? SizedBox(
                        width: 16.w,
                        height: 16.h,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Text(
                        isNotVerified && fieldType == 'phoneNumber'
                            ? AppLocalizations.of(context)!.verify
                            : AppLocalizations.of(context)!.save,
                        style: AppTextStyles.getTitle2(context)
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _sendOTPAndShowSheet(BuildContext context, String newValue, String fieldType, String oldValue, {bool allowSkip = false}) async {
    final otpService = FirestoreOTPService();
    String sentOTP = fieldType == 'phoneNumber'
        ? await otpService.sendOTPToPhone(newValue)
        : await otpService.sendOTPToEmail(newValue);

    final TextEditingController otpController = TextEditingController();
    bool isCodeValid = true;
    int timerSeconds = 60;
    bool canResend = false;
    Timer? resendTimer;

    if (!context.mounted) return; // ✅ Ensure widget is mounted before proceeding

    void startTimer(Function updateUI) {
      resendTimer?.cancel();
      resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (timerSeconds > 0) {
          updateUI(() => timerSeconds--);
        } else {
          timer.cancel();
          updateUI(() => canResend = true);
        }
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (resendTimer == null) startTimer(setState);

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.pleaseConfirm(
                              fieldType == 'phoneNumber'
                                  ? AppLocalizations.of(context)!.phone
                                  : AppLocalizations.of(context)!.email
                          ),
                          style: AppTextStyles.getTitle1(context),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            resendTimer?.cancel();
                            Navigator.pop(context);
                          },
                        )
                      ],
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: otpController,
                      textDirection: detectTextDirection(otpController.text), // ✅ ضبط الاتجاه ديناميكيًا
                      textAlign: getTextAlign(context),
                      style: AppTextStyles.getText1(context),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: getInputDecoration(hintText: AppLocalizations.of(context)!.sixDigitCode).copyWith(
                        errorText: isCodeValid ? null : 'Invalid code',
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      AppLocalizations.of(context)!.sentVerificationMessage(
                        fieldType == 'phoneNumber'
                            ? AppLocalizations.of(context)!.sms
                            : AppLocalizations.of(context)!.email,
                        newValue,
                      ),
                      style: AppTextStyles.getText3(context),
                    ),
                    SizedBox(height: 4.h),
                    GestureDetector(
                      onTap: canResend
                          ? () async {
                        setState(() {
                          timerSeconds = 60;
                          canResend = false;
                        });
                        startTimer(setState);

                        fieldType == 'phoneNumber'
                            ? await otpService.sendOTPToPhone(newValue)
                            : await otpService.sendOTPToEmail(newValue);
                      }
                          : null,
                      child: Text(
                        canResend
                            ? AppLocalizations.of(context)!.resendCode
                            : AppLocalizations.of(context)!.resendIn(timerSeconds.toString()),
                        style: TextStyle(
                          color: canResend ? AppColors.main : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.sp
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () async {
                        bool isValid = await otpService.validateOTP(newValue, otpController.text.trim());
                        if (isValid) {
                          resendTimer?.cancel();
                          if (context.mounted) { // ✅ Ensure widget is mounted before accessing context
                            // context.read<UserCubit>().updateUserData(fieldType, newValue, isVerified: true);
                            if (fieldType == 'phoneNumber') {
                              String newPhoneFormatted = _formatPhoneForBackend(newValue);




                              await context.read<UserCubit>().updateUserPhone(
                                newPhoneFormatted,
                                isVerified: true,
                              );

                            } else {
                              await context.read<UserCubit>().updateUserData(fieldType, newValue, isVerified: true);
                            }

                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(fieldType == 'phoneNumber'
                                    ? AppLocalizations.of(context)!.phoneUpdatedSuccess
                                    : AppLocalizations.of(context)!.emailUpdatedSuccess),
                                backgroundColor: AppColors.main.withOpacity(0.9),
                              ),
                            );
                          }
                        } else {
                          setState(() {
                            isCodeValid = false;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.main,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                        minimumSize: Size(double.infinity, 50.h),
                      ),
                      child: Text(AppLocalizations.of(context)!.continueButton,
                          style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white)),
                    ),
                    if (allowSkip)
                      TextButton(
                        onPressed: () async {
                          resendTimer?.cancel();
                          if (context.mounted) {
                            Navigator.pop(context);

                            // ✅ Ensure Firestore updates immediately
                            await context.read<UserCubit>().updateUserData(fieldType, newValue, isVerified: false);

                            // 🔥 Force UI to update instantly
                            await context.read<UserCubit>().loadUserData(context);

                            // ✅ Ensure UI feedback appears
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(AppLocalizations.of(context)!.phoneUpdatedWithoutVerification),
                                  backgroundColor: AppColors.yellow.withOpacity(0.8),
                                ),
                              );
                            }
                          }
                        },
                        child: Text(
                          AppLocalizations.of(context)!.verifyLater,
                          style: const TextStyle(color: AppColors.mainDark, fontSize: 11),
                        ),
                      ),





                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _checkForDuplicate(String fieldType, String newValue) async {
    try {
      final state = context.read<UserCubit>().state;
      if (state is! UserLoaded) return false; // ✅ Ensure user is loaded

      print("Checking for duplicate: $fieldType - $newValue"); // ✅ Debug print

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(fieldType, isEqualTo: newValue)
          .get();

      print("Found ${snapshot.docs.length} matching documents");

      // ✅ If there's a user with the same email/phone and it's not the current user
      bool isDuplicate = snapshot.docs.any((doc) => doc.id != state.userId);

      print("Is Duplicate: $isDuplicate");
      return isDuplicate;
    } catch (e) {
      print("Error checking duplicates: $e");
      return false;
    }
  }


  ///====================================================///
  void _showChangePasswordSheet(BuildContext context) {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();

    bool isCurrentPasswordVisible = false;
    bool isNewPasswordVisible = false;
    bool isCurrentPasswordValid = true;
    bool isNewPasswordValid = false;
    bool isNewPasswordDifferent = true;
    String newPasswordStrength = "";
    Color newPasswordStrengthColor = Colors.transparent;
    bool isUpdating = false;

    void _validateNewPassword(String password, Function setState) {
      if (password.isEmpty) {
        setState(() {
          newPasswordStrength = "";
          newPasswordStrengthColor = Colors.transparent;
          isNewPasswordValid = false;
        });
        return;
      }

      final hasUppercase = password.contains(RegExp(r'[A-Z]'));
      final hasLowercase = password.contains(RegExp(r'[a-z]'));
      final hasNumber = password.contains(RegExp(r'[0-9]'));
      final hasSymbol = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      final hasExcessiveRepeatedCharacters =
      password.contains(RegExp(r'(.)\1{2,}')); // Three or more repeated characters
      final isSimplePattern = password.contains(RegExp(r'(abcd|qwerty|1234)')); // Simple patterns

      if (password.length < 8) {
        setState(() {
          newPasswordStrength = AppLocalizations.of(context)!.weakPassword;
          newPasswordStrengthColor = AppColors.red;
          isNewPasswordValid = false;
        });
      }
      // Rule: Simple patterns
      else if (isSimplePattern) {
        setState(() {
          newPasswordStrength = AppLocalizations.of(context)!.weakPassword;
          newPasswordStrengthColor = AppColors.red;
          isNewPasswordValid = false;
        });
      }
      // Rule: Excessive repeated characters (only penalize if password doesn't meet complexity)
      else if (hasExcessiveRepeatedCharacters &&
          (!hasUppercase || !hasLowercase || !hasNumber || !hasSymbol)) {
        setState(() {
          newPasswordStrength = AppLocalizations.of(context)!.fairPassword;
          newPasswordStrengthColor = Colors.orange;
          isNewPasswordValid = false;
        });
      }
      // Rule: Missing complexity
      else if (!hasUppercase || !hasLowercase || !hasNumber || !hasSymbol) {
        setState(() {
          newPasswordStrength = AppLocalizations.of(context)!.fairPassword;
          newPasswordStrengthColor = Colors.orange;
          isNewPasswordValid = false;
        });
      }
      // Rule: Good password (length < 12 but meets complexity)
      else if (password.length < 12) {
        setState(() {
          newPasswordStrength = AppLocalizations.of(context)!.goodPassword;
          newPasswordStrengthColor = Colors.green[300]!;
          isNewPasswordValid = true;
        });
      }
      // Rule: Strong password (length >= 12 and meets complexity)
      else {
        setState(() {
          newPasswordStrength = AppLocalizations.of(context)!.strongPassword;
          newPasswordStrengthColor = Colors.green[800]!;
          isNewPasswordValid = true;
        });
      }
    }


    void _checkPasswordsDifference(Function setState) {
      String currentPassword = currentPasswordController.text.trim();
      String newPassword = newPasswordController.text.trim();

      setState(() {
        isNewPasswordDifferent = currentPassword != newPassword;
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppLocalizations.of(context)!.changePassword, style: AppTextStyles.getTitle1(context)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // ✅ Current Password Field with Smaller Eye Icon
                    TextFormField(
                      controller: currentPasswordController,
                      textDirection: detectTextDirection(currentPasswordController.text), // ✅ ضبط الاتجاه ديناميكيًا
                      textAlign: getTextAlign(context),
                      obscureText: !isCurrentPasswordVisible,
                      onChanged: (value) => _checkPasswordsDifference(setState),
                      decoration: getInputDecoration(hintText: AppLocalizations.of(context)!.currentPassword).copyWith(
                        errorText: isCurrentPasswordValid ? null : AppLocalizations.of(context)!.incorrectCurrentPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            isCurrentPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            size: 16.sp, // Smaller icon
                          ),
                          onPressed: () => setState(() => isCurrentPasswordVisible = !isCurrentPasswordVisible),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // ✅ New Password Field with Smaller Eye Icon
                    TextFormField(
                      controller: newPasswordController,
                      textDirection: detectTextDirection(newPasswordController.text), // ✅ ضبط الاتجاه ديناميكيًا
                      textAlign: getTextAlign(context),
                      obscureText: !isNewPasswordVisible,
                      onChanged: (value) {
                        _validateNewPassword(value, setState);
                        _checkPasswordsDifference(setState);
                      },
                      decoration: getInputDecoration(hintText: AppLocalizations.of(context)!.newPassword).copyWith(
                        errorText: isNewPasswordDifferent ? null : AppLocalizations.of(context)!.passwordMatchError,
                        suffixIcon: IconButton(
                          icon: Icon(
                            isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            size: 16.sp, // Smaller icon
                          ),
                          onPressed: () => setState(() => isNewPasswordVisible = !isNewPasswordVisible),
                        ),
                      ),
                    ),

                    SizedBox(height: 6.h),
                    Text(newPasswordStrength, style: TextStyle(color: newPasswordStrengthColor, fontSize: 12)),

                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: isUpdating || !isNewPasswordDifferent
                          ? null
                          : () async {
                        setState(() => isUpdating = true);

                        String currentPassword = currentPasswordController.text.trim();
                        String newPassword = newPasswordController.text.trim();

                        if (!isNewPasswordValid || !isNewPasswordDifferent) {
                          setState(() => isUpdating = false);
                          return;
                        }

                        bool isValidCurrentPassword = await _validateCurrentPassword(currentPassword);
                        if (!isValidCurrentPassword) {
                          setState(() {
                            isCurrentPasswordValid = false;
                            isUpdating = false;
                          });
                          return;
                        }

                        await _updatePassword(newPassword);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.main,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size(double.infinity, 50.h),
                      ),
                      child: isUpdating
                          ?  SizedBox(
                        width: 16.w,
                        height: 16.h,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                          : Text(AppLocalizations.of(context)!.save
                          ,style: AppTextStyles.getTitle2(context).copyWith(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _validateCurrentPassword(String enteredPassword) async {
    try {
      final state = context.read<UserCubit>().state; // ✅ Get latest state

      if (state is! UserLoaded) return false; // ✅ Ensure user is loaded

      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(state.userId).get();

      if (!userDoc.exists) return false;

      String storedPasswordHash = userDoc['password']; // ✅ Get hashed password from Firestore
      String enteredPasswordHash = _hashPassword(enteredPassword); // ✅ Hash user input

      print("🔍 Entered Password Hash: $enteredPasswordHash");
      print("🔍 Stored Password Hash: $storedPasswordHash");

      return enteredPasswordHash == storedPasswordHash; // ✅ Compare hashes
    } catch (e) {
      print("❌ Error validating password: $e");
      return false;
    }
  }


  Future<void> _updatePassword(String newPassword) async {
    try {
      final state = context.read<UserCubit>().state; // ✅ Get latest state

      if (state is! UserLoaded) return; // ✅ Ensure user is loaded

      String hashedNewPassword = _hashPassword(newPassword); // ✅ Hash new password

      await FirebaseFirestore.instance.collection('users').doc(state.userId).update({
        'password': hashedNewPassword, // ✅ Store hashed password
      });

      print("✅ Password updated successfully!");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.passwordUpdatedSuccess),
          backgroundColor: AppColors.main.withOpacity(0.9),
        ),
      );
    } catch (e) {
      print("❌ Error updating password: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.passwordUpdatedFailed(e.toString())),
          backgroundColor: AppColors.red.withOpacity(0.8),
        ),
      );
    }
  }


  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }


  void _showLanguageSelectionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext bottomSheetContext) {
        return StatefulBuilder(
          builder: (BuildContext innerContext, StateSetter setState) {
            String currentLocale = Localizations.localeOf(innerContext).languageCode;
            bool isArabic = currentLocale == 'ar';

            return Directionality(
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 10.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ Title
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      child: Text(
                        AppLocalizations.of(innerContext)!.chooseLanguage,
                        style: AppTextStyles.getTitle1(context),
                      ),
                    ),
                    const Divider(),

                    // ✅ Arabic Option
                    ListTile(
                      leading: const Icon(Icons.language, color: AppColors.main),
                      title: Text(
                        "العربية",
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      trailing: currentLocale == 'ar'
                          ? const Icon(Icons.check, color: AppColors.main)
                          : null,
                      onTap: () {
                        if (mounted) { // ✅ Check if the widget is still mounted before calling setState
                          setState(() {
                            _changeLanguage("ar");
                          });
                        }
                      },
                    ),
                    Divider(color: Colors.grey[300]),

                    // ✅ English Option
                    ListTile(
                      leading: const Icon(Icons.language, color: AppColors.main),
                      title: Text(
                        "English",
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      trailing: currentLocale == 'en'
                          ? const Icon(Icons.check, color: AppColors.main)
                          : null,
                      onTap: () {
                        if (mounted) { // ✅ Check if the widget is still mounted before calling setState
                          setState(() {
                            _changeLanguage("en");
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// ✅ تغيير اللغة بناءً على اختيار المستخدم
  void _changeLanguage(String languageCode) {
    final myAppState = MyApp.of(context);
    if (myAppState != null) {
      myAppState.changeLanguage(languageCode);
    }

    setState(() {}); // ✅ Refresh UI
    Navigator.pop(context); // ✅ Close the Bottom Sheet
  }


  ///====================================================///





  /// **إظهار نافذة تعديل البيانات**
  void _showEditDialog(String field, String title, String currentValue) {
    TextEditingController controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: 'New $title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              String newValue = controller.text.trim();
              // context.read<UserCubit>().updateUserData(field, newValue);
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: AppColors.main)),
          ),

        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background2,
      body: BlocBuilder<UserCubit, UserState>( // ⬅️ Use BlocBuilder instead of BlocConsumer
        builder: (context, state) {
          print("🟢 [DEBUG] BlocBuilder received state: $state");

          if (state is UserLoading) {
            return _buildShimmerLoading(); // ⬅️ Show loading state
          } else if (state is NotLogged) {
            return _buildLoginPrompt(context); // ⬅️ Show login screen if user is not logged in
          } else if (state is UserLoaded) {
            return _buildAccountContent(context, state); // ⬅️ Directly show loaded user data
          } else {
            return _buildShimmerLoading(); // ⬅️ Fallback to loading state
          }
        },
      ),
    );
  }


  Widget _buildAccountContent(BuildContext context, UserLoaded state) {
    return Column(
      children: [
        if (state.userId.isEmpty)
          _buildLoginPrompt(context)
        else
          Expanded(
            child: ListView(
              children: [
                SizedBox(height: 5.h),
                _buildSectionTitle(AppLocalizations.of(context)!.personalInformation),
                Divider(color: Colors.grey[200], height: 2.h),
                _buildEditableListTile(Icons.person, AppLocalizations.of(context)!.myProfile, state.userName, 'firstName'),
                Divider(color: Colors.grey[200], height: 2.h),
                _buildEditableListTile(Icons.people, AppLocalizations.of(context)!.myRelatives, AppLocalizations.of(context)!.myRelativesDescription, 'firstName'),
                Divider(color: Colors.grey[200], height: 2.h),

                const SizedBox(height: 15),
                _buildSectionTitle(AppLocalizations.of(context)!.loginSection),
                Divider(color: Colors.grey[200], height: 2.h),
                _buildEditableListTile(Icons.phone, AppLocalizations.of(context)!.phone, _formatPhoneForDisplay(state.userPhone), 'phoneNumber', isVerified: state.isPhoneVerified),
                Divider(color: Colors.grey[200], height: 2.h),
                _buildEditableListTile(Icons.email, AppLocalizations.of(context)!.email, state.userEmail, 'email', isVerified: state.isEmailVerified),
                Divider(color: Colors.grey[200], height: 2.h),
                _buildEditableListTile(Icons.lock, AppLocalizations.of(context)!.password, AppLocalizations.of(context)!.passwordHidden, 'password'),
                Divider(color: Colors.grey[200], height: 2.h),

                const SizedBox(height: 15),
                _buildSectionTitle(AppLocalizations.of(context)!.settings),
                Divider(color: Colors.grey[200], height: 2.h),
                _buildEditableListTile(Icons.language, AppLocalizations.of(context)!.language, AppLocalizations.of(context)!.languageDescription, 'Language', trailingWidget: Text(
                  Localizations.localeOf(context).languageCode == 'ar' ? "العربية" : "English",
                  style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w500, color: AppColors.grayMain),
                ),),
                Divider(color: Colors.grey[200], height: 2.h),
                _buildEditableListTile(Icons.key, AppLocalizations.of(context)!.twoFactorAuth, AppLocalizations.of(context)!.twoFactorAuthActivated, 'Activated'),
                Divider(color: Colors.grey[200], height: 2.h),
                _buildEditableListTile(Icons.security, AppLocalizations.of(context)!.encryptedDocuments, AppLocalizations.of(context)!.encryptedDocumentsDescription,'Activated'),
                Divider(color: Colors.grey[200], height: 2.h),
                _buildEditableListTile(
                    biometricIcon,
                    biometricType,
                    biometricType == AppLocalizations.of(context)!.faceIdTitle
                        ? AppLocalizations.of(context)!.faceIdDescription
                        : AppLocalizations.of(context)!.fingerprintDescription,
                    'faceId'
                ),

                Divider(color: Colors.grey[200], height: 2.h),

                SizedBox(height: 15.h),
                _buildSectionTitle(AppLocalizations.of(context)!.confidentiality),
                Divider(color: Colors.grey[200], height: 2.h),
                _buildEditableListTile(Icons.settings, AppLocalizations.of(context)!.myPreferences, '', ''),
                Divider(color: Colors.grey[200], height: 2.h),
                _buildEditableListTile(Icons.info, AppLocalizations.of(context)!.legalInformation, '', ''),
                Divider(color: Colors.grey[200], height: 2.h),

                SizedBox(height: 25.h),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<UserCubit>().logout(); // ✅ Triggers logout state
                      widget.onLogout(); // ✅ Keeps external logic for logout
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 12.h),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.logOut,
                      style: AppTextStyles.getText2(context).copyWith(color: AppColors.whiteText),
                    ),
                  ),
                ),


                SizedBox(height: 25.h),
              ],
            ),
          ),
      ],
    );
  }

  /// **🔹 Builds the UI shown when the user is logged out**
  Widget _buildLoginPrompt(BuildContext context) {
    return ClipPath(
      clipper: CustomTopBarClipper(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        width: double.infinity,
        color: AppColors.main,
        padding: EdgeInsets.symmetric(vertical: 30.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 80.sp, color: Colors.white),
            SizedBox(height: 10.h),
            Text(AppLocalizations.of(context)!.welcomeDocsera, style: AppTextStyles.getTitle3(context).copyWith(color: Colors.white)),
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 30.w),
              child: Text(
                AppLocalizations.of(context)!.welcome_subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.getText2(context).copyWith(color: Colors.white70),
              ),
            ),
            SizedBox(height: 20.h),
            _buildBenefitsList(),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              icon: const Icon(Icons.login, color: AppColors.main),
              label: Text(AppLocalizations.of(context)!.login_button,
                  style: AppTextStyles.getText2(context).copyWith(color: AppColors.main, fontWeight: FontWeight.w600)), // 🔸 Applied responsive text
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 35.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
            ),

            // ✅ رابط لإنشاء حساب جديد
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/signup');
              },
              child: Text(AppLocalizations.of(context)!.signup_button,
                  style: AppTextStyles.getText2(context).copyWith(color: Colors.white)), // 🔸 Applied responsive text
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: ShimmerWidget(width: 100.w, height: 20.h, radius: 8),
          ),
          SizedBox(height: 10.h),
          ...List.generate(2, (index) => Padding(
            padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 5.w),
            child: ShimmerWidget(width: double.infinity, height: 60.h, radius: 3),
          )),
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: ShimmerWidget(width: 100.w, height: 20.h, radius: 8),
          ),
          SizedBox(height: 10.h),
          ...List.generate(3, (index) => Padding(
            padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 5.w),
            child: ShimmerWidget(width: double.infinity, height: 60.h, radius: 3),
          )),
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: ShimmerWidget(width: 100.w, height: 20.h, radius: 8),
          ),          SizedBox(height: 10.h),
          ...List.generate(4, (index) => Padding(
            padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 5.w),
            child: ShimmerWidget(width: double.infinity, height: 60.h, radius: 3),
          )),
        ],
      ),
    );
  }


// ✅ عنصر منفصل لعرض ميزة من مميزات التسجيل
  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // 🔸 Ensures text wraps properly
        children: [
          Icon(icon, size: 18.sp, color: Colors.white),
          SizedBox(width: 10.w),
          Flexible( // 🔸 Allows text to wrap without causing overflow
              child: Text(
                        text,
                            style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
                            softWrap: true,
                            overflow: TextOverflow.visible,),
          )
        ],
      ),
    );
  }

  /// **🔹 Builds benefits list**
  Widget _buildBenefitsList() {
    return Expanded( // 🔸 Replace `Flexible` with `Expanded`
        child: SingleChildScrollView( // 🔸 Ensure it scrolls when needed
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 60.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildBenefitItem(Icons.event_available, AppLocalizations.of(context)!.benefit_appointments),
                _buildBenefitItem(Icons.notifications_active, AppLocalizations.of(context)!.benefit_reminders),
                _buildBenefitItem(Icons.history, AppLocalizations.of(context)!.benefit_history),
                _buildBenefitItem(Icons.chat, AppLocalizations.of(context)!.benefit_chat),
              ],
            ),
          ),
        ),
      );
  }

  /// **🔵 عنصر عنوان لقسم معين**
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
      child: Text(
        title,
      style: AppTextStyles.getTitle1(context).copyWith(
    color: AppColors.mainDark.withOpacity(0.6), fontSize: 12),
      ),
    );
  }

  /// **🟢 عنصر عرض معلومات المستخدم مع إمكانية التعديل**
  Widget _buildEditableListTile(
      IconData icon,
      String title,
      String subtitle,
      String field,
      {bool? isVerified, Widget? trailingWidget}
      ) {
    return InkWell(
      onTap: (field == 'faceId') ? null : () { // ✅ منع الضغط عند وجود Switch
        final state = context.read<UserCubit>().state; // ✅ Get latest state
        if (state is! UserLoaded) return;

        if (title == AppLocalizations.of(context)!.myProfile) {
          Navigator.push(context, fadePageRoute(const UserProfilePage()));
        } else if (title == AppLocalizations.of(context)!.myRelatives) {
          Navigator.push(context, fadePageRoute(const MyRelativesPage()));
        } else if (title == AppLocalizations.of(context)!.phone) {
          _showEditFieldSheet(context, 'phoneNumber', state.userPhone);
        } else if (title == AppLocalizations.of(context)!.email) {
          _showEditFieldSheet(context, 'email', state.userEmail);
        } else if (title == AppLocalizations.of(context)!.password) {
          _showChangePasswordSheet(context);
        } else if (title == AppLocalizations.of(context)!.language) {
          _showLanguageSelectionSheet();
        } else {
          _showEditDialog(field, title, subtitle);
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 20.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, -10.h),
              child: (field == 'faceId') ? Icon(icon, color: AppColors.main, size: 20.sp) : Icon(icon, color: AppColors.main, size: 16.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w500)),
                  SizedBox(height: 4.h),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
                    child: Text(subtitle, style: AppTextStyles.getText2(context).copyWith(color: Colors.grey)),
                  ),
                ],
              ),
            ),
            if (field == 'phoneNumber' || field == 'email')
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: (isVerified ?? false) ? AppColors.main.withOpacity(0.1) : AppColors.yellow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  (isVerified ?? false) ? AppLocalizations.of(context)!.verified : AppLocalizations.of(context)!.notVerified,
                  style: AppTextStyles.getText3(context).copyWith(
                    color: (isVerified ?? false) ? AppColors.main : AppColors.yellow,
                    fontWeight: FontWeight.w400,
                    fontSize: 8,
                  ),
                ),
              ),
            if (trailingWidget != null)
              trailingWidget
            else if (field == 'faceId')
              Transform.scale(
                scale: 0.8, // ✅ تقليل حجم الـ Switch بشكل عام
                child: Switch(
                  value: isFaceIdEnabled,
                  onChanged: (bool value) async {
                    bool authenticated = await _authenticateWithFaceID();
                    if (authenticated) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('enableFaceID', value);
                      setState(() {
                        isFaceIdEnabled = value;
                      });
                      print("✅ Face ID Preference Saved: $value");
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.faceIdFailed)),
                      );
                    }
                  },
                  activeColor: Colors.white, // ✅ لون الدائرة عند التفعيل
                  activeTrackColor: AppColors.main.withOpacity(0.8), // ✅ لون المسار عند التفعيل
                  inactiveTrackColor: Colors.grey[400], // ✅ لون المسار عند التعطيل
                  trackOutlineColor: MaterialStateProperty.all(Colors.transparent), // ✅ إزالة أي حدود
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // ✅ تقليل المساحة القابلة للنقر
                  thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.selected)) {
                      return AppColors.main; // ✅ لون الدائرة عند التفعيل
                    }
                    return Colors.grey[400]!; // ✅ لون الدائرة عند التعطيل
                  }),
                  thumbIcon: MaterialStateProperty.resolveWith<Icon?>((states) {
                    return Icon(
                      Icons.circle, // ✅ تغيير شكل الـ thumb
                      size: 30, // ✅ تكبير الدائرة (thumb)
                      color: Colors.grey[200], // ✅ جعل لونها أبيض
                    );
                  }),
                ),
              )
            else
              Row(
                children: [
                  SizedBox(width: 8.w),
                  Icon(Icons.arrow_forward_ios, size: 16.sp, color: Colors.grey),
                ],
              ),
          ],
        ),
      ),
    );
  }
}


