import 'dart:ui';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/sign_up_info.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/auth/sign_up/sign_up_phone.dart';
import 'package:docsera/screens/auth/sign_up/sign_up_email.dart';

class AccountMethodChoicePage extends StatelessWidget {
  const AccountMethodChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10.h),
              Text(
                AppLocalizations.of(context)!.createAnAccount,
                style: TextStyle(
                  color: AppColors.mainDark,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                AppLocalizations.of(context)!.chooseRegistrationMethod,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10.sp,
                ),
              ),
              SizedBox(height: 32.h),

                // Phone + OTP Selection (Recommended)
                _buildMethodCard(
                  context,
                  title: AppLocalizations.of(context)!.loginWithPhone,
                  subtitle: AppLocalizations.of(context)!.phoneOtpMethodDescription,
                  icon: Icons.phone_android_rounded,
                  isRecommended: true,
                  onTap: () {
                    final info = SignUpInfo();
                    info.authMethod = AuthMethod.phoneOtp;
                    Navigator.push(context, fadePageRoute(SignUpFirstPage(signUpInfo: info)));
                  },
                ),
                
                SizedBox(height: 16.h),

                // Email + Password Selection
                _buildMethodCard(
                  context,
                  title: AppLocalizations.of(context)!.loginWithEmail,
                  subtitle: AppLocalizations.of(context)!.emailPasswordMethodDescription,
                  icon: Icons.email_outlined,
                  isRecommended: false,
                  onTap: () {
                    final info = SignUpInfo();
                    info.authMethod = AuthMethod.emailPassword;
                    Navigator.push(context, fadePageRoute(EnterEmailPage(signUpInfo: info)));
                  },
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildMethodCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isRecommended,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.main.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: isRecommended ? AppColors.main.withOpacity(0.3) : Colors.grey[100]!,
                width: isRecommended ? 1.5 : 0.8,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: isRecommended ? AppColors.main.withOpacity(0.08) : Colors.grey[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: isRecommended ? AppColors.main : Colors.grey[500],
                        size: 22.sp,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.mainDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 9.sp,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.grey[300],
                      size: 14.sp,
                    ),
                  ],
                ),
                if (isRecommended)
                  Positioned(
                    top: -8.h,
                    right: -8.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: AppColors.main,
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.recommended,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
