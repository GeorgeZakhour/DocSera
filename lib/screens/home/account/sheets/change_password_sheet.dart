import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/Business_Logic/Account_page/security/account_security_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/security/account_security_state.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/utils/input_decoration.dart';

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
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

  void validateNewPassword(String password) {
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
    final hasExcessiveRepeatedCharacters = password.contains(RegExp(r'(.)\1{2,}'));
    final isSimplePattern = password.contains(RegExp(r'(abcd|qwerty|1234)'));

    if (password.length < 8 || isSimplePattern) {
      setState(() {
        newPasswordStrength = AppLocalizations.of(context)!.weakPassword;
        newPasswordStrengthColor = AppColors.red;
        isNewPasswordValid = false;
      });
    } else if (hasExcessiveRepeatedCharacters &&
        (!hasUppercase || !hasLowercase || !hasNumber || !hasSymbol)) {
      setState(() {
        newPasswordStrength = AppLocalizations.of(context)!.fairPassword;
        newPasswordStrengthColor = Colors.orange;
        isNewPasswordValid = false;
      });
    } else if (!hasUppercase || !hasLowercase || !hasNumber || !hasSymbol) {
      setState(() {
        newPasswordStrength = AppLocalizations.of(context)!.fairPassword;
        newPasswordStrengthColor = Colors.orange;
        isNewPasswordValid = false;
      });
    } else if (password.length < 12) {
      setState(() {
        newPasswordStrength = AppLocalizations.of(context)!.goodPassword;
        newPasswordStrengthColor = Colors.green.shade300;
        isNewPasswordValid = true;
      });
    } else {
      setState(() {
        newPasswordStrength = AppLocalizations.of(context)!.strongPassword;
        newPasswordStrengthColor = Colors.green.shade800;
        isNewPasswordValid = true;
      });
    }
  }

  void checkPasswordsDifference() {
    setState(() {
      isNewPasswordDifferent =
          currentPasswordController.text.trim() != newPasswordController.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
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
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
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

              // Current Password
              TextFormField(
                controller: currentPasswordController,
                obscureText: !isCurrentPasswordVisible,
                style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp),
                textDirection: detectTextDirection(currentPasswordController.text),
                textAlign: getTextAlign(context),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\u0600-\u06FF]')),
                ],
                decoration: getInputDecoration(
                  hintText: AppLocalizations.of(context)!.currentPassword,
                ).copyWith(
                  contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                  errorText: isCurrentPasswordValid
                      ? null
                      : AppLocalizations.of(context)!.incorrectCurrentPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      isCurrentPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      size: 16.sp,
                    ),
                    onPressed: () => setState(
                            () => isCurrentPasswordVisible = !isCurrentPasswordVisible),
                  ),
                ),
              ),

              SizedBox(height: 12.h),

              // New Password
              TextFormField(
                controller: newPasswordController,
                obscureText: !isNewPasswordVisible,
                style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp),
                textDirection: detectTextDirection(newPasswordController.text),
                textAlign: getTextAlign(context),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\u0600-\u06FF]')),
                ],
                onChanged: (value) {
                  validateNewPassword(value);
                  checkPasswordsDifference();
                },
                decoration: getInputDecoration(
                  hintText: AppLocalizations.of(context)!.newPassword,
                ).copyWith(
                  contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                  errorText: isNewPasswordDifferent
                      ? null
                      : AppLocalizations.of(context)!.passwordMatchError,
                  suffixIcon: IconButton(
                    icon: Icon(
                      isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      size: 16.sp,
                    ),
                    onPressed: () =>
                        setState(() => isNewPasswordVisible = !isNewPasswordVisible),
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

              // Save Button
              ElevatedButton(
                onPressed: isUpdating || !isNewPasswordValid || !isNewPasswordDifferent
                    ? null
                    : () async {
                  setState(() => isUpdating = true);

                  await context.read<AccountSecurityCubit>().changePassword(
                    current: currentPasswordController.text.trim(),
                    next: newPasswordController.text.trim(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                  style: AppTextStyles.getTitle1(context)
                      .copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
