import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/sign_up_info.dart';
import 'package:docsera/screens/auth/sign_up/sign_up_email.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../app/const.dart';
import 'package:docsera/screens/auth/sign_up/terms_of_use_page.dart';
import 'package:docsera/screens/auth/sign_up/recap_info.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/auth/sign_up/create_password.dart';


class SignUpSecondPage extends StatefulWidget {
  final SignUpInfo signUpInfo; // Accept SignUpInfo to collect user data

  const SignUpSecondPage({super.key, required this.signUpInfo});

  @override
  State<SignUpSecondPage> createState() => _SignUpSecondPageState();
}

class _SignUpSecondPageState extends State<SignUpSecondPage> {
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  String? _selectedGender;
  bool isFormValid = false;
  bool isUnderage = false;


  // final RegExp nameRegex = RegExp(r'^[\p{L}\s]+$', unicode: true); // ✅ الآن يدعم كل اللغات
  final RegExp arabicNameRegex = RegExp(r'^[\u0600-\u06FF\s]{2,}$'); // فقط حروف عربية ومسافات

  /// Method to validate each field and the overall form
  void _validateForm() {
    setState(() {
      isFormValid =
          _firstNameController.text.length >= 2 && // ✅ الحد الأدنى للاسم الأول 2 أحرف
              arabicNameRegex.hasMatch(_firstNameController.text) &&
              _lastNameController.text.length >= 2 && // ✅ الحد الأدنى لاسم العائلة 2 أحرف
              arabicNameRegex.hasMatch(_lastNameController.text) &&
              _dobController.text.isNotEmpty &&
              _selectedGender != null &&
              !isUnderage;
    });
  }


  /// 📆 تحسين نافذة اختيار التاريخ مع دعم تعدد اللغات وتنسيق الألوان
  Future<void> _selectDate(BuildContext context) async {
    final Locale currentLocale = Localizations.localeOf(context);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: currentLocale, // ✅ ضبط التقويم حسب لغة التطبيق
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: AppColors.main, // ✅ لون الأزرار والنصوص
            hintColor: AppColors.main, // ✅ لون التلميحات
            colorScheme: const ColorScheme.light(
              primary: AppColors.main, // ✅ لون رئيسي مخصص
              onPrimary: Colors.white, // ✅ لون النصوص في الأزرار
              surface: Colors.white, // ✅ لون الخلفية
              onSurface: AppColors.blackText, // ✅ لون النصوص في التقويم
            ), dialogTheme: const DialogThemeData(backgroundColor: Colors.white), // ✅ لون خلفية النافذة
          ),
          child: Directionality(
            textDirection: currentLocale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      final now = DateTime.now();
      int age = now.year - picked.year;
      if (now.month < picked.month || (now.month == picked.month && now.day < picked.day)) {
        age--;
      }

      setState(() {
        isUnderage = age < 16;
        _dobController.text =
        '${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}';
        widget.signUpInfo.dateOfBirth =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
      _validateForm();
    }

  }
  /// ✅ تحويل الرقم من 00963XXXXXXXX إلى 09XXXXXXXX للعرض فقط
  String _getDisplayPhoneNumber(String input) {
    if (input.startsWith('00963') && input.length > 5) {
      return '0${input.substring(5)}'; // ✅ يعيد الرقم بصيغة 09XXXXXXXX
    }
    return input; // ✅ لو الإيميل أو غير رقم، رجّعه كما هو
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
              // User Info Display
              Row(
                children: [
                  Icon(
                    widget.signUpInfo.authMethod == AuthMethod.phoneOtp ? Icons.phone_android : Icons.email_outlined,
                    size: 40.sp,
                    color: AppColors.main,
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    widget.signUpInfo.authMethod == AuthMethod.phoneOtp
                        ? _getDisplayPhoneNumber(widget.signUpInfo.phoneNumber ?? '')
                        : (widget.signUpInfo.email ?? ''),
                    style: AppTextStyles.getTitle1(context),
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              Text(
                AppLocalizations.of(context)!.enterPersonalInfo,
                style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
              ),
              SizedBox(height: 25.h),

              // Gender Dropdown
              Text(AppLocalizations.of(context)!.identity,
                style: AppTextStyles.getTitle1(context).copyWith(fontSize: 11.sp,color: AppColors.mainDark)),
              SizedBox(height: 20.h),
              _buildDropdownValidatedField(
                value: _selectedGender,
                hint: AppLocalizations.of(context)!.selectGender,
                items:  [
                  DropdownMenuItem(value: "ذكر", child: Text(AppLocalizations.of(context)!.male, style: AppTextStyles.getText1(context),)),
                  DropdownMenuItem(value: "أنثى", child: Text(AppLocalizations.of(context)!.female, style: AppTextStyles.getText1(context),)),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                    widget.signUpInfo.gender = value; // Store gender
                  });
                  _validateForm();
                },
              ),
              SizedBox(height: 10.h),

              // First Name
              _buildValidatedField(
                controller: _firstNameController,
                labelText: AppLocalizations.of(context)!.firstName,
                validator: (value) => value.isNotEmpty && value.length >= 2 && arabicNameRegex.hasMatch(value),
                onChanged: (value) {
                  String formattedValue = value.trim(); // ✅ إزالة الفراغات الزائدة

                  // ✅ تحويل أول حرف من كل كلمة إلى حرف كبير في الإنجليزية فقط
                  if (formattedValue.isNotEmpty && RegExp(r'^[a-zA-Z]').hasMatch(formattedValue)) {
                    formattedValue = formattedValue.split(' ').map((word) {
                      if (word.isNotEmpty) {
                        return word[0].toUpperCase() + word.substring(1);
                      }
                      return '';
                    }).join(' ');
                  }

                  setState(() {
                    _firstNameController.text = formattedValue; // ✅ تحديث `TextField`
                    _firstNameController.selection = TextSelection.fromPosition(
                      TextPosition(offset: formattedValue.length),
                    );

                    widget.signUpInfo.firstName = formattedValue; // ✅ تحديث البيانات عند التنقل بين الصفحات
                    _validateForm(); // ✅ إعادة التحقق من صحة الفورم
                  });
                },
              ),

              SizedBox(height: 10.h),

              // Last Name
              _buildValidatedField(
                controller: _lastNameController,
                labelText: AppLocalizations.of(context)!.lastName,
                validator: (value) => value.isNotEmpty && value.length >= 2 && arabicNameRegex.hasMatch(value),
                onChanged: (value) {
                  String formattedValue = value.trim(); // ✅ إزالة الفراغات الزائدة

                  // ✅ تحويل أول حرف من كل كلمة إلى حرف كبير في الإنجليزية فقط
                  if (formattedValue.isNotEmpty && RegExp(r'^[a-zA-Z]').hasMatch(formattedValue)) {
                    formattedValue = formattedValue.split(' ').map((word) {
                      if (word.isNotEmpty) {
                        return word[0].toUpperCase() + word.substring(1);
                      }
                      return '';
                    }).join(' ');
                  }

                  setState(() {
                    _lastNameController.text = formattedValue; // ✅ تحديث `TextField`
                    _lastNameController.selection = TextSelection.fromPosition(
                      TextPosition(offset: formattedValue.length),
                    );

                    widget.signUpInfo.lastName = formattedValue; // ✅ تحديث البيانات عند التنقل بين الصفحات
                    _validateForm(); // ✅ إعادة التحقق من صحة الفورم
                  });
                },
              ),

              SizedBox(height: 10.h),

              // Date of Birth
              _buildDatePickerField(),
              if (isUnderage)
                Padding(
                  padding: EdgeInsets.only(top: 5.h, left: 8.w),
                  child: Text(
                    AppLocalizations.of(context)!.mustBeOver16,
                    style: AppTextStyles.getText3(context).copyWith(color: AppColors.red),
                  ),
                ),
              SizedBox(height: 20.h),

              // Progress Line
              LinearProgressIndicator(
                value: 0.35,
                backgroundColor: AppColors.main.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.main),
                minHeight: 4,
              ),
              SizedBox(height: 20.h),

              // Continue Button
              ElevatedButton(
                onPressed: isFormValid
                    ? () {
                  if (widget.signUpInfo.authMethod == AuthMethod.phoneOtp) {
                    // Path A: Go to Terms -> Marketing -> Recap
                    Navigator.push(
                      context,
                      fadePageRoute(TermsOfUsePage(signUpInfo: widget.signUpInfo)),
                    );
                  } else {
                    // Path B: Go to Create Password -> Terms -> Marketing -> Recap
                    Navigator.push(
                      context,
                      fadePageRoute(CreatePasswordPage(signUpInfo: widget.signUpInfo)),
                    );
                  }
                }
                    : null, // ❌ تعطيل الزر إذا لم يكن الإدخال صحيحًا
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFormValid ? AppColors.main : Colors.grey, // ✅ تغيير اللون حسب حالة الفورم
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
          ),
        ),
      ),
    );
  }

  /// 🔹 حقل إدخال محسّن مع أيقونة التحقق ✔️❌
  Widget _buildValidatedField({
    required TextEditingController controller,
    required String labelText,
    required bool Function(String value) validator,
    required Function(String value) onChanged,
  }) {
    return TextFormField(
      controller: controller,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^[\u0600-\u06FF\s]+$')),
      ],
      textDirection: detectTextDirection(controller.text), // ✅ ضبط الاتجاه ديناميكيًا
      textAlign: getTextAlign(context),
      style: AppTextStyles.getText2(context), // ✅ استخدام ستايل النصوص القياسي
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: AppTextStyles.getText3(context).copyWith(color: Colors.grey), // ✅ ستايل النصوص الصغير
        floatingLabelBehavior: FloatingLabelBehavior.auto, // ✅ جعل التسمية تظهر بعد الكتابة
        contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: AppColors.main, width: 2),
        ),
        suffixIcon: controller.text.isEmpty
            ? null // ✅ لا تعرض أيقونة إذا كان الحقل فارغًا
            : Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          child: Container(
            width: 15.w,
            height: 15.w,
            decoration: BoxDecoration(
              color: validator(controller.text) ? AppColors.main : AppColors.red,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                validator(controller.text) ? Icons.check : Icons.close,
                color: Colors.white,
                size: 14.sp,
              ),
            ),
          ),
        ),
      ),
      onChanged: (value) {
        onChanged(value);
        _validateForm(); // ✅ تحديث صحة الفورم بعد كل إدخال
      },
    );
  }


  /// 🔹 قائمة منسدلة محسنة مع جميع التحسينات المطلوبة
  Widget _buildDropdownValidatedField({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: hint, // ✅ التسمية تظهر فقط كـ floating
        labelStyle: AppTextStyles.getText3(context).copyWith(
          color: value == null ? Colors.grey : AppColors.main, // ✅ رمادي قبل الاختيار، أخضر بعده
          fontSize: 12.sp, // ✅ ضبط حجم النص ليكون متناسقًا مع باقي الحقول
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto, // ✅ التسمية تتحول إلى `floating` فقط عند الاختيار
        contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: AppColors.main, width: 2),
        ),
      ),
      dropdownColor: Colors.white.withOpacity(0.95), // ✅ لون خلفية القائمة المنسدلة
      isExpanded: true, // ✅ جعل القائمة أصغر من عرض الحقل
      borderRadius: BorderRadius.circular(15.r), // ✅ زوايا دائرية للقائمة
      menuMaxHeight: 250.h, // ✅ منع القائمة من أن تصبح طويلة جدًا
      icon: Icon(Icons.arrow_drop_down, color: AppColors.main, size: 22.sp), // ✅ تغيير أيقونة السهم
      items: items,
      onChanged: onChanged,
    );
  }

  /// 🔹 حقل اختيار تاريخ محسّن مع أيقونة التحقق ✔️
  Widget _buildDatePickerField() {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: AbsorbPointer(
        child: TextFormField(
          controller: _dobController,
          textDirection: detectTextDirection(_dobController.text), // ✅ ضبط الاتجاه ديناميكيًا
          textAlign: getTextAlign(context),
          style: AppTextStyles.getText2(context), // ✅ توحيد ستايل النصوص
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.dateOfBirth,
            hintText: 'DD.MM.YYYY',
            hintStyle: AppTextStyles.getText3(context).copyWith(color: Colors.grey, fontSize: 11.sp),
            labelStyle: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
            floatingLabelBehavior: FloatingLabelBehavior.auto, // ✅ إظهار التسمية فقط بعد الاختيار
            contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.r),
              borderSide: BorderSide(color: isUnderage ? AppColors.red : Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.r),
              borderSide: const BorderSide(color: AppColors.main, width: 2),
            ),
            suffixIcon: _dobController.text.isEmpty
                ? null
                : Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: Container(
                width: 15.w,
                height: 15.w,
                decoration: BoxDecoration(
                  color: isUnderage ? AppColors.red : AppColors.main,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isUnderage ? Icons.close : Icons.check,
                    color: Colors.white,
                    size: 14.sp,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}
