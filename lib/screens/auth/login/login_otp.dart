import 'dart:async';
import 'dart:io';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/utils/keyboard_insets.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:docsera/services/analytics/analytics_service.dart';
import 'package:docsera/services/analytics/analytics_event_catalog.dart';

import '../../../utils/full_page_loader.dart';

class LoginOTPPage extends StatefulWidget {
  final String? phoneNumber;
  final String? email;

  const LoginOTPPage({
    super.key,
    this.phoneNumber,
    this.email,
  }) : assert(phoneNumber != null || email != null, 'Either phone or email must be provided');

  @override
  State<LoginOTPPage> createState() => _LoginOTPPageState();
}

class _LoginOTPPageState extends State<LoginOTPPage> with WidgetsBindingObserver {
  final TextEditingController _codeController = TextEditingController();

  String sentCode = '';
  bool isCodeValid = true;
  bool isLoading = true;

  int _secondsRemaining = 20;
  Timer? _resendTimer;
  bool canResend = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sendOTP();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  Future<String> getDeviceId() async {
    final info = DeviceInfoPlugin();

    try {
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return ios.identifierForVendor ?? 'ios-unknown';
      }

      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return android.id ?? android.device ?? 'android-unknown';
      }

      return 'unknown-platform';
    } catch (e) {
      return 'unknown-device';
    }
  }


  Future<void> _sendOTP() async {
    setState(() {
      isLoading = true;
    });
    // Cache messenger + loc BEFORE the OTP-send await so the catch-arm
    // snackbar doesn't read context after potential unmount.
    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context)!;

    final channel = widget.email != null ? 'email' : 'phone';
    Analytics.instance.track(Events.otpRequested, {
      'channel': channel,
      'context': 'login',
    });

    try {

      if (widget.email != null) {
        // 📧 Email Flow (Edge Function)
        final res = await Supabase.instance.client.functions.invoke(
          'send_email_otp',
          body: {'email': widget.email},
        );
        if (res.status != 200) throw Exception('Failed to send email OTP');
        sentCode = 'SENT_VIA_EMAIL'; // Edge function doesn't return code
      } else {
        // 📱 Phone Flow — unified send_sms_otp edge function. Real
        // phones get Syriatel SMS; whitelisted test phones accept
        // "123456" via the function's TEST_PHONES bypass. The OTP
        // is hashed server-side and never returned to the client.
        final res = await Supabase.instance.client.functions.invoke(
          'send_sms_otp',
          body: {
            'phone': widget.phoneNumber,
            'purpose': 'login_2fa',
          },
        );
        if (res.status != 200) {
          throw Exception('Failed to send phone OTP');
        }
        sentCode = 'SENT_VIA_SMS';
      }
      setState(() {
        isLoading = false;
      });
      _startResendTimer();

      // ✅ عرض الـ OTP كـ Snackbar (للديفيلوبر فقط) - COMMENTED OUT FOR PRODUCTION
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('OTP: $sentCode'),
      //     backgroundColor: AppColors.main.withValues(alpha: 0.9),
      //     duration: const Duration(seconds: 3),
      //   ),
      // );

    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Analytics.instance.track(Events.otpFailed, {
        'channel': channel,
        'context': 'login_send',
        'error_code': 'send_error',
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(loc.otpSendFailed),
          backgroundColor: AppColors.red.withValues(alpha: 0.8),
          action: SnackBarAction(
            label: loc.tryAgain,
            textColor: Colors.white,
            onPressed: _sendOTP,
          ),
        ),
      );
    }
  }


  Future<void> _validateCode() async {
    setState(() => isLoading = true);
    // Cache navigator + messenger + loc BEFORE the verify/trust awaits so
    // post-verify navigation and error snackbars don't read context after
    // potential unmount.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context)!;
    final channel = widget.email != null ? 'email' : 'phone';

    try {
      final deviceId = await getDeviceId();

      if (widget.email != null) {
        // 📧 Email Verification
        // 1. Verify OTP
        await Supabase.instance.client.rpc(
          'rpc_verify_email_otp',
          params: {
            'p_email': widget.email,
            'p_code': _codeController.text.trim(),
            'p_purpose': 'signup_email_verify', // Reusing ownership check
          },
        );

        // 2. Trust Device (Since this is a login verification)
        await Supabase.instance.client.rpc(
          'trust_current_device',
          params: {'p_device_id': deviceId},
        );

      } else {
        // 📱 Phone Verification — unified rpc_verify_phone_otp + the
        // dedicated trust_current_device RPC (mirrors the email path
        // above exactly).
        final ok = await Supabase.instance.client.rpc(
          'rpc_verify_phone_otp',
          params: {
            'p_phone': widget.phoneNumber,
            'p_code': _codeController.text.trim(),
            'p_purpose': 'login_2fa',
          },
        );
        if (ok != true) {
          throw Exception('invalid_otp');
        }
        await Supabase.instance.client.rpc(
          'trust_current_device',
          params: {'p_device_id': deviceId},
        );
      }
      Analytics.instance.track(Events.otpVerified, {
        'channel': channel,
        'context': 'login',
      });

      navigator.pushAndRemoveUntil(
        fadePageRoute(CustomBottomNavigationBar()),
            (_) => false,
      );
    } catch (_) {
      Analytics.instance.track(Events.otpFailed, {
        'channel': channel,
        'context': 'login_verify',
        'error_code': 'invalid_otp',
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(loc.invalidCode),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _secondsRemaining = 20;
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
    WidgetsBinding.instance.removeObserver(this);
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
    final local = AppLocalizations.of(context)!;

    return BaseScaffold(
      title: Text(
        local.login,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          top: 16.w,
          bottom: 16.w + realKeyboardInset(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  SizedBox(height: 20.h),
                  Icon(
                    widget.email != null ? Icons.email : Icons.phone,
                    color: AppColors.main,
                    size: 40.sp,
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    widget.email != null
                        ? local.enterEmailCode
                        : local.enterSmsCode,
                    style: AppTextStyles.getTitle2(context),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            if (isLoading)
              const Center(child: FullPageLoader())
            else ...[
              TextFormField(
                controller: _codeController,
                textDirection: detectTextDirection(_codeController.text),
                textAlign: getTextAlign(context),
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: local.otpLabel,
                  labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                  errorText: isCodeValid ? null : local.invalidCode,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.r)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25.r)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.r),
                    borderSide: const BorderSide(color: AppColors.main, width: 2),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: 10.h),

              Text(local.otpSentTo, style: AppTextStyles.getText3(context)),
              Text(
                _getDisplayPhoneNumber(widget.email ?? widget.phoneNumber!),
                style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5.h),
              GestureDetector(
                onTap: canResend ? _sendOTP : null,
                child: Text(
                  canResend
                      ? local.didntReceiveCode
                      : '${local.didntReceiveCode} $_secondsRemaining ${local.seconds}',
                  style: AppTextStyles.getText3(context).copyWith(
                    color: canResend ? AppColors.main : Colors.grey,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const Spacer(),

              LinearProgressIndicator(
                value: 1.0,
                backgroundColor: AppColors.background2,
                valueColor: const AlwaysStoppedAnimation(AppColors.main),
                minHeight: 4.h,
              ),
              SizedBox(height: 20.h),

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
                      local.continueButton,
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
