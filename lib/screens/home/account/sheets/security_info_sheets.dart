import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/Business_Logic/Account_page/security/account_security_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/security/account_security_state.dart';

class EncryptedDocumentsSheet extends StatelessWidget {
  const EncryptedDocumentsSheet({super.key});

  @override
  Widget build(BuildContext context) {
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
  }
}

class TwoFactorAuthSheet extends StatelessWidget {
  final bool is2FAEnabled;

  const TwoFactorAuthSheet({super.key, required this.is2FAEnabled});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
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

          // Status Badge
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

          // Description
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

          // Action Button (Cubit only)
          BlocBuilder<AccountSecurityCubit, AccountSecurityState>(
            builder: (context, state) {
              final isLoading = state is AccountSecurityUpdating;

              return ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                  final newValue = !is2FAEnabled;

                  // Confirm before deactivation
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
                              AppLocalizations.of(context)!.deactivate2FA,
                              style: AppTextStyles.getTitle2(context),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              AppLocalizations.of(context)!
                                  .twoFactorDeactivateWarning,
                              style: AppTextStyles.getText2(context),
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
                                  borderRadius: BorderRadius.circular(10.r),
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

                  // Cubit call ONLY
                  if (context.mounted) {
                    context
                        .read<AccountSecurityCubit>()
                        .toggleTwoFactor(enable: newValue);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main,
                  padding: EdgeInsets.symmetric(
                      vertical: 14.h, horizontal: 14.h),
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
  }
}
