import 'dart:async';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/forgot_password/reset_password_page.dart';
import 'package:docsera/services/supabase/supabase_otp_service.dart';
import 'package:docsera/utils/keyboard_insets.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import '../../../app/const.dart';

/// OTP entry screen for the forgot-password flow.
///
/// Channel-agnostic: caller passes either an [email] or a [phone]
/// (in 00963XXXXXXXXX form) plus [isPhoneMode]. Validation peeks
/// (without consuming) so the next screen can call the consume +
/// reset endpoint atomically. [displayValue] is what we show to the
/// user — for phone we show the human local form (09…), not the
/// 00963 form.
class OtpVerificationPage extends StatefulWidget {
  final bool isPhoneMode;
  final String? email;
  final String? phone;
  final String displayValue;

  const OtpVerificationPage({
    super.key,
    required this.isPhoneMode,
    this.email,
    this.phone,
    required this.displayValue,
  }) : assert(
          (isPhoneMode && phone != null) || (!isPhoneMode && email != null),
          'must provide phone in phone mode or email in email mode',
        );

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage>
    with WidgetsBindingObserver {
  final SupabaseOTPService _otpService = SupabaseOTPService();
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = false;
  int _secondsRemaining = 30;
  Timer? _resendTimer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startResendTimer();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
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
      if (widget.isPhoneMode) {
        await _otpService.sendForgotPasswordPhoneOtp(widget.phone!);
      } else {
        await _otpService.sendForgotPasswordOtp(widget.email!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isPhoneMode
                ? local.smsSentTitle
                : local.emailSentTitle),
            backgroundColor: Colors.green,
          ),
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
      final isValid = widget.isPhoneMode
          ? await _otpService.validateForgotPasswordPhoneOtp(widget.phone!, code)
          : await _otpService.validateForgotPasswordOtp(widget.email!, code);

      if (!isValid) {
        throw Exception(local.invalidCode);
      }

      if (mounted) {
        Navigator.push(
          context,
          fadePageRoute(ResetPasswordPage(
            isPhoneMode: widget.isPhoneMode,
            email: widget.email,
            phone: widget.phone,
            code: code,
          )),
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
    WidgetsBinding.instance.removeObserver(this);
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
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 20.w,
          bottom: 20.w + realKeyboardInset(context),
        ),
        child: Column(
          children: [
            SizedBox(height: 20.h),
            Icon(
              widget.isPhoneMode ? Icons.sms_outlined : Icons.mark_email_read_outlined,
              size: 50.sp,
              color: AppColors.main,
            ),
            SizedBox(height: 20.h),
            Text(
              local.otpSentTo,
              style: AppTextStyles.getTitle2(context),
            ),
            Text(
              widget.displayValue,
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
                    : '${local.resendCode.split('?')[0]}? $_secondsRemaining ${local.seconds}',
                style: AppTextStyles.getText3(context).copyWith(
                  color: _canResend ? AppColors.main : Colors.grey,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Spacer(),
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
