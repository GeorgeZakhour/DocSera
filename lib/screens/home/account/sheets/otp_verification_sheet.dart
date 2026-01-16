import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/Business_Logic/Account_page/security/account_security_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/security/account_security_state.dart';
import 'package:docsera/Business_Logic/Account_page/profile/account_profile_cubit.dart';
import 'package:docsera/utils/input_decoration.dart';

class OtpVerificationSheet extends StatefulWidget {
  final String fieldType;
  final String targetValue;

  const OtpVerificationSheet({
    super.key,
    required this.fieldType,
    required this.targetValue,
  });

  @override
  State<OtpVerificationSheet> createState() => _OtpVerificationSheetState();
}

class _OtpVerificationSheetState extends State<OtpVerificationSheet> {
  final otpController = TextEditingController();
  bool invalid = false;

  @override
  void initState() {
    super.initState();
    // 🔹 Request OTP on init
    final security = context.read<AccountSecurityCubit>();
    if (widget.fieldType == 'phoneNumber') {
      security.requestPhoneOtp(widget.targetValue);
    } else {
      security.requestEmailOtp(widget.targetValue);
    }
  }

  String _mapSecurityError(BuildContext context, String code) {
    switch (code) {
      case 'INVALID_OTP':
        return AppLocalizations.of(context)!.invalidOtp;
      case 'OTP_REQUEST_FAILED':
        return AppLocalizations.of(context)!.otpRequestFailed;
      default:
        return AppLocalizations.of(context)!.somethingWentWrong;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = widget.fieldType == 'phoneNumber';

    return BlocConsumer<AccountSecurityCubit, AccountSecurityState>(
      listener: (context, s) async {
        // ✅ Verification Success
        if (s is AccountOtpVerified) {
          Navigator.pop(context);
          await context.read<AccountProfileCubit>().loadProfile();
          if (context.mounted) {
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
        }

        // ❌ Failure
        if (s is AccountSecurityError) {
          if (s.message.contains('OTP')) {
            // Stay on page
            setState(() {
              invalid = true;
            });
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
                    hintText: AppLocalizations.of(context)!.sixDigitCode,
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
                      setState(() {
                        invalid = true;
                      });
                      return;
                    }

                    final security = context.read<AccountSecurityCubit>();
                    if (isPhone) {
                      security.verifyPhoneOtp(widget.targetValue, otp);
                    } else {
                      security.verifyEmailOtp(widget.targetValue, otp);
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
  }
}
