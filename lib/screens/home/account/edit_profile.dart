import 'package:docsera/app/text_styles.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/app/const.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';


class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  String userId = "";
  String gender = "";
  String country = "";
  bool isFormValid = false;
  final arabicNameRegex = RegExp(r'^[\u0600-\u06FF\s]{2,}$');

  final List<String> genderOptions = ["ذكر", "أنثى"];

  final List<String> cityOptions = [
    "دمشق", "حلب", "حمص", "حماة", "اللاذقية", "دير الزور",
    "الرقة", "إدلب", "درعا", "طرطوس", "الحسكة", "القامشلي", "السويداء"
  ];

  // Controllers for form fields
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController dateOfBirthController = TextEditingController();
  final TextEditingController streetController = TextEditingController();
  final TextEditingController buildingNrController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController countryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  @override
  void dispose() {
    // Dispose controllers
    firstNameController.dispose();
    lastNameController.dispose();
    dateOfBirthController.dispose();
    streetController.dispose();
    buildingNrController.dispose();
    cityController.dispose();
    countryController.dispose();
    super.dispose();
  }

  /// ✅ Load userId from SharedPreferences
  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId') ?? "";
    if (userId.isNotEmpty) {
      _fetchUserData();
    }
  }

  /// ✅ Fetch user data from Supabase and populate fields
  void _fetchUserData() async {
    if (userId.isEmpty) return;

    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    if (response.isNotEmpty) {
      final userData = response;
      setState(() {
        gender = userData['gender'] ?? "";
        firstNameController.text = userData['first_name'] ?? "";
        lastNameController.text = userData['last_name'] ?? "";
        dateOfBirthController.text = _formatDate(userData['date_of_birth']);
        streetController.text = userData['address']?['street'] ?? "";
        buildingNrController.text = userData['address']?['buildingNr'] ?? "";
        cityController.text = userData['address']?['city'] ?? "";
        countryController.text = userData['address']?['country'] ?? "";
        _validateForm();
      });
    }
  }


  String _formatDate(String? isoDate) {
    if (isoDate == null) return "";
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd.MM.yyyy').format(date);
    } catch (_) {
      return "";
    }
  }


  /// ✅ Save updated user data to Supabase
  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (buildingNrController.text.isNotEmpty &&
        (streetController.text.isEmpty ||
            cityController.text.isEmpty ||
            countryController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.buildingNrError),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    final supabase = Supabase.instance.client;

    try {
      await supabase
          .from('users')
          .update({
        'gender': gender,
        'first_name': firstNameController.text,
        'last_name': lastNameController.text,
        'date_of_birth': _convertToIsoDate(dateOfBirthController.text),
        'address': {
          'street': streetController.text,
          'buildingNr': buildingNrController.text,
          'city': cityController.text,
          'country': countryController.text,
        },
      })
          .eq('id', userId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.updateSuccess), backgroundColor: AppColors.main.withOpacity(0.7)),
      );

      Navigator.pop(context, true); // ✅ رجّع true عند نجاح الحفظ
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.updateFailed(e.toString())), backgroundColor: AppColors.red.withOpacity(0.7)),
      );
    }
  }

  String _convertToIsoDate(String formattedDate) {
    try {
      final date = DateFormat('dd.MM.yyyy').parse(formattedDate);
      return date.toIso8601String();
    } catch (_) {
      return "";
    }
  }



  /// ✅ Date picker for date of birth
  Future<void> _pickDate() async {
    DateTime initialDate = DateTime.now();
    if (dateOfBirthController.text.isNotEmpty) {
      try {
        initialDate = DateFormat('dd.MM.yyyy').parse(dateOfBirthController.text);
      } catch (_) {}
    }

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
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
        _validateForm();
      });
    }
  }

  /// ✅ Validate form and address fields
  void _validateForm() {
    setState(() {
      bool isAddressEmpty = streetController.text.isEmpty &&
          cityController.text.isEmpty &&
          countryController.text.isEmpty &&
          buildingNrController.text.isEmpty;

      bool isAddressValid = (streetController.text.isNotEmpty &&
          cityController.text.isNotEmpty &&
          countryController.text.isNotEmpty) ||
          isAddressEmpty;

      // ✅ Check if building number exists without other fields
      bool isBuildingNrAlone = buildingNrController.text.isNotEmpty &&
          (streetController.text.isEmpty ||
              cityController.text.isEmpty ||
              countryController.text.isEmpty);

      isFormValid = firstNameController.text.isNotEmpty &&
          lastNameController.text.isNotEmpty &&
          dateOfBirthController.text.isNotEmpty &&
          gender.isNotEmpty &&
          isAddressValid &&
          !isBuildingNrAlone;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background2,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, // يمنع تأثير الظل الغامق الذي يظهر عند التمرير
        elevation: 0,
        toolbarHeight: 70.h,
        title: Padding(
          padding: EdgeInsets.only(top: 35.h, bottom: 8.h),
          child: Text(
            AppLocalizations.of(context)!.editMyProfile,
            style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp ,color: Colors.black)
          ),
        ),
        centerTitle: true,
        leading: Padding(
          padding: EdgeInsets.only(top: 35.h, bottom: 8.h),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        onChanged: _validateForm,
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
                  _validateForm();
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
                _validateForm();
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
                _validateForm();
              }),
            ),

            SizedBox(height: 20.h),

            ElevatedButton(
              onPressed: isFormValid ? _saveProfile : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isFormValid ? AppColors.main : Colors.grey.shade400,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(AppLocalizations.of(context)!.save, style: AppTextStyles.getText1(context).copyWith(
                  color: Colors.white, fontWeight: FontWeight.bold),),
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

  /// 🏷️ Build Field Labels
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

  /// 📝 Build TextField
  Widget _buildTextField({
    required TextEditingController controller,
    String hintText = "",
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      textDirection: detectTextDirection(controller.text), // ✅ ضبط الاتجاه ديناميكيًا
      textAlign: getTextAlign(context),
      decoration: _inputDecoration(hintText: hintText),
      validator: validator,
      style: AppTextStyles.getText2(context),
    );
  }

  /// 🔽 Build Dropdown with Empty Option Support
  Widget _buildDropdown({
    required String? value,
    required List<String> options,
    required void Function(String?) onChanged,
    String hintText = "",
  }) {

    final genderDisplayMap = {
      "ذكر": AppLocalizations.of(context)!.male,
      "أنثى": AppLocalizations.of(context)!.female,
    };


    final cityDisplayMap = {
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
    };

    final countryDisplayMap = {
      "سوريا": AppLocalizations.of(context)!.syria,
    };



    return DropdownButtonFormField<String>(
      value: value?.isEmpty ?? true ? null : value,
      hint: Text(hintText, style: AppTextStyles.getText2(context)),
      items: options.map((String option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(
            option.isEmpty ? '—' :
            genderDisplayMap[option] ??
                cityDisplayMap[option] ??
                countryDisplayMap[option] ??
                option,
            style: AppTextStyles.getText2(context),
          ),
        );
      }).toList(),
      decoration: _inputDecoration(),
      onChanged: onChanged,
    );
  }


  /// 🎨 Standard Input Decoration
  InputDecoration _inputDecoration({String hintText = ""}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(color: Colors.grey, width: 0.6),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25.r),
        borderSide: const BorderSide(color: AppColors.main, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(color: AppColors.red, width: 1),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
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
            borderSide: BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.r),
            borderSide: BorderSide(color: AppColors.main, width: 2),
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
        labelStyle: MaterialStateTextStyle.resolveWith((states) {
          if (states.contains(MaterialState.error)) {
            return AppTextStyles.getText3(context).copyWith(color: AppColors.red);
          }
          return AppTextStyles.getText3(context).copyWith(color: Colors.grey);
        }),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: BorderSide(color: AppColors.main, width: 2),
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
        labelStyle: MaterialStateTextStyle.resolveWith((states) {
          if (states.contains(MaterialState.error)) {
            return AppTextStyles.getText3(context).copyWith(color: AppColors.red);
          }
          return AppTextStyles.getText3(context).copyWith(color: Colors.grey);
        }),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: BorderSide(color: AppColors.main, width: 2),
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
            labelStyle: MaterialStateTextStyle.resolveWith((states) {
              if (states.contains(MaterialState.error)) {
                return AppTextStyles.getText3(context).copyWith(color: AppColors.red);
              }
              return AppTextStyles.getText3(context).copyWith(color: Colors.grey);
            }),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.r),
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.r),
              borderSide: BorderSide(color: AppColors.main, width: 2),
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

}
