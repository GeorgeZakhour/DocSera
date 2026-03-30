import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/login/login_page.dart';
import 'package:docsera/screens/auth/sign_up/create_password.dart';
import 'package:docsera/screens/auth/sign_up/cross_app_options.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/const.dart';
import '../../../models/sign_up_info.dart';
import 'package:docsera/screens/auth/sign_up/sign_up_phone.dart';
import 'package:docsera/screens/auth/sign_up/sign_up_identity.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EnterEmailPage extends StatefulWidget {
  final SignUpInfo signUpInfo;
  final bool isOptional;

  const EnterEmailPage({super.key, required this.signUpInfo, this.isOptional = false});

  @override
  State<EnterEmailPage> createState() => _EnterEmailPageState();
}

class _EnterEmailPageState extends State<EnterEmailPage> {
  final TextEditingController _emailController = TextEditingController();
  bool isValid = false;
  bool hasInput = false;
  bool isChecking = false;

  // ── OTP State ──
  bool _otpSent = false;
  bool _otpSending = false;
  bool _otpVerifying = false;
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    _emailController.dispose();
    for (var c in _otpControllers) { c.dispose(); }
    for (var f in _otpFocusNodes) { f.dispose(); }
    super.dispose();
  }

  final RegExp emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

  Future<void> _sendOtp() async {
    setState(() => _otpSending = true);
    final email = _emailController.text.trim().toLowerCase();
    try {
      // Note: We need a sendEmailOtp method in SupabaseUserService
      await context.read<SupabaseUserService>().sendEmailOtp(email);
      setState(() {
        _otpSent = true;
        _otpSending = false;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _otpFocusNodes[0].requestFocus();
      });
    } catch (e) {
      debugPrint("Email OTP Send Error: $e");
      setState(() => _otpSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.unexpectedError)),
      );
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length != 6) return;

    setState(() => _otpVerifying = true);
    final email = _emailController.text.trim().toLowerCase();
    try {
      final success = await context.read<SupabaseUserService>().verifyEmailOtp(email, code);
      if (success) {
        widget.signUpInfo.email = email;
        if (!mounted) return;

        if (widget.signUpInfo.authMethod == AuthMethod.emailPassword) {
          // Path B: Email Verified -> Now Mandatory Phone
          Navigator.push(
            context,
            fadePageRoute(SignUpFirstPage(signUpInfo: widget.signUpInfo)),
          );
        } else {
          // Path A (Optional Step): Email Verified -> Go to Identity
          Navigator.push(
            context,
            fadePageRoute(SignUpSecondPage(signUpInfo: widget.signUpInfo)),
          );
        }
      } else {
        throw Exception("Invalid code");
      }
    } catch (e) {
      debugPrint("Email OTP Verify Error: $e");
      setState(() => _otpVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.invalidOtp)),
      );
    }
  }

  void _onOtpChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    if (index == 5 && value.length == 1) {
      _verifyOtp();
    }
  }

  /// ✅ تحقق مما إذا كان البريد الإلكتروني مستخدمًا مسبقًا في تطبيق المرضى
  Future<void> _checkForDuplicates() async {
    if (!isValid) return;

    setState(() => isChecking = true);

    final email = _emailController.text.trim().toLowerCase();

    try {
      final res = await Supabase.instance.client.rpc(
        'check_email_context',
        params: {'p_email': email},
      );
      final contextStatus = res as String;

      setState(() => isChecking = false);

      if (contextStatus == 'in_docsera' || contextStatus == 'in_both') {
        _showDuplicateDialog();
        return;
      }

      // ✅ الإيميل متاح -> SEND OTP
      widget.signUpInfo.email = email;
      widget.signUpInfo.isCrossApp = contextStatus == 'in_docsera_pro';

      _sendOtp();
    } catch (e) {
      setState(() => isChecking = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorCheckingEmail),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  /// ✅ عرض نافذة تنبيه عند تكرار البريد الإلكتروني
  void _showDuplicateDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.emailAlreadyRegistered,
            style: AppTextStyles.getTitle2(context),
            textAlign: TextAlign.center, // ✅ توسيط العنوان
          ),
          content: Text(
            AppLocalizations.of(context)!.emailAlreadyRegisteredContent,
            style: AppTextStyles.getText2(context),
            textAlign: TextAlign.center, // ✅ توسيط العنوان
          ),
          actionsAlignment: MainAxisAlignment.center, // ✅ توسيط الأزرار
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.main,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      fadePageRoute(LogInPage(preFilledInput: _emailController.text)),
                    );
                  },
                  child: Text(
                    AppLocalizations.of(context)!.loginWithEmail,
                    style: AppTextStyles.getText2(context).copyWith(color: AppColors.whiteText),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _emailController.clear();
                      hasInput = false;
                      isValid = false;
                      widget.signUpInfo.email = null;
                    });
                  },
                  style: TextButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 10.h)),
                  child: Text(
                    AppLocalizations.of(context)!.edit,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: AppColors.main,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.signUp,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.enterEmail,
                style: AppTextStyles.getText2(context),
              ),
              SizedBox(height: 15.h),

              /// 🔹 **حقل إدخال البريد الإلكتروني**
              TextFormField(
                controller: _emailController,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9@._\-]')),
                ],
                keyboardType: TextInputType.emailAddress,
                textDirection: detectTextDirection(_emailController.text),
                textAlign: getTextAlign(context),
                style: AppTextStyles.getText2(context),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.email,
                  labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
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
                  suffixIcon: hasInput
                      ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: Container(
                      width: 15.w,
                      height: 15.w,
                      decoration: BoxDecoration(
                        color: isValid ? AppColors.main : AppColors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          isValid ? Icons.check : Icons.close,
                          color: Colors.white,
                          size: 14.sp,
                        ),
                      ),
                    ),
                  )
                      : null, // ✅ إخفاء الأيقونة عند عدم وجود إدخال
                ),
                onChanged: (value) {
                  setState(() {
                    hasInput = value.isNotEmpty;
                    isValid = emailRegex.hasMatch(value);
                  });
                },
              ),

              if (_otpSent) ...[
                SizedBox(height: 30.h),
                Center(child: Text(AppLocalizations.of(context)!.enterOtp, style: AppTextStyles.getTitle2(context))),
                SizedBox(height: 15.h),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: SizedBox(
                          width: 40.w,
                          child: TextField(
                            controller: _otpControllers[i],
                            focusNode: _otpFocusNodes[i],
                            maxLength: 1,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: Colors.grey.withOpacity(0.1),
                              contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: BorderSide(color: AppColors.mainDark.withOpacity(0.2)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: const BorderSide(color: AppColors.main, width: 2),
                              ),
                            ),
                            onChanged: (val) => _onOtpChanged(val, i),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                SizedBox(height: 20.h),
                if (_otpVerifying)
                  const Center(child: CircularProgressIndicator())
              ],

              SizedBox(height: 20.h),

              // ✅ **خط التقدم**
              LinearProgressIndicator(
                value: 0.40,
                backgroundColor: AppColors.main.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.main),
              ),
              SizedBox(height: 20.h),

              // ✅ **زر المتابعة**
              ElevatedButton(
                onPressed: (isValid && _emailController.text.isNotEmpty && !isChecking && !_otpSent)
                    ? _checkForDuplicates
                    : (_otpSent && !_otpVerifying ? _verifyOtp : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isValid && _emailController.text.isNotEmpty && !isChecking)
                      ? AppColors.main
                      : Colors.grey,
                  padding: EdgeInsets.symmetric(vertical: 5.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
                child: (isChecking || _otpSending || _otpVerifying)
                    ? const SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
                    : SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: Text(
                      _otpSent ? AppLocalizations.of(context)!.verify : AppLocalizations.of(context)!.continueButton,
                      style: AppTextStyles.getText2(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              if (widget.isOptional) ...[
                SizedBox(height: 16.h),
                TextButton(
                  onPressed: () {
                    widget.signUpInfo.email = null;
                    Navigator.push(
                      context,
                      fadePageRoute(SignUpSecondPage(signUpInfo: widget.signUpInfo)),
                    );
                  },
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.skipEmail ?? "Skip for now",
                      style: AppTextStyles.getText2(context).copyWith(
                        color: Colors.grey,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],

              SizedBox(height: 10.h),
              // Center(
              //   child: TextButton(
              //     onPressed: () {
              //       widget.signUpInfo.email = null;
              //       Navigator.push(
              //         context,
              //         fadePageRoute(CreatePasswordPage(signUpInfo: widget.signUpInfo)),
              //       );
              //     },
              //     style: TextButton.styleFrom(
              //       foregroundColor: AppColors.main,
              //       textStyle: AppTextStyles.getText3(context).copyWith(
              //         decoration: TextDecoration.underline,
              //         fontWeight: FontWeight.bold,
              //       ),
              //     ),
              //     child: Text(AppLocalizations.of(context)!.skipEmail),
              //   ),
              // ),

            ],
          ),
        ),
      ),
    );
  }
}
