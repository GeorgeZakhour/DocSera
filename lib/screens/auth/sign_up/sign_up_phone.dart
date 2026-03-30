import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/sign_up/sign_up_identity.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/const.dart';
import '../../../models/sign_up_info.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/auth/sign_up/sign_up_email.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SignUpFirstPage extends StatefulWidget {
  final SignUpInfo signUpInfo;

  const SignUpFirstPage({super.key, required this.signUpInfo});

  @override
  State<SignUpFirstPage> createState() => _SignUpFirstPageState();
}

class _SignUpFirstPageState extends State<SignUpFirstPage> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();

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
    _phoneController.dispose();
    _phoneFocus.dispose();
    for (var c in _otpControllers) { c.dispose(); }
    for (var f in _otpFocusNodes) { f.dispose(); }
    super.dispose();
  }

  /// **📌 التحقق من صحة رقم الهاتف**
  bool _isValidPhoneNumber(String input) {
    if (!input.startsWith('9') && !input.startsWith('09')) return false;

    int requiredLength = input.startsWith('09') ? 10 : 9;
    return input.length == requiredLength;
  }

  /// **📌 فحص التكرارات في جدول users الخاص بالمرضى**
  Future<void> _checkForDuplicates() async {
    if (!isValid) return;

    setState(() => isChecking = true);

    final formattedPhone = getFormattedPhoneNumber();

    try {
      // Check the app-specific `users` table via RPC because of RLS restrictions
      // This allows cross-app phone reuse while preventing intra-app duplication.
      final exists = await Supabase.instance.client.rpc(
        'rpc_check_phone_exists',
        params: {'p_phone': formattedPhone},
      );

      final bool isAvailable = exists != true;

      if (!isAvailable) {
        setState(() => isChecking = false);
        _showDuplicateDialog(context);
        return;
      }

      // ✅ حفظ البيانات (Check availability first, then SEND OTP)
      setState(() => isChecking = false);
      _sendOtp();
    } catch (e) {
      setState(() => isChecking = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.unexpectedError),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  Future<void> _sendOtp() async {
    setState(() => _otpSending = true);
    final formattedPhone = getFormattedPhoneNumber();
    try {
      await context.read<SupabaseUserService>().sendPhoneOtp(formattedPhone);
      setState(() {
        _otpSent = true;
        _otpSending = false;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _otpFocusNodes[0].requestFocus();
      });
    } catch (e) {
      debugPrint("OTP Send Error: $e");
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
    final formattedPhone = getFormattedPhoneNumber();
    try {
      final success = await context.read<SupabaseUserService>().verifyPhoneOtp(formattedPhone, code);
      if (success) {
        widget.signUpInfo.phoneNumber = formattedPhone;
        widget.signUpInfo.otpCode = code; // ✅ Save code for the final registration step
        // Proceed to next step
        if (!mounted) return;
        
        if (widget.signUpInfo.authMethod == AuthMethod.phoneOtp) {
          // Path A: Go to Optional Email
          Navigator.push(
            context,
            fadePageRoute(EnterEmailPage(signUpInfo: widget.signUpInfo, isOptional: true)),
          );
        } else {
          // Path B: Phone was mandatory after Email, now Go to Identity
          Navigator.push(
            context,
            fadePageRoute(SignUpSecondPage(signUpInfo: widget.signUpInfo)),
          );
        }
      } else {
        throw Exception("Invalid code");
      }
    } catch (e) {
      debugPrint("OTP Verify Error: $e");
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



  /// **📌 تحويل الرقم إلى الصيغة الدولية (00963)**
  String getFormattedPhoneNumber() {
    String phone = _phoneController.text.trim();
    if (phone.startsWith('09')) {
      phone = phone.substring(1); // ✅ إزالة `0` الأول
    }
    return "00963$phone"; // ✅ إضافة `00963` إلى البداية
  }

  /// **📌 نافذة تنبيه عند اكتشاف رقم مكرر**
  void _showDuplicateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.phoneAlreadyRegistered,
            style: AppTextStyles.getTitle2(context),
            textAlign: TextAlign.center, // ✅ توسيط العنوان
          ),
          content: Text(
            AppLocalizations.of(context)!.phoneAlreadyRegisteredContent,
            style: AppTextStyles.getText2(context),
            textAlign: TextAlign.center, // ✅ توسيط المحتوى
          ),
          actionsAlignment: MainAxisAlignment.center, // ✅ توسيط الأزرار
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min, // ✅ منع تمدد العمود
              crossAxisAlignment: CrossAxisAlignment.center, // ✅ توسيط الأزرار
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.main,
                    elevation: 0, // ✅ جعل الارتفاع 0
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    minimumSize: Size(double.infinity, 45.h), // ✅ تمديد الزر ليملأ العرض
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      fadePageRoute(SignUpFirstPage(signUpInfo: widget.signUpInfo)),
                    );
                  },
                  child: Text(
                    AppLocalizations.of(context)!.loginWithPhone,
                    style: AppTextStyles.getText2(context).copyWith(color: AppColors.whiteText),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _phoneController.clear();
                      hasInput = false;
                      isValid = false;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    minimumSize: Size(double.infinity, 45.h), // ✅ تمديد الزر ليملأ العرض
                  ),
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
              Text(AppLocalizations.of(context)!.enterPhone, style: AppTextStyles.getText2(context)),
              SizedBox(height: 15.h),

              /// **📌 حقل إدخال رقم الهاتف**
              TextFormField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.number,
                textDirection: detectTextDirection(_phoneController.text),
                textAlign: getTextAlign(context),
                style: AppTextStyles.getText2(context),
                maxLength: 10, // ✅ تحديد الحد الأقصى بـ 10 أرقام
                decoration: InputDecoration(
                  counterText: "", // ✅ إخفاء عداد الأحرف الافتراضي
                  labelText: AppLocalizations.of(context)!.phoneNumber,
                  labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),

                  // ✅ `prefixIcon` يبقى ثابتًا على اليمين
                  prefixIcon: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    child: Directionality(
                      textDirection: TextDirection.ltr, // ✅ ترتيب `+963` ثابت دائمًا
                      child: Row(
                        mainAxisSize: MainAxisSize.min, // ✅ منع التمدد غير المطلوب
                        children: [
                          Text(
                            Localizations.localeOf(context).languageCode == 'ar' ? "| +963" : "+963 |",
                            style: AppTextStyles.getText2(context).copyWith(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  prefixIconConstraints: BoxConstraints(
                    minWidth: 75.w, // ✅ تحديد عرض مناسب لتجنب التداخل
                    minHeight: 40.h, // ✅ منع التمدد غير الطبيعي
                  ),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.r),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.r),
                    borderSide: const BorderSide(color: AppColors.main, width: 2),
                  ),

                  // ✅ `suffixIcon` لا يؤثر على موضع `prefixIcon`
                  suffixIcon: hasInput
                      ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Container(
                      width: 20.w,
                      height: 20.w,
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
                      : null,
                  suffixIconConstraints: BoxConstraints(
                    minWidth: 32.w, // ✅ التأكد من أن الأيقونة لا تضغط على `prefixIcon`
                    minHeight: 32.h,
                  ),
                ),

                onChanged: (value) {
                  if (value.length > 10) {
                    _phoneController.text = value.substring(0, 10);
                    _phoneController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _phoneController.text.length),
                    );
                    return;
                  }

                  setState(() {
                    hasInput = value.isNotEmpty;
                    isValid = _isValidPhoneNumber(value);
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

              /// **📌 شريط التقدم**
              LinearProgressIndicator(
                value: 0.15,
                backgroundColor: AppColors.main.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.main),
              ),
              SizedBox(height: 20.h),

              /// **📌 زر المتابعة**
              ElevatedButton(
                onPressed: (isValid && _phoneController.text.isNotEmpty && !isChecking && !_otpSent)
                    ? _checkForDuplicates // Step 1: Check availability and technically "Continue" to Step 2
                    : (_otpSent && !_otpVerifying ? _verifyOtp : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isValid && _phoneController.text.isNotEmpty && !isChecking)
                      ? AppColors.main
                      : Colors.grey,
                  padding: EdgeInsets.symmetric(vertical: 5.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
                child: (isChecking || _otpSending || _otpVerifying)
                    ?  const SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
                    :  SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: Text(
                      _otpSent ? AppLocalizations.of(context)!.verify : AppLocalizations.of(context)!.continueButton,
                      style: AppTextStyles.getText2(context).copyWith(color: Colors.white, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
