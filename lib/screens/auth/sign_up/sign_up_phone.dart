import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/sign_up/sign_up_identity.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../app/const.dart';
import '../../../models/sign_up_info.dart';
import '../../../services/firestore/firestore_user_service.dart'; // Firestore Service
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SignUpFirstPage extends StatefulWidget {
  final SignUpInfo signUpInfo;

  const SignUpFirstPage({super.key, required this.signUpInfo});

  @override
  State<SignUpFirstPage> createState() => _SignUpFirstPageState();
}

class _SignUpFirstPageState extends State<SignUpFirstPage> {
  final TextEditingController _phoneController = TextEditingController();
  final FirestoreUserService _firestoreService = FirestoreUserService();

  bool isValid = false;
  bool hasInput = false;
  bool isChecking = false;

  /// **📌 التحقق من صحة رقم الهاتف**
  bool _isValidPhoneNumber(String input) {
    if (!input.startsWith('9') && !input.startsWith('09')) return false;

    int requiredLength = input.startsWith('09') ? 10 : 9;
    return input.length == requiredLength;
  }

  /// **📌 فحص التكرارات في Firestore**
  Future<void> _checkForDuplicates() async {
    if (!isValid) return;

    setState(() => isChecking = true);
    final formattedPhone = getFormattedPhoneNumber();

    try {
      // ✅ تحقق من التكرار في Firestore حسب رقم الهاتف
      final isDuplicate = await _firestoreService.isPhoneNumberExists(formattedPhone);
      if (isDuplicate) {
        setState(() => isChecking = false);
        _showDuplicateDialog(context);
        return;
      }

      // ✅ توليد إيميل وهمي فريد
      final fakeEmail = await _firestoreService.generateNextFakeEmail();
      print("📣 Called generateNextFakeEmail()");

      // ✅ تخزين البيانات
      widget.signUpInfo.phoneNumber = formattedPhone;
      widget.signUpInfo.email = null;
      widget.signUpInfo.fakeEmail = fakeEmail;

      setState(() => isChecking = false);

      Navigator.push(
        context,
        fadePageRoute(SignUpSecondPage(signUpInfo: widget.signUpInfo)),
      );

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
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.r),
                    borderSide: BorderSide(color: AppColors.main, width: 2),
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
                onPressed: isValid && _phoneController.text.isNotEmpty && !isChecking
                    ? _checkForDuplicates
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isValid && _phoneController.text.isNotEmpty && !isChecking
                      ? AppColors.main
                      : Colors.grey,
                  padding: EdgeInsets.symmetric(vertical: 5.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
                child: isChecking
                    ?  const SizedBox(
                  width: double.infinity,
                  // height: 16.w,
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
                    child: Text(AppLocalizations.of(context)!.continueButton,
                        style: AppTextStyles.getText2(context).copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
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
