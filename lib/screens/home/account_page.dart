import 'dart:async';
import 'dart:io';
import 'package:docsera/Business_Logic/Account_page/danger/account_danger_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/profile/account_profile_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/profile/account_profile_state.dart';
import 'package:docsera/Business_Logic/Account_page/security/account_security_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/security/account_security_state.dart';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/main.dart';
import 'package:docsera/models/sign_up_info.dart';
import 'package:docsera/screens/auth/sign_up/sign_up_phone.dart';
import 'package:docsera/screens/home/account/goodbye_page.dart';
import 'package:docsera/screens/home/account/legal_information.dart';
import 'package:docsera/screens/home/account/points_history_page.dart';
import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';
import 'package:docsera/utils/custom_clippers.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:flutter/services.dart';
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
import '../../Business_Logic/Account_page/user_cubit.dart';
import '../../Business_Logic/Account_page/user_state.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'account/preferences.dart';



class AccountScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const AccountScreen({super.key, required this.onLogout});

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  String biometricType = "Biometric Authentication"; // Default fallback
  IconData biometricIcon = Icons.fingerprint; // Default icon
  bool _biometricChecked = false;
  String currentLocale = "en"; // Default
  String appVersion = '';

  @override
  void initState() {
    super.initState();

    final authCubit = context.read<AuthCubit>();
    final authState = authCubit.state;

    if (authState is AuthAuthenticated) {
      // 🔹 تحميل المستخدم الأساسي
      context.read<UserCubit>().loadUserData(context: context);

      // 🔹 تحميل كل تبويبات الحساب فورًا
      context.read<AccountProfileCubit>().loadProfile();
    }

    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() {
        appVersion = 'v${info.version}';
      });
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



  Future<void> _detectBiometricType() async {
    try {
      List<BiometricType> availableBiometrics = await auth.getAvailableBiometrics();
      if (!mounted) return;

      debugPrint("✅ Available Biometrics: $availableBiometrics");

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

      debugPrint("✅ Biometric Type Set & Saved: $biometricType");
    } catch (e) {
      debugPrint("❌ Biometric detection error: $e");
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

  bool _isValidPhoneNumber(String input) {
    if (!input.startsWith('9') && !input.startsWith('09')) return false;
    int requiredLength = input.startsWith('09') ? 10 : 9;
    return input.length == requiredLength;
  }


  void _showEditFieldSheet(
      BuildContext context,
      String fieldType,
      String currentValue, {
        String? customTitle,
      }) {
    final profileState = context.read<AccountProfileCubit>().state;
    if (profileState is! AccountProfileLoaded) return;

    // ---------------------------------------------------------------------------
    // Helpers (نفس منطقك السابق)
    // ---------------------------------------------------------------------------

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

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

    final originalNormalizedValue =
    fieldType == 'phoneNumber' ? profileState.phone : profileState.email;

    final formattedCurrentValue =
    fieldType == 'phoneNumber'
        ? formatPhoneForDisplay(profileState.phone)
        : profileState.email;


    final controller = TextEditingController(
      text: formattedCurrentValue ==
          AppLocalizations.of(context)!.notProvided
          ? ''
          : formattedCurrentValue,
    );

    bool isNotVerified =
        fieldType == 'phoneNumber' && !profileState.isPhoneVerified;


    String? errorMessage;
    bool isChecking = false;

    final title = customTitle ??
        (fieldType == 'phoneNumber'
            ? AppLocalizations.of(context)!.editPhoneNumber
            : AppLocalizations.of(context)!.editEmail);

    final hintText = fieldType == 'phoneNumber'
        ? AppLocalizations.of(context)!.newPhoneNumber
        : AppLocalizations.of(context)!.newEmailAddress;

    final securityCubit = context.read<AccountSecurityCubit>();

    // ---------------------------------------------------------------------------
    // Bottom Sheet
    // ---------------------------------------------------------------------------

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
          child: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ---------------------------------------------------------------------------
                    // Header
                    // ---------------------------------------------------------------------------
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title, style: AppTextStyles.getTitle1(context)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),

                    SizedBox(height: 12.h),

                    // ---------------------------------------------------------------------------
                    // Input
                    // ---------------------------------------------------------------------------
                    TextFormField(
                      controller: controller,
                      keyboardType: fieldType == 'phoneNumber'
                          ? TextInputType.number
                          : TextInputType.emailAddress,
                      textDirection: detectTextDirection(controller.text),
                      textAlign: getTextAlign(context),
                      style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp),
                      maxLength: fieldType == 'phoneNumber' ? 10 : 100,
                      decoration: getInputDecoration(hintText: hintText).copyWith(
                        counterText: "",
                        errorText: errorMessage,
                        prefixText:
                        fieldType == 'phoneNumber' ? "+963 | " : null,
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (fieldType == 'phoneNumber' &&
                                controller.text.isNotEmpty &&
                                normalizePhoneNumber(controller.text) !=
                                    originalNormalizedValue)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6.w),
                                child: Container(
                                  width: 20.w,
                                  height: 20.w,
                                  decoration: BoxDecoration(
                                    color: _isValidPhoneNumber(controller.text)
                                        ? AppColors.main.withOpacity(0.8)
                                        : AppColors.red.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isValidPhoneNumber(controller.text)
                                        ? Icons.check
                                        : Icons.close,
                                    color: Colors.white,
                                    size: 14.sp,
                                  ),
                                ),
                              ),
                            if (isNotVerified)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 6.h),
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
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(
                          RegExp(r'[\u0600-\u06FF]'),
                        ),
                      ],
                      onChanged: (_) => setState(() => errorMessage = null),
                    ),

                    SizedBox(height: 16.h),

                    // ---------------------------------------------------------------------------
                    // Save / Verify Button
                    // ---------------------------------------------------------------------------
                    ElevatedButton(
                      onPressed: isChecking
                          ? null
                          : () async {
                        final raw = controller.text.trim();
                        final normalized =
                        fieldType == 'phoneNumber'
                            ? normalizePhoneNumber(raw)
                            : raw;

                        // Validation
                        if (fieldType == 'phoneNumber' &&
                            !_isValidPhoneNumber(raw)) {
                          setState(() => errorMessage =
                              AppLocalizations.of(context)!
                                  .invalidPhoneNumber);
                          return;
                        }

                        if (fieldType == 'email' &&
                            !emailRegex.hasMatch(raw)) {
                          setState(() => errorMessage =
                              AppLocalizations.of(context)!
                                  .invalidEmail);
                          return;
                        }

                        if (normalized == originalNormalizedValue) {
                          setState(() => errorMessage =
                              AppLocalizations.of(context)!.samePhone);
                          return;
                        }

                        setState(() => isChecking = true);

                        bool available;
                        if (fieldType == 'phoneNumber') {
                          available = await securityCubit
                              .checkPhoneAvailability(normalized);
                        } else {
                          available = await securityCubit.checkEmailAvailability(
                            raw.trim().toLowerCase(),
                          );

                        }

                        setState(() => isChecking = false);

                        if (!available) {
                          setState(() => errorMessage =
                          fieldType == 'phoneNumber'
                              ? AppLocalizations.of(context)!
                              .alreadyExistsPhone
                              : AppLocalizations.of(context)!
                              .alreadyExistsEmail);
                          return;
                        }

                        Navigator.pop(context);

                        _showOtpSheetWithCubit(
                          context,
                          fieldType: fieldType,
                          targetValue: normalized,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.main,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                        (fieldType == 'phoneNumber' && isNotVerified)
                            ? AppLocalizations.of(context)!.verify
                            : (fieldType == 'email' &&
                            originalNormalizedValue.isEmpty)
                            ? AppLocalizations.of(context)!.add
                            : AppLocalizations.of(context)!.save,
                        style: AppTextStyles.getTitle1(context)
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showOtpSheetWithCubit(
      BuildContext context, {
        required String fieldType,
        required String targetValue,
      }) {
    final security = context.read<AccountSecurityCubit>();
    final isPhone = fieldType == 'phoneNumber';

    // 🔹 اطلب OTP (ولا تهتم بالنتيجة هنا)
    if (isPhone) {
      security.requestPhoneOtp(targetValue);
    } else {
      security.requestEmailOtp(targetValue);
    }

    final otpController = TextEditingController();
    bool invalid = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return BlocConsumer<AccountSecurityCubit, AccountSecurityState>(
          listener: (context, s) async {
            // ✅ نجاح التحقق
            if (s is AccountOtpVerified) {
              Navigator.pop(context);
              await context.read<AccountProfileCubit>().loadProfile();
              context.read<AccountSecurityCubit>().reset();


              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isPhone
                        ? AppLocalizations.of(context)!.phoneUpdatedSuccess
                        : AppLocalizations.of(context)!.emailUpdatedSuccess,
                  ),
                  backgroundColor: AppColors.main,
                ),
              );
            }

            // ❌ فشل OTP request أو verify
            if (s is AccountSecurityError) {
              if (s.message.contains('OTP')) {
                // ابقَ في نفس الصفحة
                invalid = true;
                (context as Element).markNeedsBuild();
              } else {
                Navigator.pop(context);
              }

              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      _mapSecurityError(context, s.message),
                    ),
                    backgroundColor: AppColors.red,
                  ),
                );

            }

          },
          builder: (context, s) {
            final loading = s is AccountSecurityLoading;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: getInputDecoration(
                        hintText:
                        AppLocalizations.of(context)!.sixDigitCode,
                      ).copyWith(
                        errorText: invalid
                            ? AppLocalizations.of(context)!.invalidOtp
                            : null,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: loading
                          ? null
                          : () async {
                        final otp = otpController.text.trim();
                        if (otp.length != 6) {
                          invalid = true;
                          (context as Element).markNeedsBuild();
                          return;
                        }
                        if (isPhone) {
                          security.verifyPhoneOtp(targetValue, otp);
                        } else {
                          security.verifyEmailOtp(targetValue, otp);
                        }
                      },

                      child: loading
                          ? SizedBox(
                              height: 20.h,
                              width: 20.h,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(AppLocalizations.of(context)!.continueButton),
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




  ///====================================================///
  void _showChangePasswordSheet(BuildContext context) {
    final TextEditingController currentPasswordController =
    TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();

    bool isCurrentPasswordVisible = false;
    bool isNewPasswordVisible = false;
    bool isCurrentPasswordValid = true;
    bool isNewPasswordValid = false;
    bool isNewPasswordDifferent = true;
    String newPasswordStrength = "";
    Color newPasswordStrengthColor = Colors.transparent;
    bool isUpdating = false;

    final securityCubit = context.read<AccountSecurityCubit>();

    // ---------------------------------------------------------------------------
    // Password validation logic (نفس منطقك السابق)
    // ---------------------------------------------------------------------------
    void validateNewPassword(String password, Function setState) {
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
      final hasSymbol =
      password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      final hasExcessiveRepeatedCharacters =
      password.contains(RegExp(r'(.)\1{2,}'));
      final isSimplePattern =
      password.contains(RegExp(r'(abcd|qwerty|1234)'));

      if (password.length < 8 || isSimplePattern) {
        setState(() {
          newPasswordStrength =
              AppLocalizations.of(context)!.weakPassword;
          newPasswordStrengthColor = AppColors.red;
          isNewPasswordValid = false;
        });
      } else if (hasExcessiveRepeatedCharacters &&
          (!hasUppercase ||
              !hasLowercase ||
              !hasNumber ||
              !hasSymbol)) {
        setState(() {
          newPasswordStrength =
              AppLocalizations.of(context)!.fairPassword;
          newPasswordStrengthColor = Colors.orange;
          isNewPasswordValid = false;
        });
      } else if (!hasUppercase ||
          !hasLowercase ||
          !hasNumber ||
          !hasSymbol) {
        setState(() {
          newPasswordStrength =
              AppLocalizations.of(context)!.fairPassword;
          newPasswordStrengthColor = Colors.orange;
          isNewPasswordValid = false;
        });
      } else if (password.length < 12) {
        setState(() {
          newPasswordStrength =
              AppLocalizations.of(context)!.goodPassword;
          newPasswordStrengthColor = Colors.green.shade300;
          isNewPasswordValid = true;
        });
      } else {
        setState(() {
          newPasswordStrength =
              AppLocalizations.of(context)!.strongPassword;
          newPasswordStrengthColor = Colors.green.shade800;
          isNewPasswordValid = true;
        });
      }
    }

    void checkPasswordsDifference(Function setState) {
      setState(() {
        isNewPasswordDifferent =
            currentPasswordController.text.trim() !=
                newPasswordController.text.trim();
      });
    }

    // ---------------------------------------------------------------------------
    // Bottom Sheet
    // ---------------------------------------------------------------------------
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return BlocListener<AccountSecurityCubit, AccountSecurityState>(
          listener: (context, state) {
            if (state is AccountPasswordInvalid) {
              setState(() {
                isUpdating = false;
                isCurrentPasswordValid = false;
              });
            }

            if (state is AccountSecurityError) {
              setState(() => isUpdating = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.somethingWentWrong,
                  ),
                  backgroundColor: AppColors.red,
                ),
              );
            }

            if (state is AccountPasswordChanged) {
              Navigator.pop(context);
            }
          },
          child: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ---------------------------------------------------------------------------
                      // Header
                      // ---------------------------------------------------------------------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.changePassword,
                            style: AppTextStyles.getTitle1(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),

                      SizedBox(height: 12.h),

                      // ---------------------------------------------------------------------------
                      // Current Password
                      // ---------------------------------------------------------------------------
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: !isCurrentPasswordVisible,
                        style: AppTextStyles.getText2(context)
                            .copyWith(fontSize: 12.sp),
                        textDirection: detectTextDirection(
                            currentPasswordController.text),
                        textAlign: getTextAlign(context),
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(
                            RegExp(r'[\u0600-\u06FF]'),
                          ),
                        ],
                        decoration: getInputDecoration(
                          hintText:
                          AppLocalizations.of(context)!.currentPassword,
                        ).copyWith(
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 10.h, horizontal: 12.w),
                          errorText: isCurrentPasswordValid
                              ? null
                              : AppLocalizations.of(context)!
                              .incorrectCurrentPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              isCurrentPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 16.sp,
                            ),
                            onPressed: () => setState(() =>
                            isCurrentPasswordVisible =
                            !isCurrentPasswordVisible),
                          ),
                        ),
                      ),

                      SizedBox(height: 12.h),

                      // ---------------------------------------------------------------------------
                      // New Password
                      // ---------------------------------------------------------------------------
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: !isNewPasswordVisible,
                        style: AppTextStyles.getText2(context)
                            .copyWith(fontSize: 12.sp),
                        textDirection: detectTextDirection(
                            newPasswordController.text),
                        textAlign: getTextAlign(context),
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(
                            RegExp(r'[\u0600-\u06FF]'),
                          ),
                        ],
                        onChanged: (value) {
                          validateNewPassword(value, setState);
                          checkPasswordsDifference(setState);
                        },
                        decoration: getInputDecoration(
                          hintText:
                          AppLocalizations.of(context)!.newPassword,
                        ).copyWith(
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 10.h, horizontal: 12.w),
                          errorText: isNewPasswordDifferent
                              ? null
                              : AppLocalizations.of(context)!
                              .passwordMatchError,
                          suffixIcon: IconButton(
                            icon: Icon(
                              isNewPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 16.sp,
                            ),
                            onPressed: () => setState(() =>
                            isNewPasswordVisible =
                            !isNewPasswordVisible),
                          ),
                        ),
                      ),

                      SizedBox(height: 6.h),
                      Text(
                        newPasswordStrength,
                        style: TextStyle(
                          color: newPasswordStrengthColor,
                          fontSize: 12,
                        ),
                      ),

                      SizedBox(height: 16.h),

                      // ---------------------------------------------------------------------------
                      // Save Button
                      // ---------------------------------------------------------------------------
                      ElevatedButton(
                        onPressed: isUpdating ||
                            !isNewPasswordValid ||
                            !isNewPasswordDifferent
                            ? null
                            : () async {
                          setState(() => isUpdating = true);

                          await securityCubit.changePassword(
                            current: currentPasswordController.text
                                .trim(),
                            next: newPasswordController.text.trim(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.main,
                          padding:
                          EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize:
                          Size(double.infinity, 50.h),
                        ),
                        child: isUpdating
                            ? SizedBox(
                          width: 16.w,
                          height: 16.h,
                          child:
                          const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                            AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        )
                            : Text(
                          AppLocalizations.of(context)!.save,
                          style: AppTextStyles.getTitle1(
                              context)
                              .copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
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
                'assets/images/encrypted.webp',
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
              // ------------------------------------------------------------------
              // Header
              // ------------------------------------------------------------------
              Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      AppLocalizations.of(context)!.twoFactorAuth,
                      style: AppTextStyles.getTitle1(context)
                          .copyWith(fontWeight: FontWeight.bold),
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
                'assets/images/two_factor.webp',
                height: 100.h,
              ),

              SizedBox(height: 20.h),

              // ------------------------------------------------------------------
              // Status Badge
              // ------------------------------------------------------------------
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: is2FAEnabled
                      ? const Color(0xFFDFF6F3)
                      : const Color(0xFFFFEAE6),
                  borderRadius: BorderRadius.circular(30.r),
                ),
                child: Text(
                  is2FAEnabled
                      ? AppLocalizations.of(context)!.activated
                      : AppLocalizations.of(context)!.notActivated,
                  style: TextStyle(
                    color: is2FAEnabled
                        ? const Color(0xFF00B7A0)
                        : const Color(0xFFFF6B6B),
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              // ------------------------------------------------------------------
              // Description
              // ------------------------------------------------------------------
              Text(
                AppLocalizations.of(context)!.twoFactorAuthHeadline,
                textAlign: TextAlign.center,
                style: AppTextStyles.getText2(context).copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                AppLocalizations.of(context)!.twoFactorAuthFullDescription,
                textAlign: TextAlign.center,
                style: AppTextStyles.getText3(context),
              ),

              SizedBox(height: 20.h),

              // ------------------------------------------------------------------
              // Action Button (Cubit only)
              // ------------------------------------------------------------------
              BlocBuilder<AccountSecurityCubit, AccountSecurityState>(
                builder: (context, state) {
                  final isLoading = state is AccountSecurityUpdating;

                  return ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                      final newValue = !is2FAEnabled;

                      // ----------------------------------------------
                      // Confirm before deactivation
                      // ----------------------------------------------
                      if (!newValue) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 24.w,
                              vertical: 20.h,
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!
                                      .deactivate2FA,
                                  style:
                                  AppTextStyles.getTitle2(context),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  AppLocalizations.of(context)!
                                      .twoFactorDeactivateWarning,
                                  style:
                                  AppTextStyles.getText2(context),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 24.h),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.red,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 24.w,
                                      vertical: 12.h,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(10.r),
                                    ),
                                  ),
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: Text(
                                    AppLocalizations.of(context)!
                                        .deactivate2FA,
                                    style: AppTextStyles.getText2(context)
                                        .copyWith(color: Colors.white),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(
                                    AppLocalizations.of(context)!.cancel,
                                    style: AppTextStyles.getText2(context)
                                        .copyWith(
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

                      // ----------------------------------------------
                      // Cubit call ONLY
                      // ----------------------------------------------
                      context
                          .read<AccountSecurityCubit>()
                          .toggleTwoFactor(enable: newValue);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.main,
                      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Text(
                      is2FAEnabled
                          ? AppLocalizations.of(context)!.deactivate2FA
                          : AppLocalizations.of(context)!.activate2FA,
                      style: AppTextStyles.getText2(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
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
        return BlocBuilder<AccountDangerCubit, AccountDangerState>(
            builder: (context, state) {
              final isLoading = state is AccountDangerLoading;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ------------------------------------------------------------------
                  // Header
                  // ------------------------------------------------------------------
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: Text(
                          AppLocalizations.of(context)!.deleteMyAccount,
                          style: AppTextStyles.getTitle1(context).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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

                  // ------------------------------------------------------------------
                  // Warning Text
                  // ------------------------------------------------------------------
                  Text(
                    AppLocalizations.of(context)!.deleteAccountWarningText,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 16.h),

                  // ------------------------------------------------------------------
                  // Cancel
                  // ------------------------------------------------------------------
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

                  // ------------------------------------------------------------------
                  // Confirm Delete (🔥 ONLY Cubit Call)
                  // ------------------------------------------------------------------
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context); // ⬅️ أغلق الشيت فقط
                      await context.read<AccountDangerCubit>().deleteMyAccount();
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Text(
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
          }
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

  String _mapSecurityError(BuildContext context, String code) {
    switch (code) {
      case 'INVALID_OTP':
        return AppLocalizations.of(context)!.invalidOtp;

      case 'OTP_REQUEST_FAILED':
        return AppLocalizations.of(context)!.otpRequestFailed;

      case 'PHONE_ALREADY_EXISTS':
        return AppLocalizations.of(context)!.alreadyExistsPhone;

      case 'EMAIL_ALREADY_EXISTS':
        return AppLocalizations.of(context)!.alreadyExistsEmail;

      case 'TWO_FACTOR_UPDATE_FAILED':
        return AppLocalizations.of(context)!.twoFactorUpdateFailed;

      default:
        return AppLocalizations.of(context)!.somethingWentWrong;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AppAuthState>(
      builder: (context, authState) {

        if (authState is AuthUnauthenticated) {
          return Scaffold(
            backgroundColor: AppColors.background2,
            body: _buildLoginPrompt(context),
          );
        }

        if (authState is AuthLoading || authState is AuthInitial) {
          return Scaffold(
            backgroundColor: AppColors.background2,
            body: _buildShimmerLoading(),
          );
        }

        if (authState is AuthAuthenticated) {
          return _AuthenticatedAccountView(
            onLogout: widget.onLogout,
            buildShimmer: _buildShimmerLoading,
            buildAccountContent: _buildAccountContent,
            mapSecurityError: _mapSecurityError,
          );
        }


        return const SizedBox.shrink();
      },
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
              'assets/images/account_banner.webp',
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
          Expanded(
            child: ListView(
              children: [
                SizedBox(height: 5.h),
                _buildAccountBannerCard(),
                SizedBox(height: 5.h),
                _buildPointsCard(context, state),
                Divider(color: Colors.grey[200], height: 2.h),
                _buildSectionTitle(AppLocalizations.of(context)!.personalInformation),
                Divider(color: Colors.grey[200], height: 2.h),
                BlocBuilder<AccountProfileCubit, AccountProfileState>(
                  builder: (context, profileState) {
                    final subtitle = profileState is AccountProfileLoaded
                        ? profileState.fullName
                        : AppLocalizations.of(context)!.loading;

                    return _buildEditableListTile(
                      Icons.person,
                      AppLocalizations.of(context)!.myProfile,
                      subtitle,
                      'profile',
                    );
                  },
                ),
                Divider(color: Colors.grey[200], height: 2.h),
                _buildEditableListTile(Icons.people, AppLocalizations.of(context)!.myRelatives, AppLocalizations.of(context)!.myRelativesDescription, 'firstName'),
                Divider(color: Colors.grey[200], height: 2.h),
                const SizedBox(height: 15),
                _buildSectionTitle(AppLocalizations.of(context)!.loginSection),
                Divider(color: Colors.grey[200], height: 2.h),
                BlocBuilder<AccountProfileCubit, AccountProfileState>(
                  builder: (context, profileState) {
                    final phone = profileState is AccountProfileLoaded
                        ? profileState.phone
                        : '';

                    final isVerified = profileState is AccountProfileLoaded
                        ? profileState.isPhoneVerified
                        : false;

                    final subtitle = phone.isEmpty
                        ? AppLocalizations.of(context)!.notProvided
                        : _formatPhoneForDisplay(phone);

                    return _buildEditableListTile(
                      Icons.phone,
                      AppLocalizations.of(context)!.phone,
                      subtitle,
                      'phoneNumber',
                      isVerified: isVerified,
                    );
                  },
                ),
                Divider(color: Colors.grey[200], height: 2.h),
                BlocBuilder<AccountProfileCubit, AccountProfileState>(
                  builder: (context, profileState) {
                    final email = profileState is AccountProfileLoaded
                        ? profileState.email
                        : '';

                    final isVerified = profileState is AccountProfileLoaded
                        ? profileState.isEmailVerified
                        : false;

                    final subtitle = email.isEmpty
                        ? AppLocalizations.of(context)!.notProvided
                        : email;

                    return _buildEditableListTile(
                      Icons.email,
                      AppLocalizations.of(context)!.email,
                      subtitle,
                      'email',
                      isVerified: isVerified,
                    );
                  },
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
            padding: EdgeInsets.symmetric(
              horizontal: Localizations.localeOf(context).languageCode == 'ar' ? 100.w : 80.w,
            ),
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

  Widget _buildPointsCard(BuildContext context, UserLoaded state) {
    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: () {
        Navigator.push(
          context,
          fadePageRoute(PointsHistoryPage(userId: state.userId)),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Container(
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: AppColors.main.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.main.withOpacity(0.25), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.main.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.stars, color: AppColors.main, size: 18.sp),
              ),
              SizedBox(width: 14.w),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.rewardPoints,
                    style: AppTextStyles.getTitle1(context)
                        .copyWith(color: AppColors.mainDark),
                  ),
                  SizedBox(height: 4.h),

                  Text(
                    "${state.userPoints} ${AppLocalizations.of(context)!.points}",
                    style: AppTextStyles.getText2(context)
                        .copyWith(color: AppColors.main),
                  ),
                ],
              ),

              const Spacer(),

              Icon(Icons.arrow_forward_ios, size: 14.sp, color: AppColors.main),
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
          final profile = context.read<AccountProfileCubit>().state;
          if (profile is AccountProfileLoaded) {
            _showEditFieldSheet(context, 'phoneNumber', profile.phone);
          }
        } else if (title == AppLocalizations.of(context)!.email) {
          final profile = context.read<AccountProfileCubit>().state;

          if (profile is AccountProfileLoaded) {
            final email = profile.email;

            _showEditFieldSheet(
              context,
              'email',
              email,
              customTitle: email.isEmpty
                  ? AppLocalizations.of(context)!.addEmailTitle
                  : null,
            );
          }
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
              BlocBuilder<AccountSecurityCubit, AccountSecurityState>(
                builder: (context, state) {
                  final bool isEnabled =
                      state is AccountBiometricState && state.enabled;

                  final bool isLoading = state is AccountBiometricChecking;

                  return Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isEnabled,
                      onChanged: isLoading
                          ? null
                          : (value) {
                        context
                            .read<AccountSecurityCubit>()
                            .toggleBiometric(enable: value);
                      },
                      activeColor: Colors.white,
                      activeTrackColor: AppColors.main.withOpacity(0.8),
                      inactiveTrackColor: Colors.grey[400],
                      trackOutlineColor:
                      WidgetStateProperty.all(Colors.transparent),
                      materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                      thumbColor:
                      WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.main;
                        }
                        return Colors.grey[400]!;
                      }),
                      thumbIcon:
                      WidgetStateProperty.resolveWith<Icon?>((states) {
                        return const Icon(
                          Icons.circle,
                          size: 30,
                          color: Colors.white,
                        );
                      }),
                    ),
                  );
                },
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


class _AuthenticatedAccountView extends StatelessWidget {
  final VoidCallback onLogout;

  final Widget Function() buildShimmer;
  final Widget Function(BuildContext, UserLoaded) buildAccountContent;
  final String Function(BuildContext, String) mapSecurityError;

  const _AuthenticatedAccountView({
    required this.onLogout,
    required this.buildShimmer,
    required this.buildAccountContent,
    required this.mapSecurityError,
  });


  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [

        // 👤 User loaded → load account profile
        BlocListener<UserCubit, UserState>(
          listenWhen: (_, current) => current is UserLoaded,
          listener: (context, state) {
            context.read<AccountProfileCubit>().loadProfile();
          },
        ),

        // 🔐 Account Security listeners
        BlocListener<AccountSecurityCubit, AccountSecurityState>(
          listenWhen: (_, s) => s is AccountSecurityError,
          listener: (context, s) {
            final error = s as AccountSecurityError;

            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    mapSecurityError(context, error.message),
                  ),
                  backgroundColor: AppColors.red,
                ),
              );
          },
        ),

        BlocListener<AccountSecurityCubit, AccountSecurityState>(
          listenWhen: (_, s) => s is AccountPasswordChanged,
          listener: (context, s) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.passwordUpdatedSuccess,
                  ),
                  backgroundColor: AppColors.main,
                ),
              );
          },
        ),

        BlocListener<AccountSecurityCubit, AccountSecurityState>(
          listenWhen: (_, s) =>
          s is AccountOtpSent || s is AccountOtpVerified,
          listener: (context, s) {
            if (s is AccountOtpSent) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 20),
                    backgroundColor: AppColors.mainDark,
                    content: Text('OTP: ${s.otp}'),
                  ),
                );
            }

            if (s is AccountOtpVerified) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            }
          },
        ),

        BlocListener<AccountSecurityCubit, AccountSecurityState>(
          listenWhen: (_, s) => s is AccountTwoFactorUpdated,
          listener: (context, s) {
            final state = s as AccountTwoFactorUpdated;

            Navigator.pop(context);

            context.read<UserCubit>().loadUserData(
              context: context,
              useCache: false,
            );

            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    state.enabled
                        ? AppLocalizations.of(context)!
                        .twoFactorActivatedSuccess
                        : AppLocalizations.of(context)!
                        .twoFactorDeactivatedSuccess,
                  ),
                  backgroundColor: AppColors.main,
                ),
              );
          },
        ),

        BlocListener<AccountSecurityCubit, AccountSecurityState>(
          listenWhen: (_, s) => s is AccountBiometricUpdated,
          listener: (context, s) {
            final state = s as AccountBiometricUpdated;

            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    state.enabled
                        ? AppLocalizations.of(context)!.faceIdEnabled
                        : AppLocalizations.of(context)!.faceIdDisabled,
                  ),
                  backgroundColor: AppColors.main,
                ),
              );
          },
        ),

        // ☠️ Account danger
        BlocListener<AccountDangerCubit, AccountDangerState>(
          listener: (context, s) async {
            if (s is AccountDangerError) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(s.message),
                    backgroundColor: AppColors.red,
                  ),
                );
            }

            if (s is AccountDangerSuccess) {
              await context.read<AuthCubit>().signOut();

              Navigator.pushAndRemoveUntil(
                context,
                fadePageRoute(const GoodbyePage()),
                    (_) => false,
              );
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background2,
        body: BlocBuilder<UserCubit, UserState>(
          builder: (context, state) {
            if (state is UserLoading) {
              return buildShimmer();
            }

            if (state is UserLoaded) {
              return buildAccountContent(context, state);
            }

            return buildShimmer();
          },
        ),
      ),
    );
  }
}
