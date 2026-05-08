import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/forgot_password/otp_verification_page.dart';
import 'package:docsera/services/supabase/supabase_otp_service.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import '../../../app/const.dart';

/// Forgot-password entry screen.
///
/// Channel is fixed by the caller — login_page passes the channel
/// matching the tab the user came from (phone+password vs
/// email+password). The reset flow then sends the OTP to that same
/// channel: phone via [SupabaseOTPService.sendForgotPasswordPhoneOtp]
/// (Syriatel SMS), email via [SupabaseOTPService.sendForgotPasswordOtp].
///
/// We deliberately don't expose a channel toggle here: an account is
/// created with one auth method and only that method can be used to
/// recover it. Showing both options would invite the user to type
/// the wrong identifier and hit a silent anti-enumeration dead-end.
class ForgotPasswordPage extends StatefulWidget {
  final bool initialPhoneMode;
  final String? prefilledIdentifier;

  const ForgotPasswordPage({
    super.key,
    this.initialPhoneMode = false,
    this.prefilledIdentifier,
  });

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final SupabaseOTPService _otpService = SupabaseOTPService();
  final RegExp _phoneRegex = RegExp(r'^09\d{8}$');

  bool _isLoading = false;
  late bool _isPhoneMode;

  @override
  void initState() {
    super.initState();
    _isPhoneMode = widget.initialPhoneMode;
    final pre = (widget.prefilledIdentifier ?? '').trim();
    if (pre.isNotEmpty) {
      if (_isPhoneMode || RegExp(r'^09\d{0,8}$').hasMatch(pre)) {
        _phoneController.text = pre;
        _isPhoneMode = true;
      } else {
        _emailController.text = pre;
        _isPhoneMode = false;
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _formattedPhone() {
    var p = _phoneController.text.trim();
    if (p.startsWith('09')) p = p.substring(1);
    return '00963$p';
  }

  Future<void> _sendCode() async {
    final local = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      if (_isPhoneMode) {
        if (!_phoneRegex.hasMatch(_phoneController.text.trim())) return;
        final phone = _formattedPhone();
        await _otpService.sendForgotPasswordPhoneOtp(phone);
        if (!mounted) return;
        await _showSentDialog(
          title: local.smsSentTitle,
          body: local.codeSentMessagePhone(_phoneController.text.trim()),
        );
        if (!mounted) return;
        Navigator.push(
          context,
          fadePageRoute(OtpVerificationPage(
            isPhoneMode: true,
            phone: phone,
            displayValue: _phoneController.text.trim(),
          )),
        );
      } else {
        final email = _emailController.text.trim();
        if (email.isEmpty) return;
        await _otpService.sendForgotPasswordOtp(email);
        if (!mounted) return;
        await _showSentDialog(
          title: local.emailSentTitle,
          body: local.codeSentMessage(email),
        );
        if (!mounted) return;
        Navigator.push(
          context,
          fadePageRoute(OtpVerificationPage(
            isPhoneMode: false,
            email: email,
            displayValue: email,
          )),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${local.errorOccurred}: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSentDialog({required String title, required String body}) {
    final local = AppLocalizations.of(context)!;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          title,
          style: AppTextStyles.getTitle2(context).copyWith(color: AppColors.mainDark),
          textAlign: TextAlign.center,
        ),
        content: Text(
          body,
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
                local.ok,
                style: AppTextStyles.getText2(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  bool get _canSubmit {
    if (_isLoading) return false;
    if (_isPhoneMode) {
      return _phoneRegex.hasMatch(_phoneController.text.trim());
    }
    return _emailController.text.trim().isNotEmpty;
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
              _isPhoneMode
                  ? local.forgotPasswordSubtitlePhone
                  : local.forgotPasswordSubtitle,
              style: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
            ),
            SizedBox(height: 20.h),
            if (_isPhoneMode)
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: AppTextStyles.getText2(context),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: local.phoneNumber,
                  hintText: local.forgotPasswordPhoneFieldHint,
                  labelStyle: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                  hintStyle: AppTextStyles.getText3(context)
                      .copyWith(color: Colors.grey.withValues(alpha: 0.5)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: AppColors.main, width: 2),
                  ),
                  prefixIcon: const Icon(Icons.phone_android, color: Colors.grey),
                ),
              )
            else
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.getText2(context),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: local.email,
                  hintText: local.forgotPasswordEmailFieldHint,
                  labelStyle: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                  hintStyle: AppTextStyles.getText3(context)
                      .copyWith(color: Colors.grey.withValues(alpha: 0.5)),
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
                onPressed: _canSubmit ? _sendCode : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canSubmit ? AppColors.main : Colors.grey,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        local.sendCode,
                        style: AppTextStyles.getTitle2(context)
                            .copyWith(color: Colors.white, fontSize: 13.sp),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
