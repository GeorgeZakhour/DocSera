import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/app/const.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';


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

  final List<String> genderOptions = ["Male", "Female"];
  final List<String> cityOptions = [
    "Damascus", "Aleppo", "Homs", "Hama", "Latakia", "Deir ez-Zor",
    "Raqqa", "Idlib", "Daraa", "Tartus", "Al-Hasakah", "Qamishli", "Suwayda"
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

  /// ✅ Fetch user data from Firestore and populate fields
  void _fetchUserData() async {
    if (userId.isEmpty) return;

    DocumentSnapshot docSnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (docSnapshot.exists) {
      Map<String, dynamic> userData = docSnapshot.data() as Map<String, dynamic>;
      setState(() {
        gender = userData['gender'] ?? "";
        firstNameController.text = userData['firstName'] ?? "";
        lastNameController.text = userData['lastName'] ?? "";
        dateOfBirthController.text = userData['dateOfBirth'] ?? "";
        streetController.text = userData['address']?['street'] ?? "";
        buildingNrController.text = userData['address']?['buildingNr'] ?? "";
        cityController.text = userData['address']?['city'] ?? "";
        countryController.text = userData['address']?['country'] ?? "";
        _validateForm();
      });
    }
  }

  /// ✅ Save updated user data to Firestore
  /// ✅ Save updated user data to Firestore
  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ Check if building number is alone
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

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'gender': gender,
        'firstName': firstNameController.text,
        'lastName': lastNameController.text,
        'dateOfBirth': dateOfBirthController.text,
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

            SizedBox(height: 16.h),

            _buildLabel(AppLocalizations.of(context)!.gender, isRequired: true),
            _buildDropdown(
              value: gender.isEmpty ? null : gender,
              options: genderOptions,
              hintText: AppLocalizations.of(context)!.selectGender,
              onChanged: (value) {
                setState(() {
                  gender = value!;
                  _validateForm();
                });
              },
            ),

            SizedBox(height: 12.h),

            _buildLabel(AppLocalizations.of(context)!.firstName, isRequired: true),
            _buildTextField(
              controller: firstNameController,
              validator: (value) => (value == null || value.isEmpty) ? AppLocalizations.of(context)!.firstNameRequired : null,
            ),

            SizedBox(height: 12.h),

            _buildLabel(AppLocalizations.of(context)!.lastName, isRequired: true),
            _buildTextField(
              controller: lastNameController,
              validator: (value) => (value == null || value.isEmpty) ? AppLocalizations.of(context)!.lastNameRequired : null,
            ),

            SizedBox(height: 12.h),

            _buildLabel(AppLocalizations.of(context)!.dateOfBirth, isRequired: true),
            GestureDetector(
              onTap: _pickDate,
              child: AbsorbPointer(
                child: _buildTextField(
                  controller: dateOfBirthController,
                  hintText: AppLocalizations.of(context)!.dateFormatHint,
                  validator: (value) => (value == null || value.isEmpty) ? AppLocalizations.of(context)!.dobRequired : null,
                ),
              ),
            ),

            SizedBox(height: 20.h),

            Text(AppLocalizations.of(context)!.address,
                style: AppTextStyles.getTitle1(context)),

            SizedBox(height: 12.h),

            _buildLabel(AppLocalizations.of(context)!.street),
            _buildTextField(controller: streetController),

            SizedBox(height: 12.h),

            _buildLabel(AppLocalizations.of(context)!.buildingNr),
            _buildTextField(controller: buildingNrController),

            SizedBox(height: 12.h),

            _buildLabel(AppLocalizations.of(context)!.city),
            _buildDropdown(
              value: cityController.text.isEmpty ? null : cityController.text,
              options: [''] + cityOptions,
              hintText: AppLocalizations.of(context)!.selectCity,
              onChanged: (value) => setState(() {
                cityController.text = value!;
                _validateForm();
              }),
            ),

            SizedBox(height: 12.h),

            _buildLabel(AppLocalizations.of(context)!.country),
            _buildDropdown(
              value: countryController.text.isEmpty ? null : countryController.text,
              options: [''] + ["Syria"],
              hintText: AppLocalizations.of(context)!.selectCountry,
              onChanged: (value) => setState(() {
                countryController.text = value!;
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
          style: AppTextStyles.getText2(context).copyWith(
            color: AppColors.blackText,
            fontWeight: FontWeight.w500,
          ),
          children: isRequired
              ? [TextSpan(
            text: AppLocalizations.of(context)!.requiredField,
            style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
          ),]
              : [],
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
}
