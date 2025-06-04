import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditRelativePage extends StatefulWidget {
  final String relativeId;
  final Map<String, dynamic> relativeData;

  const EditRelativePage({Key? key, required this.relativeId, required this.relativeData}) : super(key: key);

  @override
  State<EditRelativePage> createState() => _EditRelativePageState();
}

class _EditRelativePageState extends State<EditRelativePage> {
  final _formKey = GlobalKey<FormState>();
  String gender = "", country = "";
  bool isFormValid = false;

  final List<String> genderOptions = ["Male", "Female"];
  final List<String> cityOptions = [
    "Damascus", "Aleppo", "Homs", "Hama", "Latakia", "Deir ez-Zor",
    "Raqqa", "Idlib", "Daraa", "Tartus", "Al-Hasakah", "Qamishli", "Suwayda"
  ];

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
  void initState() {
    super.initState();
    _populateFields();
  }

  void _populateFields() {
    firstNameController.text = widget.relativeData['firstName'] ?? "";
    lastNameController.text = widget.relativeData['lastName'] ?? "";
    dateOfBirthController.text = widget.relativeData['dateOfBirth'] ?? "";
    emailController.text = widget.relativeData['email'] ?? "";
    phoneController.text = widget.relativeData['phoneNumber'] ?? "";
    streetController.text = widget.relativeData['address']?['street'] ?? "";
    buildingNrController.text = widget.relativeData['address']?['buildingNr'] ?? "";
    cityController.text = widget.relativeData['address']?['city'] ?? "";
    countryController.text = widget.relativeData['address']?['country'] ?? "";
    gender = widget.relativeData['gender'] ?? "";
    _validateForm();
  }

  Future<void> _updateRelative() async {
    if (!_formKey.currentState!.validate()) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString('userId') ?? "";
    if (userId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('relatives')
          .doc(widget.relativeId)
          .update({
        'firstName': firstNameController.text,
        'lastName': lastNameController.text,
        'dateOfBirth': dateOfBirthController.text,
        'gender': gender,
        'email': emailController.text,
        'phoneNumber': phoneController.text,
        'address': {
          'street': streetController.text,
          'buildingNr': buildingNrController.text,
          'city': cityController.text,
          'country': countryController.text,
        },
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.updateSuccess), backgroundColor: AppColors.main.withOpacity(0.7)),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.updateFailed(e.toString())), backgroundColor: AppColors.red.withOpacity(0.7)),
      );
    }
  }

  void _validateForm() {
    setState(() {
      bool addressValid = (streetController.text.isNotEmpty && cityController.text.isNotEmpty && countryController.text.isNotEmpty) ||
          (streetController.text.isEmpty && cityController.text.isEmpty && countryController.text.isEmpty && buildingNrController.text.isEmpty);

      isFormValid = firstNameController.text.isNotEmpty &&
          lastNameController.text.isNotEmpty &&
          dateOfBirthController.text.isNotEmpty &&
          gender.isNotEmpty &&
          addressValid;
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
        shadowColor: Colors.transparent,
        toolbarHeight: 70.h,
        title: Padding(
          padding: EdgeInsets.only(top: 35.h, bottom: 8.h),
          child: Text(AppLocalizations.of(context)!.editRelative, style: AppTextStyles.getTitle1(context).copyWith(color: Colors.black, fontSize: 12.sp)),
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

            SizedBox(height: 16.h),
            _buildLabel(AppLocalizations.of(context)!.gender, isRequired: true),
            _buildDropdown(value: gender, options: genderOptions, hintText: AppLocalizations.of(context)!.selectGender, onChanged: (val) => setState(() => gender = val!)),
            SizedBox(height: 12.h),
            _buildLabel(AppLocalizations.of(context)!.firstName, isRequired: true),
            _buildTextField(controller: firstNameController),
            SizedBox(height: 12.h),
            _buildLabel(AppLocalizations.of(context)!.lastName, isRequired: true),
            _buildTextField(controller: lastNameController),
            SizedBox(height: 12.h),
            _buildLabel(AppLocalizations.of(context)!.dateOfBirth, isRequired: true),
            _buildTextField(controller: dateOfBirthController),
            SizedBox(height: 12.h),
            _buildLabel(AppLocalizations.of(context)!.phoneNumber),
            _buildTextField(controller: phoneController),
            SizedBox(height: 12.h),
            _buildLabel(AppLocalizations.of(context)!.email),
            _buildTextField(controller: emailController),
            SizedBox(height: 20.h),

            Text(AppLocalizations.of(context)!.address, style: AppTextStyles.getTitle1(context)),
            SizedBox(height: 12.h),
            _buildLabel(AppLocalizations.of(context)!.street),
            _buildTextField(controller: streetController),
            SizedBox(height: 12.h),
            _buildLabel(AppLocalizations.of(context)!.buildingNr),
            _buildTextField(controller: buildingNrController),
            SizedBox(height: 12.h),
            _buildLabel(AppLocalizations.of(context)!.city),
            _buildDropdown(value: cityController.text, options: cityOptions, hintText: AppLocalizations.of(context)!.selectCity, onChanged: (val) => setState(() => cityController.text = val!)),
            SizedBox(height: 12.h),
            _buildLabel(AppLocalizations.of(context)!.country),
            _buildDropdown(value: countryController.text, options: ["Syria"], hintText: AppLocalizations.of(context)!.selectCountry, onChanged: (val) => setState(() => countryController.text = val!)),

            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: isFormValid ? _updateRelative : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isFormValid ? AppColors.main : Colors.grey.shade400,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(AppLocalizations.of(context)!.save, style: AppTextStyles.getText1(context).copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

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
            child: Text(AppLocalizations.of(context)!.infoText, style: AppTextStyles.getText3(context).copyWith(color: AppColors.mainDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller}) {
    return TextFormField(
      controller: controller,
      textDirection: detectTextDirection(controller.text),
      textAlign: getTextAlign(context),
      decoration: _inputDecoration(),
      style: AppTextStyles.getText2(context),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: RichText(
        text: TextSpan(
          text: text,
          style: AppTextStyles.getText2(context).copyWith(color: AppColors.blackText, fontWeight: FontWeight.w500),
          children: isRequired ? [TextSpan(text: AppLocalizations.of(context)!.requiredField, style: AppTextStyles.getText3(context).copyWith(color: Colors.grey))] : [],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> options,
    required void Function(String?) onChanged,
    String hintText = "",
  }) {
    final genderDisplayMap = {
      "Male": AppLocalizations.of(context)!.male,
      "Female": AppLocalizations.of(context)!.female,
    };

    final cityDisplayMap = {
      "Damascus": AppLocalizations.of(context)!.damascus,
      "Aleppo": AppLocalizations.of(context)!.aleppo,
      "Homs": AppLocalizations.of(context)!.homs,
      "Hama": AppLocalizations.of(context)!.hama,
      "Latakia": AppLocalizations.of(context)!.latakia,
      "Deir ez-Zor": AppLocalizations.of(context)!.deirEzzor,
      "Raqqa": AppLocalizations.of(context)!.raqqa,
      "Idlib": AppLocalizations.of(context)!.idlib,
      "Daraa": AppLocalizations.of(context)!.daraa,
      "Tartus": AppLocalizations.of(context)!.tartus,
      "Al-Hasakah": AppLocalizations.of(context)!.alHasakah,
      "Qamishli": AppLocalizations.of(context)!.qamishli,
      "Suwayda": AppLocalizations.of(context)!.suwayda,
    };

    final countryDisplayMap = {
      "Syria": AppLocalizations.of(context)!.syria,
    };

    return DropdownButtonFormField<String>(
      value: value?.isEmpty ?? true ? null : value,
      hint: Text(hintText, style: AppTextStyles.getText2(context)),
      items: options.map((option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(
            option.isEmpty
                ? '—'
                : genderDisplayMap[option] ??
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

  InputDecoration _inputDecoration() {
    return InputDecoration(
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
}
