import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/forgot_password/otp_verification_page.dart';
import 'package:docsera/services/supabase/supabase_otp_service.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import '../../../app/const.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final SupabaseOTPService _otpService = SupabaseOTPService();
  bool _isLoading = false;

  void _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _otpService.sendForgotPasswordOtp(email);
      if (mounted) {
        // Show confirmation dialog before navigating
        await showDialog(
          context: context, 
          builder: (context) => AlertDialog(
             backgroundColor: Colors.white,
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              title: Text(
                AppLocalizations.of(context)!.emailSentTitle, 
                style: AppTextStyles.getTitle2(context).copyWith(color: AppColors.mainDark),
                textAlign: TextAlign.center,
              ),
             content: Text(
                AppLocalizations.of(context)!.codeSentMessage(email), 
                style: AppTextStyles.getText2(context),
                textAlign: TextAlign.center,
             ),
             actionsAlignment: MainAxisAlignment.center,
             actionsPadding: EdgeInsets.only(bottom: 24.h, left: 24.w, right: 24.w),
             actions: [
               SizedBox(
                 width: double.infinity,
                 child: ElevatedButton(
                   onPressed: () => Navigator.pop(context), 
                   style: ElevatedButton.styleFrom(
                     backgroundColor: AppColors.main,
                     padding: EdgeInsets.symmetric(vertical: 12.h),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                     elevation: 0,
                   ),
                   child: Text(
                     AppLocalizations.of(context)!.ok, 
                     style: AppTextStyles.getText2(context).copyWith(color: Colors.white, fontWeight: FontWeight.bold)
                   )
                 ),
               )
             ]
          )
        );

        if (mounted) {
          Navigator.push(
            context,
            fadePageRoute(OtpVerificationPage(email: email)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppLocalizations.of(context)!.errorOccurred}: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return BaseScaffold(
      title: Text(
        local.forgotPasswordTitle,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.h),
            Text(
              local.forgotPasswordTitle,
              style: AppTextStyles.getTitle2(context).copyWith(fontSize: 14.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              local.forgotPasswordSubtitle,
              style: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
            ),
            SizedBox(height: 30.h),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: AppTextStyles.getText2(context),
              decoration: InputDecoration(
                labelText: local.email,
                labelStyle: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: AppColors.main, width: 2),
                ),
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
              ),
            ),
            SizedBox(height: 40.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: _isLoading
                    ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                  local.sendCode,
                  style: AppTextStyles.getTitle2(context).copyWith(color: Colors.white, fontSize: 13.sp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
