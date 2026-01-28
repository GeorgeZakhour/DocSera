import 'dart:async';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/forgot_password/reset_password_page.dart';
import 'package:docsera/services/supabase/supabase_otp_service.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import '../../../app/const.dart';
import '../../../utils/full_page_loader.dart';

class OtpVerificationPage extends StatefulWidget {
  final String email;

  const OtpVerificationPage({super.key, required this.email});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final SupabaseOTPService _otpService = SupabaseOTPService();
  final TextEditingController _codeController = TextEditingController();
  
  bool _isLoading = false;
  int _secondsRemaining = 30; // 30 seconds cooldown
  Timer? _resendTimer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _secondsRemaining = 30;
      _canResend = false;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() => _canResend = true);
        timer.cancel();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _resendCode() async {
    final local = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      await _otpService.sendForgotPasswordOtp(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(local.emailSentTitle), backgroundColor: Colors.green),
        );
      }
      _startResendTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${local.errorOccurred}: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final local = AppLocalizations.of(context)!;
    final code = _codeController.text.trim();
    if (code.length != 6) return;

    setState(() => _isLoading = true);

    try {
      final isValid = await _otpService.validateForgotPasswordOtp(widget.email, code);
      
      if (!isValid) {
        throw Exception(local.invalidCode);
      }

      if (mounted) {
        Navigator.push(
          context,
          fadePageRoute(ResetPasswordPage(email: widget.email, code: code)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${local.errorOccurred}: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return BaseScaffold(
      title: Text(local.verificationCode, style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            SizedBox(height: 20.h),
            Icon(Icons.mark_email_read_outlined, size: 50.sp, color: AppColors.main),
            SizedBox(height: 20.h),
            Text(
              local.otpSentTo,
              style: AppTextStyles.getTitle2(context),
            ),
             Text(
              widget.email,
              style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 30.h),
            
            TextFormField(
                controller: _codeController,
                textDirection: detectTextDirection(_codeController.text),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: AppTextStyles.getTitle1(context).copyWith(fontSize: 24.sp, letterSpacing: 5),
                decoration: InputDecoration(
                  labelText: local.otpLabel,
                  labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey, letterSpacing: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: AppColors.main, width: 2),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              
            SizedBox(height: 20.h),
            
            GestureDetector(
                onTap: _canResend ? _resendCode : null,
                child: Text(
                  _canResend
                      ? local.resendCode
                      : '${local.resendCode.split('?')[0]}? $_secondsRemaining ${local.seconds}', // Using split to remove potential extra text if resendCode is "Resend?" 
                      // Actually local.resendCode is "Didn't receive the code? Tap to resend."
                      // Let's just use local.didntReceiveCode (Line 575: "Didn't receive a code?") for brevity or construct correctly.
                      // Line 589: didntReceiveCode: "Didn't receive the code?"
                      // Wait, line 589 in my view was: "didntReceiveCode": "Didn't receive the code?",
                      // I will just use local.didntReceiveCode.
                  style: AppTextStyles.getText3(context).copyWith(
                    color: _canResend ? AppColors.main : Colors.grey,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              
             SizedBox(height: 40.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isLoading || _codeController.text.length != 6) ? null : _verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: _isLoading 
                ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                  local.verify,
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
