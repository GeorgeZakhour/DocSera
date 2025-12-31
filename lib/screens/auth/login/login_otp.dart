import 'dart:async';
import 'dart:io';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/services/supabase/supabase_otp_service.dart';
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

import '../../../utils/full_page_loader.dart';

class LoginOTPPage extends StatefulWidget {
  final String phoneNumber;

  const LoginOTPPage({super.key, required this.phoneNumber});

  @override
  State<LoginOTPPage> createState() => _LoginOTPPageState();
}

class _LoginOTPPageState extends State<LoginOTPPage> {
  final SupabaseOTPService _supabaseService = SupabaseOTPService();
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
    _sendOTP();
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

    try {
      sentCode = await Supabase.instance.client.rpc(
        'send_login_otp',
        params: {
          'p_phone': widget.phoneNumber,
        },
      );
      setState(() {
        isLoading = false;
      });
      _startResendTimer();

      // ✅ عرض الـ OTP كـ Snackbar (للديفيلوبر فقط)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP: $sentCode'),
          backgroundColor: AppColors.main.withOpacity(0.9),
          duration: const Duration(seconds: 3),
        ),
      );

    } catch (e) {
      setState(() {
        isLoading = false;
      });

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


  Future<void> _validateCode() async {
    setState(() => isLoading = true);

    try {
      final deviceId = await getDeviceId();

      final res = await Supabase.instance.client.rpc(
        'verify_login_otp',
        params: {
          'p_phone': widget.phoneNumber,
          'p_code': _codeController.text.trim(),
          'p_device_id': deviceId,
        },
      );


      if (res != true) {
        throw Exception('invalid_otp');
      }

      Navigator.pushAndRemoveUntil(
        context,
        fadePageRoute(const CustomBottomNavigationBar()),
            (_) => false,
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.invalidCode),
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
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  SizedBox(height: 20.h),
                  Icon(Icons.phone, color: AppColors.main, size: 40.sp),
                  SizedBox(height: 20.h),
                  Text(local.enterSmsCode, style: AppTextStyles.getTitle2(context)),
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
                _getDisplayPhoneNumber(widget.phoneNumber),
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
