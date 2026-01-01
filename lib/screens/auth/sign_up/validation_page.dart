import 'dart:async';
import 'package:docsera/screens/auth/sign_up/recap_info.dart';
import 'package:docsera/services/supabase/supabase_otp_service.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../app/const.dart';
import '../../../app/text_styles.dart';
import '../../../utils/full_page_loader.dart';
import '../../../utils/page_transitions.dart';
import '../../../models/sign_up_info.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class ValidationPage extends StatefulWidget {
  final String validationType; // 'SMS' or 'Email'
  final SignUpInfo signUpInfo; // Accept SignUpInfo to pass user data

  const ValidationPage({super.key, required this.validationType, required this.signUpInfo});

  @override
  State<ValidationPage> createState() => _ValidationPageState();
}

class _ValidationPageState extends State<ValidationPage> {
  final SupabaseOTPService _supabaseOTPService = SupabaseOTPService(); // Firestore Service
  final TextEditingController _codeController = TextEditingController();

  String sentCode = ""; // Store the sent OTP
  bool isCodeValid = true;
  bool isLoading = true; // Show loading indicator while sending OTP


  int _secondsRemaining = 60;

  Timer? _resendTimer;

  bool canResend = false;

  @override
  void initState() {
    super.initState();
    _sendOTP(); // Send OTP when the page loads
    // _startResendTimer();
  }



  /// Send OTP based on the validation type (SMS or Email)
  Future<void> _sendOTP() async {
    setState(() {
      isLoading = true;
    });

    try {
      // --------------------------------------------------
      // 📱 SMS (كما هو – OTP محلي + Snackbar)
      // --------------------------------------------------
      if (widget.validationType == 'SMS') {
        sentCode = await _supabaseOTPService
            .sendOTPToPhone(widget.signUpInfo.phoneNumber!);

        debugPrint('Sent SMS OTP: $sentCode'); // Debug only

        // ✅ إظهار OTP في Snackbar (Debug فقط)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP: $sentCode'),
            backgroundColor: AppColors.main.withOpacity(0.9),
            duration: const Duration(seconds: 10),
          ),
        );
      }

      // --------------------------------------------------
      // 📧 Email (Edge Function فقط – بدون OTP محلي)
      // --------------------------------------------------
      else if (widget.validationType == 'Email') {
        await _supabaseOTPService
            .sendEmailOtp(widget.signUpInfo.email!);
      }

      setState(() {
        isLoading = false;
      });

      _startResendTimer();
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      final errorMessage = e.toString();

      // 🔒 Rate limit (OTP_TOO_FREQUENT)
      if (errorMessage.contains('429') ||
          errorMessage.contains('OTP_TOO_FREQUENT')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!
                  .pleaseWaitBeforeRequestingAnotherCode,
            ),
            backgroundColor: AppColors.red.withOpacity(0.85),
          ),
        );
        return;
      }

      // ❌ Generic error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.otpSendFailed),
          backgroundColor: AppColors.red.withOpacity(0.8),
          action: SnackBarAction(
            label: AppLocalizations.of(context)!.tryAgain,
            textColor: Colors.white,
            onPressed: _sendOTP,
          ),
        ),
      );
    }

  }

  /// Validate the entered OTP
  Future<void> _validateCode() async {
    // --------------------------------------------------
    // 📱 SMS (كما هو – مقارنة محلية)
    // --------------------------------------------------
    if (widget.validationType == 'SMS') {
      setState(() {
        isCodeValid = _codeController.text == sentCode;
      });

      if (!isCodeValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.invalidCode),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }

      // SMS صحيح
      if (widget.signUpInfo.email == null) {
        Navigator.push(
          context,
          fadePageRoute(
            RecapPage(
              signUpInfo: widget.signUpInfo..phoneVerified = true,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          fadePageRoute(
            ValidationPage(
              validationType: 'Email',
              signUpInfo: widget.signUpInfo..phoneVerified = true,
            ),
          ),
        );
      }

      return;
    }

    // --------------------------------------------------
    // 📧 Email (RPC تحقق – بدون معرفة OTP)
    // --------------------------------------------------
    if (widget.validationType == 'Email') {
      final isValid = await _supabaseOTPService.verifyEmailOtp(
        widget.signUpInfo.email!,
        _codeController.text,
      );

      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.invalidCode),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }

      Navigator.push(
        context,
        fadePageRoute(
          RecapPage(
            signUpInfo: widget.signUpInfo..emailVerified = true,
          ),
        ),
      );
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _secondsRemaining = 60;
      canResend = false;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          canResend = true;
        });
        timer.cancel();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  String _getDisplayPhoneNumber(String input) {
    if (input.startsWith('00963') && input.length > 5) {
      return '0${input.substring(5)}';
    }
    return input;
  }


  @override
  Widget build(BuildContext context) {
    final isSMS = widget.validationType == 'SMS';

    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.signUp,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Icon and Title
            Center(
              child: Column(
                children: [
                  SizedBox(height: 20.h),
                  Icon(
                    isSMS ? Icons.phone : Icons.email,
                    color: AppColors.main,
                    size: 40.sp,
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    isSMS
                        ? AppLocalizations.of(context)!.enterSmsCode
                        : AppLocalizations.of(context)!.enterEmailCode,
                    style: AppTextStyles.getTitle2(context),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            if (isLoading)
              const Center(child: FullPageLoader())
            else ...[
              // OTP Input Field
              TextFormField(
                controller: _codeController,
                textDirection: detectTextDirection(_codeController.text),
                textAlign: getTextAlign(context),
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.otpLabel,
                  labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                  errorText: isCodeValid ? null : AppLocalizations.of(context)!.invalidCode,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.r),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.r),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.r),
                    borderSide: const BorderSide(color: AppColors.main, width: 2),
                  ),
                ),
                onChanged: (value) {
                  setState(() {}); // ✅ Forces UI to update based on the entered OTP
                },
              ),
              SizedBox(height: 10.h),

              // OTP Sent Information
              Text(
                AppLocalizations.of(context)!.otpSentTo,
                style: AppTextStyles.getText3(context),
              ),
              Text(
                isSMS ? _getDisplayPhoneNumber(widget.signUpInfo.phoneNumber!) : widget.signUpInfo.email!,
                style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5.h),
              GestureDetector(
                onTap: canResend ? _sendOTP : null,
                child: Text(
                  canResend
                      ? AppLocalizations.of(context)!.didntReceiveCode
                      : '${AppLocalizations.of(context)!.didntReceiveCode} $_secondsRemaining ${AppLocalizations.of(context)!.seconds}',
                  style: AppTextStyles.getText3(context).copyWith(
                    color: canResend ? AppColors.main : Colors.grey,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const Spacer(),

              // Progress Bar
              LinearProgressIndicator(
                value: 1.0,
                backgroundColor: AppColors.background2,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.main),
                minHeight: 4.h,
              ),
              SizedBox(height: 20.h),

              // Continue Button
              ElevatedButton(
                onPressed: _codeController.text.length == 6 ? _validateCode : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _codeController.text.length == 6 ? AppColors.main : Colors.grey,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.continueButton,
                      style: AppTextStyles.getText2(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
