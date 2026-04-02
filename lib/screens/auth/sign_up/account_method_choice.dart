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
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          // Background Aesthetic Shapes for Light Glass UI
          Positioned(
            top: -50.h,
            right: -50.w,
            child: Container(
              width: 300.w,
              height: 300.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.main.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -100.h,
            left: -50.w,
            child: Container(
              width: 350.w,
              height: 350.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mainDark.withOpacity(0.05),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(color: Colors.white.withOpacity(0.2)),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom AppBar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_ios, color: AppColors.mainDark, size: 22.sp),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20.h),
                        Text(
                          AppLocalizations.of(context)!.createAnAccount,
                          style: TextStyle(
                            color: AppColors.mainDark,
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          AppLocalizations.of(context)!.chooseRegistrationMethod,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12.sp,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 40.h),

                        // The 2 Big Glassy Tabs / Choice Cards
                        _buildGlassCard(
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
                        
                        SizedBox(height: 20.h),

                        _buildGlassCard(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isRecommended,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28.r),
          boxShadow: isRecommended 
              ? [BoxShadow(color: AppColors.main.withOpacity(0.12), blurRadius: 25, spreadRadius: 2)] 
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, spreadRadius: 1)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: isRecommended ? Colors.white.withOpacity(0.8) : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(28.r),
                border: Border.all(
                  color: isRecommended ? AppColors.main.withOpacity(0.3) : Colors.white.withOpacity(0.8),
                  width: isRecommended ? 1.5 : 1.0,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                   Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: isRecommended ? AppColors.main.withOpacity(0.12) : Colors.grey.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: isRecommended ? AppColors.mainDark : Colors.grey[600],
                          size: 26.sp,
                        ),
                      ),
                      SizedBox(width: 20.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: AppColors.mainDark,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 10.sp,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.grey[400],
                        size: 16.sp,
                      ),
                    ],
                  ),
                  if (isRecommended)
                    Positioned(
                      top: -12.h,
                      right: -12.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: AppColors.main,
                          borderRadius: BorderRadius.circular(100.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.main.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.recommended,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
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
      ),
    );
  }
}
