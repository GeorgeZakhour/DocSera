import 'dart:async';
import 'dart:io';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/main.dart';
import 'package:docsera/models/sign_up_info.dart';
import 'package:docsera/screens/auth/sign_up/sign_up_phone.dart';
import 'package:docsera/screens/home/account/goodbye_page.dart';
import 'package:docsera/screens/home/account/legal_information.dart';
import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';
import 'package:docsera/services/supabase/supabase_otp_service.dart';
import 'package:docsera/services/supabase/supabase_user_service.dart';
import 'package:docsera/utils/custom_clippers.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart'; //
import 'package:docsera/screens/home/account/user_profile_page.dart';
import 'package:docsera/screens/home/account/my_relatives.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter_svg/svg.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/utils/input_decoration.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../Business_Logic/Account_page/user_cubit.dart';
import '../../Business_Logic/Account_page/user_state.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account/preferences.dart';



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
  String appVersion = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      setState(() {
        appVersion = 'v${info.version}';
      });
      print("✅ App Version Loaded: v${info.version}"); // ✅ DEBUG
    });

    _loadFaceIdPreference();

    Future.delayed(Duration.zero, () async {
      final prefs = await SharedPreferences.getInstance();
      final userCubit = context.read<UserCubit>();
      await userCubit.loadUserData(context, useCache: true);
      userCubit.startRealtimeUserListener(prefs.getString('userId') ?? '');
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

  // Future<bool> _isPhoneNumberDuplicate(String phone) async {
  //   final String formatted = _formatPhoneForBackend(phone);
  //   final String fakeEmail = "$formatted@docsera.com";
  //
  //   final response = await Supabase.instance.client
  //       .from('users')
  //       .select('id')
  //       .eq('fakeEmail', fakeEmail)
  //       .maybeSingle();
  //
  //   return response != null;
  // }


  Future<bool> _isPhoneNumberDuplicate(String phone) async {
    final String formatted = _formatPhoneForBackend(phone);

    final response = await Supabase.instance.client
        .from('users')
        .select('id')
        .eq('phone_number', formatted)
        .maybeSingle();

    return response != null;
  }


  bool _isValidPhoneNumber(String input) {
    if (!input.startsWith('9') && !input.startsWith('09')) return false;
    int requiredLength = input.startsWith('09') ? 10 : 9;
    return input.length == requiredLength;
  }


  void _showEditFieldSheet(BuildContext context, String fieldType, String currentValue, {String? customTitle}) {

    final state = context.read<UserCubit>().state;
    if (state is! UserLoaded) return;

    String formatPhoneForDisplay(String phone) {
      if (phone.startsWith('00963')) return '0${phone.substring(5)}';
      return phone;
    }

    String normalizePhoneNumber(String phone) {
      phone = phone.trim();
      if (phone.startsWith('00963')) return phone;
      if (phone.startsWith('09')) return '00963${phone.substring(1)}';
      if (phone.startsWith('9') && phone.length == 9) return '00963$phone';
      return phone;
    }

    final RegExp emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    String formattedCurrentValue = fieldType == 'phoneNumber' ? formatPhoneForDisplay(state.userPhone) : currentValue;
    final originalNormalizedValue = fieldType == 'phoneNumber' ? state.userPhone : currentValue;

    final TextEditingController fieldController = TextEditingController(
      text: formattedCurrentValue == AppLocalizations.of(context)!.notProvided ? '' : formattedCurrentValue,
    );

    String? errorMessage;
    bool isChecking = false;
    bool isNotVerified = (fieldType == 'phoneNumber' && !state.isPhoneVerified);

    String title = customTitle ??
        (fieldType == 'phoneNumber'
            ? AppLocalizations.of(context)!.editPhoneNumber
            : AppLocalizations.of(context)!.editEmail);

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
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: fieldController,
                      keyboardType: fieldType == 'phoneNumber' ? TextInputType.number : TextInputType.emailAddress,
                      textDirection: detectTextDirection(fieldController.text),
                      textAlign: getTextAlign(context),
                      style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp),
                      maxLength: fieldType == 'phoneNumber' ? 10 : 100,
                      decoration: getInputDecoration(hintText: hintText).copyWith(
                        errorText: errorMessage,
                        counterText: "",
                        prefixText: fieldType == 'phoneNumber' ? "+963 | " : null,
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (fieldType == 'phoneNumber' &&
                                fieldController.text.isNotEmpty &&
                                normalizePhoneNumber(fieldController.text.trim()) != originalNormalizedValue)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6.w),
                                child: Container(
                                  width: 20.w,
                                  height: 20.w,
                                  decoration: BoxDecoration(
                                    color: _isValidPhoneNumber(fieldController.text.trim())
                                        ? AppColors.main.withOpacity(0.8)
                                        : AppColors.red.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isValidPhoneNumber(fieldController.text.trim()) ? Icons.check : Icons.close,
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
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      onChanged: (_) {
                        setState(() => errorMessage = null);
                      },
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () async {
                        final newRaw = fieldController.text.trim();
                        final newNormalized = fieldType == 'phoneNumber'
                            ? normalizePhoneNumber(newRaw)
                            : newRaw;

                        if (fieldType == 'phoneNumber' && !_isValidPhoneNumber(newRaw)) {
                          setState(() => errorMessage = AppLocalizations.of(context)!.invalidPhoneNumber);
                          return;
                        }

                        if (fieldType == 'email' && !emailRegex.hasMatch(newRaw)) {
                          setState(() => errorMessage = AppLocalizations.of(context)!.invalidEmail);
                          return;
                        }

                        if (newNormalized == originalNormalizedValue) {
                          setState(() => errorMessage = AppLocalizations.of(context)!.samePhone);
                          return;
                        }

                        setState(() => isChecking = true);

                        bool isDuplicate = false;
                        if (fieldType == 'phoneNumber') {
                          isDuplicate = await _isPhoneNumberDuplicate(newNormalized);
                        } else {
                          isDuplicate = await SupabaseUserService().doesUserExist(email: newRaw);
                        }

                        setState(() => isChecking = false);

                        if (isDuplicate) {
                          setState(() => errorMessage = fieldType == 'phoneNumber'
                              ? AppLocalizations.of(context)!.alreadyExistsPhone
                              : AppLocalizations.of(context)!.alreadyExistsEmail);
                        } else {
                          Navigator.pop(context);
                          _sendOTPAndShowSheet(
                            context,
                            newRaw,
                            fieldType,
                            originalNormalizedValue,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.main,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size(double.infinity, 50.h),
                      ),
                      child: isChecking
                          ? SizedBox(
                        width: 16.w,
                        height: 16.h,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Text(
                        (fieldType == 'phoneNumber' && isNotVerified)
                            ? AppLocalizations.of(context)!.verify
                            : (fieldType == 'email' && originalNormalizedValue.isEmpty)
                            ? AppLocalizations.of(context)!.add
                            : AppLocalizations.of(context)!.save,
                        style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
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

  void _sendOTPAndShowSheet(BuildContext context, String newValue, String fieldType, String oldValue) async {
    final otpService = SupabaseOTPService();
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

                        final otp = fieldType == 'phoneNumber'
                            ? await otpService.sendOTPToPhone(newValue)
                            : await otpService.sendOTPToEmail(newValue);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('OTP: $otp'),
                              backgroundColor: AppColors.main.withOpacity(0.9),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
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
                                context,
                                newPhoneFormatted,
                                isVerified: true,
                              );

                            } else {
                              await context.read<UserCubit>().updateUserData(context, fieldType, newValue, isVerified: true);
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
      if (state is! UserLoaded) return false;

      print("🔍 Checking for duplicate in Supabase: $fieldType - $newValue");

      final response = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq(fieldType, newValue)
          .neq('id', state.userId) // ✅ استثني المستخدم الحالي
          .maybeSingle();

      final isDuplicate = response != null;

      print("⚠️ Is Duplicate: $isDuplicate");
      return isDuplicate;
    } catch (e) {
      print("❌ Supabase duplicate check error: $e");
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
                      style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp),
                      textDirection: detectTextDirection(currentPasswordController.text),
                      textAlign: getTextAlign(context),
                      obscureText: !isCurrentPasswordVisible,
                      decoration: getInputDecoration(hintText: AppLocalizations.of(context)!.currentPassword).copyWith(
                        contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                        errorText: isCurrentPasswordValid ? null : AppLocalizations.of(context)!.incorrectCurrentPassword,
                        hintStyle: AppTextStyles.getText3(context).copyWith(fontSize: 11.sp, color: Colors.grey),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isCurrentPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            size: 16.sp,
                          ),
                          onPressed: () => setState(() => isCurrentPasswordVisible = !isCurrentPasswordVisible),
                        ),
                      ),
                    ),

                    SizedBox(height: 12.h),

                    // ✅ New Password Field with Smaller Eye Icon
                    TextFormField(
                      controller: newPasswordController,
                      textDirection: detectTextDirection(newPasswordController.text),
                      textAlign: getTextAlign(context),
                      obscureText: !isNewPasswordVisible,
                      style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp),
                      onChanged: (value) {
                        _validateNewPassword(value, setState);
                        _checkPasswordsDifference(setState);
                      },
                      decoration: getInputDecoration(
                        hintText: AppLocalizations.of(context)!.newPassword,
                      ).copyWith(
                        contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                        hintStyle: AppTextStyles.getText3(context).copyWith(fontSize: 11.sp, color: Colors.grey),
                        errorText: isNewPasswordDifferent ? null : AppLocalizations.of(context)!.passwordMatchError,
                        suffixIcon: IconButton(
                          icon: Icon(
                            isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            size: 16.sp,
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

                        bool reauthSuccess = await _reauthenticateUser(currentPassword);
                        if (!reauthSuccess) {
                          setState(() {
                            isCurrentPasswordValid = false;
                            isUpdating = false;
                          });
                          return;
                        }

                        await _updatePasswordSupabase(newPassword);
                        if (mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.main,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size(double.infinity, 50.h),
                      ),
                      child: isUpdating
                          ? SizedBox(
                        width: 16.w,
                        height: 16.h,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Text(
                        AppLocalizations.of(context)!.save,
                        style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
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

  void _showResetPasswordViaOTPSheet(BuildContext context) async {
    final userState = context.read<UserCubit>().state;
    final phone = userState is UserLoaded ? userState.userPhone : '';
    final formattedPhone = _formatPhoneForBackend(phone);


    final otpService = SupabaseOTPService();
    await otpService.sendOTPToPhone(formattedPhone);

    final TextEditingController otpController = TextEditingController();
    bool isCodeValid = true;
    int timerSeconds = 60;
    bool canResend = false;
    Timer? resendTimer;

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
                        Text(AppLocalizations.of(context)!.pleaseConfirm(AppLocalizations.of(context)!.phone),
                            style: AppTextStyles.getTitle1(context)),
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
                      textDirection: detectTextDirection(otpController.text),
                      textAlign: getTextAlign(context),
                      style: AppTextStyles.getText1(context),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: getInputDecoration(hintText: AppLocalizations.of(context)!.sixDigitCode)
                          .copyWith(errorText: isCodeValid ? null : 'Invalid code'),
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () async {
                        bool isValid = await otpService.validateOTP(formattedPhone, otpController.text.trim());
                        if (isValid) {
                          resendTimer?.cancel();
                          Navigator.pop(context); // ✅ أغلق شيت OTP
                          _showEnterNewPasswordSheet(context); // ✅ افتح شيت تغيير كلمة المرور الجديدة
                        } else {
                          setState(() => isCodeValid = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.main,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                        minimumSize: Size(double.infinity, 50.h),
                      ),
                      child: Text(AppLocalizations.of(context)!.continueButton,
                          style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white)),
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

  void _showEnterNewPasswordSheet(BuildContext context) {
    final TextEditingController pass1 = TextEditingController();
    final TextEditingController pass2 = TextEditingController();
    bool isVisible1 = false;
    bool isVisible2 = false;
    bool isValid = false;
    bool isMatching = true;
    bool isUpdating = false;

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
                        Text(AppLocalizations.of(context)!.resetPassword,
                            style: AppTextStyles.getTitle1(context)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                      ],
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: pass1,
                      obscureText: !isVisible1,
                      onChanged: (_) => setState(() {
                        isValid = pass1.text.length >= 8;
                        isMatching = pass1.text == pass2.text;
                      }),
                      decoration: getInputDecoration(
                        hintText: AppLocalizations.of(context)!.newPassword,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(isVisible1 ? Icons.visibility : Icons.visibility_off, size: 16.sp),
                          onPressed: () => setState(() => isVisible1 = !isVisible1),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: pass2,
                      obscureText: !isVisible2,
                      onChanged: (_) => setState(() {
                        isMatching = pass1.text == pass2.text;
                      }),
                      decoration: getInputDecoration(
                        hintText: AppLocalizations.of(context)!.confirmPassword,
                      ).copyWith(
                        errorText: isMatching ? null : AppLocalizations.of(context)!.passwordMatchError,
                        suffixIcon: IconButton(
                          icon: Icon(isVisible2 ? Icons.visibility : Icons.visibility_off, size: 16.sp),
                          onPressed: () => setState(() => isVisible2 = !isVisible2),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: (!isValid || !isMatching || isUpdating)
                          ? null
                          : () async {
                        setState(() => isUpdating = true);
                        try {
                          await Supabase.instance.client.auth.updateUser(
                            UserAttributes(password: pass1.text.trim()),
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!.passwordUpdatedSuccess),
                              backgroundColor: AppColors.main,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!.passwordUpdatedFailed(e.toString())),
                              backgroundColor: AppColors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.main,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                        minimumSize: Size(double.infinity, 50.h),
                      ),
                      child: isUpdating
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : Text(AppLocalizations.of(context)!.save,
                          style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white)),
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

  Future<bool> _reauthenticateUser(String currentPassword) async {
    try {
      final state = context.read<UserCubit>().state;
      if (state is! UserLoaded) return false;

      final email = state.userEmail;
      if (email == null || email.isEmpty) return false;

      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );

      return res.user != null;
    } on AuthException catch (e) {
      print("❌ Re-authentication failed: ${e.message}");
      return false;
    } catch (e) {
      print("❌ Re-authentication failed: $e");
      return false;
    }
  }


  Future<void> _updatePasswordSupabase(String newPassword) async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      print("✅ Password updated successfully");

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

  void _showEncryptedDocumentsInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      AppLocalizations.of(context)!.encryptedDocuments,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.getTitle1(context).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              Image.asset(
                'assets/images/encrypted.png',
                height: 100.h,
              ),
              SizedBox(height: 20.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFDFF6F3),
                  borderRadius: BorderRadius.circular(30.r),
                ),
                child: Text(
                  AppLocalizations.of(context)!.activated,
                  style: TextStyle(
                    color: const Color(0xFF00B7A0),
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                AppLocalizations.of(context)!.encryptedDocumentsFullDescription,
                textAlign: TextAlign.center,
                style: AppTextStyles.getText3(context),
              ),
              SizedBox(height: 10.h),
            ],
          ),
        );
      },
    );
  }

  void _showTwoFactorAuthInfoSheet(bool is2FAEnabled) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      AppLocalizations.of(context)!.twoFactorAuth,
                      style: AppTextStyles.getTitle1(context).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              Image.asset('assets/images/two_factor.png', height: 100.h),
              SizedBox(height: 20.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: is2FAEnabled ? const Color(0xFFDFF6F3) : const Color(0xFFFFEAE6),
                  borderRadius: BorderRadius.circular(30.r),
                ),
                child: Text(
                  is2FAEnabled
                      ? AppLocalizations.of(context)!.activated
                      : AppLocalizations.of(context)!.notActivated,
                  style: TextStyle(
                    color: is2FAEnabled ? const Color(0xFF00B7A0) : const Color(0xFFFF6B6B),
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                AppLocalizations.of(context)!.twoFactorAuthHeadline,
                textAlign: TextAlign.center,
                style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold, fontSize: 12.sp),
              ),
              SizedBox(height: 6.h),
              Text(
                AppLocalizations.of(context)!.twoFactorAuthFullDescription,
                textAlign: TextAlign.center,
                style: AppTextStyles.getText3(context),
              ),
              SizedBox(height: 20.h),
              ElevatedButton(
                onPressed: () async {
                  final userId = (context.read<AuthCubit>().state as AuthAuthenticated).user.id;
                  final newValue = !is2FAEnabled;

                  if (!newValue) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.deactivate2FA,
                              style: AppTextStyles.getTitle2(context),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              AppLocalizations.of(context)!.twoFactorDeactivateWarning,
                              style: AppTextStyles.getText2(context),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24.h),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.red,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                              ),
                              onPressed: () {
                                Navigator.pop(context, true);
                              },
                              child: Center(
                                child: Text(
                                  AppLocalizations.of(context)!.deactivate2FA,
                                  style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(
                                AppLocalizations.of(context)!.cancel,
                                style: AppTextStyles.getText2(context).copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.blackText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    if (confirm != true) return;
                  }

                  await Supabase.instance.client
                      .from('users')
                      .update({'two_factor_auth_enabled': newValue})
                      .eq('id', userId);


                  Navigator.pop(context);
                  await context.read<UserCubit>().loadUserData(context, useCache: false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: Center(
                  child: Text(
                    is2FAEnabled
                        ? AppLocalizations.of(context)!.deactivate2FA
                        : AppLocalizations.of(context)!.activate2FA,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void showDeleteAccountSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      AppLocalizations.of(context)!.deleteMyAccount,
                      style: AppTextStyles.getTitle1(context).copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              Text(
                AppLocalizations.of(context)!.deleteAccountWarningText,
                style: AppTextStyles.getText2(context).copyWith(color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  AppLocalizations.of(context)!.cancel,
                  style: AppTextStyles.getText2(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.blackText,
                  ),
                ),
              ),
              TextButton(

                onPressed: () async {
                  Navigator.pop(context); // إغلاق الشيت

                  final user = Supabase.instance.client.auth.currentUser;
                  final userId = user?.id;

                  String? phone;
                  String? email;

                  if (userId != null) {
                    // ✅ جلب بيانات Supabase
                    final data = await Supabase.instance.client
                        .from('users')
                        .select('phone_number, email')
                        .eq('id', userId)
                        .maybeSingle();

                    if (data == null) {
                      print("❌ No user data found.");
                      return;
                    }

                    phone = data['phone_number']?.toString();
                    email = data['email']?.toString();

                    print("🧾 [DEBUG] userId: $userId");
                    print("📞 [DEBUG] phone from Supabase: $phone");
                    print("📧 [DEBUG] email from Supabase: $email");

                    final service = SupabaseUserService();

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => Center(child: CircularProgressIndicator(color: AppColors.grayMain)),
                    );

                    try {
                      await service.deleteUserAccount(userId, phoneNumber: phone, email: email);
                      Navigator.pushAndRemoveUntil(
                        context,
                        fadePageRoute(const GoodbyePage()),
                            (route) => false,
                      );
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred)),
                      );
                    }
                  }
                },
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  AppLocalizations.of(context)!.confirmDeleteMyAccount,
                  style: AppTextStyles.getText2(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),



            ],
          ),
        );
      },
    );
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

  Widget _buildAccountBannerCard() {
    return Padding(
      padding: EdgeInsets.only(top: 16.h, right: 16.w, left: 16.w),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 25.w, horizontal: 20.w),
        decoration: BoxDecoration(
          color: AppColors.main.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/images/account_banner.png',
              width: 45.w,
              height: 45.w,
            ),
            SizedBox(width: 18.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.accountPrivacyInfoLine1,
                    style: AppTextStyles.getText2(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.blackText,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    AppLocalizations.of(context)!.accountPrivacyInfoLine2,
                    style: AppTextStyles.getText3(context).copyWith(
                      color: AppColors.blackText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
                _buildAccountBannerCard(),
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
                _buildEditableListTile(
                  Icons.email,
                  AppLocalizations.of(context)!.email,
                  (state.userEmail == null || state.userEmail!.isEmpty)
                      ? AppLocalizations.of(context)!.notProvided
                      : state.userEmail!,
                  'email',
                  isVerified: state.isEmailVerified,
                ),

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
                if (state is UserLoaded)
                  _buildEditableListTile(
                    Icons.key,
                    AppLocalizations.of(context)!.twoFactorAuth,
                    state.is2FAEnabled
                        ? AppLocalizations.of(context)!.activated
                        : AppLocalizations.of(context)!.notActivated,
                    '2fa',
                    trailingWidget: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: state.is2FAEnabled
                            ? const Color(0xFFDFF6F3)
                            : const Color(0xFFFFF4D9),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        state.is2FAEnabled
                            ? AppLocalizations.of(context)!.activated
                            : AppLocalizations.of(context)!.notActivated,
                        style: AppTextStyles.getText3(context).copyWith(
                          color: state.is2FAEnabled
                              ? const Color(0xFF00B7A0)
                              : AppColors.yellow,
                          fontWeight: FontWeight.w400,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ),

                Divider(color: Colors.grey[200], height: 2.h),
                _buildEditableListTile(
                  Icons.security,
                  AppLocalizations.of(context)!.encryptedDocuments,
                  AppLocalizations.of(context)!.encryptedDocumentsDescription,
                  'encrypted',
                  trailingWidget: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDFF6F3),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.activated,
                      style: AppTextStyles.getText3(context).copyWith(
                        color: const Color(0xFF00B7A0),
                        fontWeight: FontWeight.w400,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
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
                _buildPrivacyItem(
                  AppLocalizations.of(context)!.myPreferences,
                      () {
                        Navigator.push(context, fadePageRoute(const MyPreferencesPage()));
                  },
                ),
                Divider(color: Colors.grey[200], height: 2.h),
                _buildPrivacyItem(
                  AppLocalizations.of(context)!.legalInformation,
                      () {
                        Navigator.push(context, fadePageRoute(const LegalInformation()));
                  },
                ),
                Divider(color: Colors.grey[200], height: 2.h),
                _buildPrivacyItem(
                  AppLocalizations.of(context)!.deleteMyAccount,
                      () => showDeleteAccountSheet(context),
                ),

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


                if (appVersion.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 10.h, bottom: 20.h),
                    child: Center(
                      child: Text(
                        appVersion,
                        style: AppTextStyles.getText3(context).copyWith(
                          color: Colors.grey,
                          fontSize: 9.sp,
                        ),
                      ),
                    ),
                  ),
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
                Navigator.push(
                  context,
                  fadePageRoute(SignUpFirstPage(signUpInfo: SignUpInfo())),
                );
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
    return Expanded(
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 60.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // يضمن التمركز العمودي داخل الـScroll
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
          final hasEmail = state.userEmail != null && state.userEmail!.isNotEmpty;
          _showEditFieldSheet(
            context,
            'email',
            state.userEmail ?? '',
            customTitle: (state.userEmail == null || state.userEmail!.isEmpty)
                ? AppLocalizations.of(context)!.addEmailTitle
                : null,
          );

        } else if (title == AppLocalizations.of(context)!.password) {
          _showChangePasswordSheet(context);
        } else if (title == AppLocalizations.of(context)!.language) {
          _showLanguageSelectionSheet();
        } else if (field == 'encrypted') {
          _showEncryptedDocumentsInfoSheet();
        } else if (field == '2fa') {
          _showTwoFactorAuthInfoSheet(state.is2FAEnabled);
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
              child: (field == 'faceId')
                  ? (biometricIcon == Icons.face
                  ? SvgPicture.asset('assets/icons/face-id.svg', width: 20.w, height: 20.w, color: AppColors.main)
                  : Icon(biometricIcon, size: 20.w, color: AppColors.main))
                  : Icon(icon, color: AppColors.main, size: 16.sp),
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
            if ((field == 'phoneNumber') || (field == 'email' && (subtitle.isNotEmpty && subtitle != AppLocalizations.of(context)!.notProvided)))
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: (isVerified ?? false)
                      ? AppColors.main.withOpacity(0.1)
                      : AppColors.yellow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  (isVerified ?? false)
                      ? AppLocalizations.of(context)!.verified
                      : AppLocalizations.of(context)!.notVerified,
                  style: AppTextStyles.getText3(context).copyWith(
                    color: (isVerified ?? false)
                        ? AppColors.main
                        : AppColors.yellow,
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
                  Icon(Icons.arrow_forward_ios, size: 12.sp, color: Colors.grey),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyItem(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 20.w),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.getText2(context).copyWith(
                  fontWeight: FontWeight.w500,
                  color:  AppColors.blackText,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12.sp, color: Colors.grey),
          ],
        ),
      ),
    );
  }

}


