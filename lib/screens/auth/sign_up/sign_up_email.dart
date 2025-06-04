import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/login/login_page.dart';
import 'package:docsera/screens/auth/sign_up/create_password.dart';
import 'package:docsera/services/firestore/firestore_user_service.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../app/const.dart';
import '../../../models/sign_up_info.dart';

class EnterEmailPage extends StatefulWidget {
  final SignUpInfo signUpInfo;

  const EnterEmailPage({Key? key, required this.signUpInfo}) : super(key: key);

  @override
  State<EnterEmailPage> createState() => _EnterEmailPageState();
}

class _EnterEmailPageState extends State<EnterEmailPage> {
  final TextEditingController _emailController = TextEditingController();
  final FirestoreUserService _firestoreService = FirestoreUserService();
  bool isValid = false;
  bool hasInput = false;
  bool isChecking = false;

  final RegExp emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

  /// ✅ تحقق مما إذا كان البريد الإلكتروني مستخدمًا مسبقًا
  Future<void> _checkForDuplicates() async {
    if (!isValid) return;

    setState(() {
      isChecking = true;
    });

    try {
      final isDuplicate = await _firestoreService.doesUserExist(email: _emailController.text.trim());

      setState(() {
        isChecking = false;
      });

      if (isDuplicate) {
        _showDuplicateDialog();
      } else {
        widget.signUpInfo.email = _emailController.text.trim();
        Navigator.push(
          context,
          fadePageRoute(CreatePasswordPage(signUpInfo: widget.signUpInfo)),
        );
      }
    } catch (e) {
      setState(() {
        isChecking = false;
      });
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
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.r),
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.r),
                    borderSide: BorderSide(color: AppColors.main, width: 2),
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
                onPressed: isValid && _emailController.text.isNotEmpty && !isChecking
                    ? _checkForDuplicates
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isValid && _emailController.text.isNotEmpty && !isChecking
                      ? AppColors.main
                      : Colors.grey,
                  padding: EdgeInsets.symmetric(vertical: 5.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
                child: isChecking
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
                      AppLocalizations.of(context)!.continueButton,
                      style: AppTextStyles.getText2(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 10.h),

              Center(
                child: TextButton(
                  onPressed: () {
                    widget.signUpInfo.email = null;
                    Navigator.push(
                      context,
                      fadePageRoute(CreatePasswordPage(signUpInfo: widget.signUpInfo)),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.main,
                    textStyle: AppTextStyles.getText3(context).copyWith(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Text(AppLocalizations.of(context)!.skipEmail),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
