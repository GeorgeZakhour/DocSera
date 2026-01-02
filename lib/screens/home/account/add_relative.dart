import 'package:docsera/Business_Logic/Account_page/relatives/relatives_cubit.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:intl/intl.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/utils/time_utils.dart';


class AddRelativePage extends StatefulWidget {
  const AddRelativePage({super.key});

  @override
  _AddRelativePageState createState() => _AddRelativePageState();
}

class _AddRelativePageState extends State<AddRelativePage> {
  final _formKey = GlobalKey<FormState>();
  String gender = "";
  String country = "";
  bool isFormValid = false;
  bool isAuthorized = false;
  final arabicNameRegex = RegExp(r'^[\u0600-\u06FF\s]{2,}$');
  bool hasTriedSubmit = false;
  String? phoneErrorText;

  final List<String> genderOptions = ["ذكر", "أنثى"];

  final List<String> cityOptions = [
    "دمشق", "حلب", "حمص", "حماة", "اللاذقية", "دير الزور",
    "الرقة", "إدلب", "درعا", "طرطوس", "الحسكة", "القامشلي", "السويداء"
  ];

  // Controllers
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController dateOfBirthController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController streetController = TextEditingController();
  final TextEditingController buildingNrController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController countryController = TextEditingController();



  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    dateOfBirthController.dispose();
    streetController.dispose();
    buildingNrController.dispose();
    cityController.dispose();
    countryController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }


  String _formatPhoneNumber(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('09')) {
      return '00963${trimmed.substring(1)}';
    } else if (trimmed.startsWith('9')) {
      return '00963$trimmed';
    } else {
      return trimmed; // fallback
    }
  }

  Future<void> _saveRelative() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid || !isAuthorized) {
      setState(() {});
      return;
    }

    // 🛑 تحقق العنوان
    if (buildingNrController.text.isNotEmpty &&
        (streetController.text.isEmpty ||
            cityController.text.isEmpty ||
            countryController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill Street, City, and Country before adding a Building Number.',
          ),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    try {
      await context.read<RelativesCubit>().addRelative({
        'first_name': firstNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
        'gender': gender,
        'date_of_birth': DocSeraTime.toUtc(DateFormat('dd.MM.yyyy')
            .parse(dateOfBirthController.text))
            .toIso8601String(),
        'email': emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
        'phone_number': phoneController.text.trim().isEmpty
            ? null
            : _formatPhoneNumber(phoneController.text.trim()),
        'address': {
          'street': streetController.text.trim(),
          'buildingNr': buildingNrController.text.trim(),
          'city': cityController.text.trim(),
          'country': countryController.text.trim(),
        },
      });


      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
          Text(AppLocalizations.of(context)!.relativeAddedSuccess),
          backgroundColor: AppColors.main.withOpacity(0.8),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.relativeAddFailed(e.toString()),
          ),
          backgroundColor: AppColors.red.withOpacity(0.8),
        ),
      );
    }
  }


  /// ✅ Date picker for date of birth
  Future<void> _pickDate() async {
    DateTime initialDate = DocSeraTime.nowSyria();
    if (dateOfBirthController.text.isNotEmpty) {
      try {
        initialDate = DateFormat('dd.MM.yyyy').parse(dateOfBirthController.text);
      } catch (_) {}
    }

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DocSeraTime.nowSyria(),
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            colorScheme: const ColorScheme.light(
              primary: AppColors.main,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        dateOfBirthController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  /// ✅ Validate form and address fields
  void _validateForm() {
    final isValid = _formKey.currentState?.validate() ?? false;

    bool isAddressEmpty = streetController.text.isEmpty &&
        cityController.text.isEmpty &&
        countryController.text.isEmpty &&
        buildingNrController.text.isEmpty;

    bool isAddressValid = (streetController.text.isNotEmpty &&
        cityController.text.isNotEmpty &&
        countryController.text.isNotEmpty) ||
        isAddressEmpty;

    bool isBuildingNrAlone = buildingNrController.text.isNotEmpty &&
        (streetController.text.isEmpty ||
            cityController.text.isEmpty ||
            countryController.text.isEmpty);

    final requiredFieldsFilled = firstNameController.text.isNotEmpty &&
        lastNameController.text.isNotEmpty &&
        dateOfBirthController.text.isNotEmpty &&
        gender.isNotEmpty;

    setState(() {
      isFormValid = isValid &&
          requiredFieldsFilled &&
          isAddressValid &&
          !isBuildingNrAlone &&
          isAuthorized;
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background2,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 70.h,
        title: Text(AppLocalizations.of(context)!.addRelative, style: AppTextStyles.getTitle1(context).copyWith(color: Colors.black,fontSize: 12.sp)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            _buildInfoBox(),
            SizedBox(height: 15.h),
            _buildLabel(AppLocalizations.of(context)!.personalInformation),
            SizedBox(height: 5.h),

            _buildDropdownValidatedField(
              value: gender.isEmpty ? null : gender,
              hint: AppLocalizations.of(context)!.selectGender,
              items: [
                DropdownMenuItem(
                  value: "ذكر",
                  child: Text(AppLocalizations.of(context)!.male, style: AppTextStyles.getText1(context)),
                ),
                DropdownMenuItem(
                  value: "أنثى",
                  child: Text(AppLocalizations.of(context)!.female, style: AppTextStyles.getText1(context)),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  gender = value!;
                });
              },
              isRequired: true,
            ),



            SizedBox(height: 15.h),
            _buildValidatedFieldArabic(
              controller: firstNameController,
              labelText: AppLocalizations.of(context)!.firstName,
              isRequired: true,
              onChanged: (value) {
                firstNameController.text = value;
                firstNameController.selection = TextSelection.fromPosition(
                  TextPosition(offset: value.length),
                );
              },
            ),
            SizedBox(height: 15.h),

            _buildValidatedFieldArabic(
              controller: lastNameController,
              labelText: AppLocalizations.of(context)!.lastName,
              isRequired: true,
              onChanged: (value) {
                lastNameController.text = value;
                lastNameController.selection = TextSelection.fromPosition(
                  TextPosition(offset: value.length),
                );
              },
            ),

            SizedBox(height: 15.h),

            _buildDateField(
              controller: dateOfBirthController,
              labelText: AppLocalizations.of(context)!.dateOfBirth,
              isRequired: true,
              onTap: _pickDate,
            ),

            SizedBox(height: 25.h),
            _buildLabel(AppLocalizations.of(context)!.contactInformation),
            SizedBox(height: 5.h),
            _buildPhoneNumberField(),
            SizedBox(height: 15.h),
            _buildEmailField(),
            SizedBox(height: 25.h),

            _buildLabel(AppLocalizations.of(context)!.address),
            SizedBox(height: 5.h),
            _buildValidatedFieldArabic(
              controller: streetController,
              labelText: AppLocalizations.of(context)!.street,
              isRequired: false,
              onChanged: (value) {
                streetController.text = value;
                streetController.selection = TextSelection.fromPosition(TextPosition(offset: value.length));
              },
            ),
            SizedBox(height: 15.h),
            _buildValidatedNumberField(
              controller: buildingNrController,
              labelText: AppLocalizations.of(context)!.buildingNr,
              isRequired: false,
              onChanged: (value) {
                buildingNrController.text = value;
                buildingNrController.selection = TextSelection.fromPosition(TextPosition(offset: value.length));
              },
            ),
            SizedBox(height: 15.h),
            _buildDropdownValidatedField(
              value: cityController.text.isEmpty ? null : cityController.text,
              hint: AppLocalizations.of(context)!.selectCity,
              isRequired: false,
              items: cityOptions.map((city) {
                final displayText = {
                  "دمشق": AppLocalizations.of(context)!.damascus,
                  "حلب": AppLocalizations.of(context)!.aleppo,
                  "حمص": AppLocalizations.of(context)!.homs,
                  "حماة": AppLocalizations.of(context)!.hama,
                  "اللاذقية": AppLocalizations.of(context)!.latakia,
                  "دير الزور": AppLocalizations.of(context)!.deirEzzor,
                  "الرقة": AppLocalizations.of(context)!.raqqa,
                  "إدلب": AppLocalizations.of(context)!.idlib,
                  "درعا": AppLocalizations.of(context)!.daraa,
                  "طرطوس": AppLocalizations.of(context)!.tartus,
                  "الحسكة": AppLocalizations.of(context)!.alHasakah,
                  "القامشلي": AppLocalizations.of(context)!.qamishli,
                  "السويداء": AppLocalizations.of(context)!.suwayda,
                }[city] ?? city;

                return DropdownMenuItem(
                  value: city,
                  child: Text(displayText, style: AppTextStyles.getText2(context)),
                );
              }).toList(),
              onChanged: (val) => setState(() {
                cityController.text = val!;
              }),
            ),
            SizedBox(height: 15.h),
            _buildDropdownValidatedField(
              value: countryController.text.isEmpty ? null : countryController.text,
              hint: AppLocalizations.of(context)!.selectCountry,
              isRequired: false,
              items: [
                DropdownMenuItem(
                  value: "سوريا",
                  child: Text(AppLocalizations.of(context)!.syria, style: AppTextStyles.getText2(context)),
                ),
              ],
              onChanged: (val) => setState(() {
                countryController.text = val!;
              }),
            ),

            SizedBox(height: 20.h),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isAuthorized
                      ? AppColors.main
                      : (hasTriedSubmit ? AppColors.red : Colors.grey),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: isAuthorized,
                    onChanged: (val) => setState(() => isAuthorized = val ?? false),
                    activeColor: AppColors.main, // Adjust checkbox color if needed
                  ),
                  SizedBox(width: 8.w), // Space between checkbox and text
                  Expanded(
                    child: Text(
                        AppLocalizations.of(context)!.authorizationStatement,
                      style: AppTextStyles.getText3(context),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: () {
                _validateForm(); // ⬅️ ضروري تحديث حالة isFormValid قبل التحقق
                hasTriedSubmit = true;

                if (!isFormValid) {
                  // عرّض الأخطاء (بما فيها التحقق من التفويض وغيره)
                  setState(() {});
                  return;
                }

                _saveRelative();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.main,
                padding:  EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(AppLocalizations.of(context)!.add, style: AppTextStyles.getText1(context).copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            SizedBox(height: 20.h),

          ],
        ),
      ),
    );
  }

  /// ℹ️ Information Box
  Widget _buildInfoBox() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.main.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.main.withOpacity(0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.mainDark, size: 18.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.infoText,
              style: AppTextStyles.getText3(context).copyWith(color: AppColors.mainDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: RichText(
        text: TextSpan(
          text: text,
          style: AppTextStyles.getText2(context).copyWith(color: AppColors.grayMain, fontWeight: FontWeight.bold),
          children: isRequired ? [TextSpan(text: AppLocalizations.of(context)!.requiredField, style: AppTextStyles.getText3(context).copyWith(color: Colors.grey))] : [],
        ),
      ),
    );
  }

  Widget _buildValidatedFieldArabic({
    required TextEditingController controller,
    required String labelText,
    required void Function(String value) onChanged,
    bool isRequired = false,
  }) {
    final localizedLabel = isRequired ? '$labelText *' : labelText;

    return TextFormField(
        controller: controller,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^[\u0600-\u06FF\s]+$')),
        ],
        textDirection: detectTextDirection(controller.text),
        textAlign: getTextAlign(context),
        style: AppTextStyles.getText2(context),
        decoration: InputDecoration(
          labelText: localizedLabel,
          labelStyle: AppTextStyles.getText3(context).copyWith(
            color: Colors.grey,
            fontWeight: isRequired ? FontWeight.bold : FontWeight.normal,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.r),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.r),
            borderSide: const BorderSide(color: AppColors.main, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.r),
            borderSide: BorderSide(color: AppColors.red.withOpacity(0.5), width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.r),
            borderSide: BorderSide(color: AppColors.main.withOpacity(0.5), width: 1),
          ),

          suffixIcon: controller.text.isEmpty
              ? null
              : Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: Container(
              width: 15.w,
              height: 15.w,
              decoration: BoxDecoration(
                color: arabicNameRegex.hasMatch(controller.text)
                    ? AppColors.main
                    : AppColors.red,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  arabicNameRegex.hasMatch(controller.text)
                      ? Icons.check
                      : Icons.close,
                  color: Colors.white,
                  size: 14.sp,
                ),
              ),
            ),
          ),
        ),
        onChanged: (value) {
          onChanged(value.trim());
          setState(() {}); // تحديث رمز التحقق
        },
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return AppLocalizations.of(context)!.requiredField;
          }

          if (value != null && value.isNotEmpty) {
            if (value.trim().length < 2) {
              return AppLocalizations.of(context)!.minTwoLettersError; // أضف هذا السطر في ملف ARB
            }

            if (!RegExp(r'^[\u0600-\u06FF\s]+$').hasMatch(value)) {
              return AppLocalizations.of(context)!.arabicOnlyError;
            }
          }

          return null;
        }


    );
  }

  Widget _buildValidatedNumberField({
    required TextEditingController controller,
    required String labelText,
    required void Function(String value) onChanged,
    bool isRequired = false,
  }) {
    final localizedLabel = isRequired ? '$labelText *' : labelText;

    final isValid = controller.text.isEmpty
        ? null
        : RegExp(r'^\d{1,3}$').hasMatch(controller.text);

    return TextFormField(
      controller: controller,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      textDirection: detectTextDirection(controller.text),
      textAlign: getTextAlign(context),
      style: AppTextStyles.getText2(context),
      decoration: InputDecoration(
        labelText: localizedLabel,
        labelStyle: WidgetStateTextStyle.resolveWith((states) {
          if (states.contains(WidgetState.error)) {
            return AppTextStyles.getText3(context).copyWith(color: AppColors.red);
          }
          return AppTextStyles.getText3(context).copyWith(color: Colors.grey);
        }),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: AppColors.main, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: BorderSide(color: AppColors.red.withOpacity(0.5), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: BorderSide(color: AppColors.main.withOpacity(0.5), width: 1),
        ),
      ),
      onChanged: (value) {
        onChanged(value.trim());
        setState(() {});
      },
      validator: (value) {
        if (value == null || value.isEmpty) return null;
        if (!RegExp(r'^\d+$').hasMatch(value)) {
          return AppLocalizations.of(context)!.numbersOnlyError;
        }
        if (value.length > 3) {
          return AppLocalizations.of(context)!.max3DigitsError;
        }
        return null;
      },
    );
  }

  Widget _buildDropdownValidatedField({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    bool isRequired = false,
  }) {
    final localizedLabel = isRequired ? '$hint *' : hint;

    return DropdownButtonFormField<String>(
      value: value,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (val) {
        if (isRequired && (val == null || val.isEmpty)) {
          return AppLocalizations.of(context)!.requiredField;
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: localizedLabel,
        labelStyle: WidgetStateTextStyle.resolveWith((states) {
          if (states.contains(WidgetState.error)) {
            return AppTextStyles.getText3(context).copyWith(color: AppColors.red);
          }
          return AppTextStyles.getText3(context).copyWith(color: Colors.grey);
        }),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: AppColors.main, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: BorderSide(color: AppColors.red.withOpacity(0.5), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: BorderSide(color: AppColors.main.withOpacity(0.5), width: 1),
        ),
      ),
      dropdownColor: Colors.white.withOpacity(0.95),
      isExpanded: true,
      borderRadius: BorderRadius.circular(15.r),
      menuMaxHeight: 250.h,
      icon: Icon(Icons.arrow_drop_down, color: AppColors.main, size: 22.sp),
      items: items,
      onChanged: (val) {
        setState(() {
          onChanged(val);
        });
      },
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String labelText,
    required bool isRequired,
    required VoidCallback onTap,
  }) {
    final localizedLabel = isRequired ? '$labelText *' : labelText;

    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          readOnly: true,
          style: AppTextStyles.getText2(context),
          textDirection: detectTextDirection(controller.text),
          textAlign: getTextAlign(context),
          decoration: InputDecoration(
            labelText: localizedLabel,
            labelStyle: WidgetStateTextStyle.resolveWith((states) {
              if (states.contains(WidgetState.error)) {
                return AppTextStyles.getText3(context).copyWith(color: AppColors.red);
              }
              return AppTextStyles.getText3(context).copyWith(color: Colors.grey);
            }),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.r),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.r),
              borderSide: const BorderSide(color: AppColors.main, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.r),
              borderSide: BorderSide(color: AppColors.red.withOpacity(0.5), width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.r),
              borderSide: BorderSide(color: AppColors.main.withOpacity(0.5), width: 1),
            ),
          ),
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return AppLocalizations.of(context)!.dobRequired;
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildPhoneNumberField() {
    final rawInput = phoneController.text.trim();
    final localValid = RegExp(r'^0?9\d{8}$').hasMatch(rawInput);
    final formatted = rawInput.startsWith('09')
        ? '00963${rawInput.substring(1)}'
        : rawInput.startsWith('9')
        ? '00963$rawInput'
        : '';

    return TextFormField(
      controller: phoneController,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: TextInputType.number,
      maxLength: 10,
      style: AppTextStyles.getText2(context),
      textDirection: detectTextDirection(phoneController.text),
      textAlign: getTextAlign(context),
      decoration: InputDecoration(
        counterText: "",
        labelText: AppLocalizations.of(context)!.phoneNumber,
        labelStyle: WidgetStateTextStyle.resolveWith((states) {
          return AppTextStyles.getText3(context).copyWith(
            color: states.contains(WidgetState.error) ? AppColors.red : Colors.grey,
          );
        }),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        prefixIcon: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: Directionality(
            textDirection: detectTextDirection(phoneController.text),
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
        prefixIconConstraints: BoxConstraints(minWidth: 75.w, minHeight: 40.h),
        suffixIcon: phoneController.text.isEmpty
            ? null
            : Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Container(
            width: 20.w,
            height: 20.w,
            decoration: BoxDecoration(
              color: localValid && phoneErrorText == null ? AppColors.main : AppColors.red,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                localValid && phoneErrorText == null ? Icons.check : Icons.close,
                color: Colors.white,
                size: 14.sp,
              ),
            ),
          ),
        ),
        errorMaxLines: 3,
        suffixIconConstraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: AppColors.main, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: BorderSide(color: AppColors.red.withOpacity(0.5), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: BorderSide(color: AppColors.main.withOpacity(0.5), width: 1),
        ),
      ),
        onChanged: (value) async {
          if (value.length > 10) {
            phoneController.text = value.substring(0, 10);
            phoneController.selection = TextSelection.fromPosition(
              TextPosition(offset: phoneController.text.length),
            );
            return;
          }

          setState(() {
            phoneErrorText = null; // إزالة أي خطأ قديم
          });

          final trimmed = value.trim();
          if (RegExp(r'^0?9\d{8}$').hasMatch(trimmed)) {
            final formatted = trimmed.startsWith('09')
                ? '00963${trimmed.substring(1)}'
                : '00963$trimmed';

            final isDuplicate =
            await context.read<RelativesCubit>().isPhoneDuplicate(formatted);

            setState(() {
              phoneErrorText = isDuplicate
                  ? AppLocalizations.of(context)!.phoneAlreadyRegistered
                  : null;
            });
          }
        },
        validator: (value) {
      if (value == null || value.trim().isEmpty) return null;

      if (!RegExp(r'^0?9\d{8}$').hasMatch(value.trim())) {
        return AppLocalizations.of(context)!.invalidPhoneNumber;
      }

      if (phoneErrorText != null) {
        return phoneErrorText;
      }

      return null;
    }

    );
  }

  Widget _buildEmailField() {
    final rawEmail = emailController.text.trim();
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    final isValid = emailRegex.hasMatch(rawEmail);

    return TextFormField(
      controller: emailController,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: TextInputType.emailAddress,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9@._\-]')),
      ],
      textDirection: detectTextDirection(emailController.text),
      textAlign: getTextAlign(context),
      style: AppTextStyles.getText2(context),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.email,
        labelStyle: WidgetStateTextStyle.resolveWith((states) {
          return AppTextStyles.getText3(context).copyWith(
            color: states.contains(WidgetState.error) ? AppColors.red : Colors.grey,
          );
        }),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: const BorderSide(color: AppColors.main, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: BorderSide(color: AppColors.red.withOpacity(0.5), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: BorderSide(color: AppColors.main.withOpacity(0.5), width: 1),
        ),
        suffixIcon: emailController.text.isEmpty
            ? null
            : Padding(
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
        ),
      ),
      onChanged: (value) async {
        setState(() {}); // لتحديث شكل الصح/الخطأ

        // ✅ تحقق من التكرار إذا كان الإيميل صالح
        if (emailRegex.hasMatch(value)) {
          final exists = await context
              .read<RelativesCubit>()
              .isEmailDuplicate(value.trim());

          if (exists) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(AppLocalizations.of(context)!.emailAlreadyRegistered),
              backgroundColor: AppColors.red.withOpacity(0.8),
            ));

            emailController.clear();
            setState(() {});
          }
        }
      },
      validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        if (!emailRegex.hasMatch(value.trim())) {
          return AppLocalizations.of(context)!.invalidEmail;
        }
        return null;
      },
    );
  }

}
