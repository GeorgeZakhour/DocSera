import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/app/const.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';


class AddRelativePage extends StatefulWidget {
  const AddRelativePage({Key? key}) : super(key: key);

  @override
  _AddRelativePageState createState() => _AddRelativePageState();
}

class _AddRelativePageState extends State<AddRelativePage> {
  final _formKey = GlobalKey<FormState>();
  String userId = "";
  String accountHolderEmail = "";
  String accountHolderPhone = "";
  String gender = "";
  String country = "";
  bool isFormValid = false;
  bool isAuthorized = false;

  final List<String> genderOptions = ["Male", "Female"];
  final List<String> cityOptions = [
    "Damascus", "Aleppo", "Homs", "Hama", "Latakia", "Deir ez-Zor",
    "Raqqa", "Idlib", "Daraa", "Tartus", "Al-Hasakah", "Qamishli", "Suwayda"
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
  void initState() {
    super.initState();
    _loadUserId();
  }

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

  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId') ?? "";
    if (userId.isNotEmpty) {
      _fetchUserInfo();
    }
  }

  /// ✅ Fetch user’s email & phone for fallback data
  void _fetchUserInfo() async {
    FirebaseFirestore.instance.collection('users').doc(userId).get().then((doc) {
      if (doc.exists) {
        if (!mounted) return;
        setState(() {
          accountHolderEmail = doc['email'] ?? "";
          accountHolderPhone = doc['phoneNumber'] ?? "";
        });
      }
    });
  }

  void _saveRelative() async {
    if (!_formKey.currentState!.validate() || !isAuthorized) return;

    // ✅ Check if building number is alone
    if (buildingNrController.text.isNotEmpty &&
        (streetController.text.isEmpty ||
            cityController.text.isEmpty ||
            countryController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill Street, City, and Country before adding a Building Number.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).collection('relatives').add({
        'firstName': firstNameController.text,
        'lastName': lastNameController.text,
        'dateOfBirth': dateOfBirthController.text,
        'gender': gender,
        'email': emailController.text.isNotEmpty ? emailController.text : accountHolderEmail,
        'phoneNumber': phoneController.text.isNotEmpty ? phoneController.text : accountHolderPhone,
        'address': {
          'street': streetController.text,
          'buildingNr': buildingNrController.text,
          'city': cityController.text,
          'country': countryController.text,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Relative added successfully!'), backgroundColor: AppColors.main.withOpacity(0.7)),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add relative: $e'), backgroundColor: AppColors.red.withOpacity(0.7)),
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
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 70.h,
        title: Text(AppLocalizations.of(context)!.addRelative, style: AppTextStyles.getTitle1(context).copyWith(color: Colors.black,fontSize: 12.sp)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
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
              hintText : AppLocalizations.of(context)!.firstNameRequired,
              validator: (value) => (value == null || value.isEmpty) ? 'First name is required' : null,
            ),

            SizedBox(height: 12.h),
            _buildLabel( AppLocalizations.of(context)!.lastName, isRequired: true),
            _buildTextField(
              controller: lastNameController,
              hintText : AppLocalizations.of(context)!.lastNameRequired,
              validator: (value) => (value == null || value.isEmpty) ? 'Last name is required' : null,
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
            SizedBox(height: 12.h),
            _buildLabel(AppLocalizations.of(context)!.phone),
            _buildTextField(controller: phoneController,
              hintText: AppLocalizations.of(context)!.enterPhoneOptional,
            ),
            SizedBox(height: 12.h),

            _buildLabel(AppLocalizations.of(context)!.email ),
            _buildTextField(controller: emailController,
              hintText: AppLocalizations.of(context)!.enterEmailOptional,
            ),
            SizedBox(height: 20.h),

            Text(AppLocalizations.of(context)!.address, style: AppTextStyles.getTitle1(context)),
            SizedBox(height: 12.h),

            _buildLabel(AppLocalizations.of(context)!.street),
            _buildTextField(controller: streetController,
              hintText: AppLocalizations.of(context)!.enterStreet,
            ),
            SizedBox(height: 12.h),

            _buildLabel(AppLocalizations.of(context)!.buildingNr),
            _buildTextField(controller: buildingNrController,
              hintText: AppLocalizations.of(context)!.enterBuildingOptional,
            ),

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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.main), // Border color
                borderRadius: BorderRadius.circular(8), // Rounded corners
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
              onPressed: isFormValid ?_saveRelative : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isFormValid ? AppColors.main : Colors.grey.shade400,
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
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: AppColors.blackText,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          children: isRequired
              ? [
            const TextSpan(
              text: ' (required)',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            )
          ]
              : [],
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
      items: options.map((String option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(option.isEmpty
              ? '—'
              : genderDisplayMap[option] ??
              cityDisplayMap[option] ??
              countryDisplayMap[option] ??
              option, style: AppTextStyles.getText2(context),), // Show dash for empty option
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
