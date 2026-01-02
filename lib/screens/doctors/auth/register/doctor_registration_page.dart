import 'package:docsera/screens/doctors/doctor_panel/doctor_dashboard.dart';
import 'package:docsera/utils/time_utils.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorRegistrationPage extends StatefulWidget {
  const DoctorRegistrationPage({super.key});

  @override
  _DoctorRegistrationPageState createState() => _DoctorRegistrationPageState();
}

class _DoctorRegistrationPageState extends State<DoctorRegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _clinicController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otherSpecialtyController = TextEditingController();
  final TextEditingController _specialtyInputController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _buildingNrController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _addressDetailsController = TextEditingController();
  final TextEditingController _profileDescriptionController = TextEditingController();
  final TextEditingController _otherLanguageController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();



  // Dropdown selections
  String _selectedTitle = "Dr.";
  String _selectedGender = "Male";
  String? _selectedSpecialty;
  bool _isOtherSpecialty = false;
  final List<String> _specialties = [];
  String _selectedCountry = "Syria";
  final List<String> _selectedLanguages = [];
  final List<String> _availableLanguages = ["العربية", "الإنجليزية", "الفرنسية", "الألمانية", "أخرى"];
  bool _isOtherLanguage = false;



  // List of specialties
  final List<String> _popularSpecialties = [
    "الطب العام",
    "جراحة العظام",
    "أمراض القلب",
    "الأعصاب",
    "الأمراض الجلدية",
    "طب الأطفال",
    "الطب النفسي",
    "الأنف والأذن والحنجرة",
    "طب العيون",
    "أمراض النساء",
    "الأورام",
    "الغدد الصماء",
    "الأشعة",
    "المسالك البولية",
    "طب أسنان",
    "أخرى"
  ];
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: const BorderSide(color: AppColors.main, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  void _addSpecialty() {
    String specialty = _specialtyInputController.text.trim();
    if (specialty.isNotEmpty && !_specialties.contains(specialty)) {
      setState(() {
        _specialties.add(specialty);
        _specialtyInputController.clear(); // Clear the input field after adding
      });
    }
  }

  final Map<String, List<Map<String, String>>> _openingHours = {
    "Monday": [],
    "Tuesday": [],
    "Wednesday": [],
    "Thursday": [],
    "Friday": [],
    "Saturday": [],
    "Sunday": []
  };

  Future<String?> _pickTime(BuildContext context) async {
    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: AppColors.main, // Main color
            colorScheme: const ColorScheme.light(
              primary: AppColors.main, // Header & buttons
              onPrimary: Colors.white, // Text on header
              onSurface: AppColors.mainDark, // Text on picker
            ),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      final hour = selectedTime.hourOfPeriod; // 12-hour format
      final minute = selectedTime.minute.toString().padLeft(2, '0');
      final period = selectedTime.period == DayPeriod.am ? "AM" : "PM";

      return "$hour:$minute $period";
    }
    return null;
  }


  void _addTimeSlot(String day) async {
    String? fromTime = await _pickTime(context);
    if (fromTime == null) return;

    String? toTime = await _pickTime(context);
    if (toTime == null) return;

    setState(() {
      _openingHours[day]?.add({"from": fromTime, "to": toTime});
    });
  }

  void _removeTimeSlot(String day, int index) {
    setState(() {
      _openingHours[day]?.removeAt(index);
    });
  }

  Future<void> _registerDoctor() async {
    if (_formKey.currentState!.validate()) {
      try {
        // ✅ إنشاء حساب باستخدام Supabase Auth
        final authResponse = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final doctorId = authResponse.user?.id;
        if (doctorId == null) throw Exception("Signup failed");

        // ✅ حفظ البيانات الإضافية في جدول doctors
        await Supabase.instance.client.from('doctors').insert({
          "id": doctorId,
          "title": _selectedTitle,
          "gender": _selectedGender,
          "first_name": _firstNameController.text.trim(),
          "last_name": _lastNameController.text.trim(),
          "clinic": _clinicController.text.trim(),
          "email": _emailController.text.trim(),
          "phone_number": _phoneController.text.trim(),
          "specialty": _selectedSpecialty == "Other"
              ? _otherSpecialtyController.text.trim()
              : _selectedSpecialty,
          "profile_description": _profileDescriptionController.text.trim(),
          "address": {
            "street": _streetController.text.trim(),
            "buildingNr": _buildingNrController.text.trim(),
            "city": _cityController.text.trim(),
            "country": _selectedCountry,
            "details": _addressDetailsController.text.trim(),
          },
          "specialties": _specialties,
          "languages": _selectedLanguages,
          "opening_hours": _openingHours,
          "created_at": DocSeraTime.nowUtc().toIso8601String(),
          "last_updated": DocSeraTime.nowUtc().toIso8601String(),
        });

        // ✅ حفظ بيانات الدخول
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isDoctorLoggedIn', true);
        await prefs.setString('doctorId', doctorId);
        await prefs.setString('doctorEmail', _emailController.text.trim());

        // ✅ التنقل إلى لوحة التحكم
        Navigator.pushAndRemoveUntil(
          context,
          fadePageRoute(DoctorDashboard()),
              (route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }





  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: const Text(
      "Doctor Registration", // Dynamic title
      style: TextStyle(
        color: AppColors.whiteText,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // Title Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedTitle,
                  decoration: _inputDecoration("Title"),
                  items: ["Dr.", ""].map((String item) {
                    return DropdownMenuItem(value: item, child: Text(item));
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedTitle = value ?? ""),
                ),

                const SizedBox(height: 16),

                // Gender Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: _inputDecoration("Gender"),
                  items: ["Male", "Female"].map((String item) {
                    return DropdownMenuItem(value: item, child: Text(item));
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedGender = value ?? "Male"),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextField(controller: _firstNameController, decoration: _inputDecoration("First Name")),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(controller: _lastNameController, decoration: _inputDecoration("Last Name")),
                    ),
                  ],
                ),
                const SizedBox(height: 16),


                // Clinic Name
                TextField(controller: _clinicController, decoration: _inputDecoration("Clinic Name")),
                const SizedBox(height: 16),

                TextField(controller: _emailController, decoration: _inputDecoration("Email")),
                const SizedBox(height: 16),

                // Phone Number
                TextField(controller: _phoneController, decoration: _inputDecoration("Phone Number"), keyboardType: TextInputType.number),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _inputDecoration("Password"),
                ),
                const SizedBox(height: 16),


                // Specialty Selection
                DropdownButtonFormField<String>(
                  value: _selectedSpecialty,
                  decoration: _inputDecoration("Primary Specialty"),
                  items: _popularSpecialties.map((String item) {
                    return DropdownMenuItem(value: item, child: Text(item));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSpecialty = value;
                      _isOtherSpecialty = (value == "Other");
                    });
                  },
                ),

                // Show "Specify Specialty" TextField if "Other" is selected
                if (_isOtherSpecialty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: TextField(controller: _otherSpecialtyController, decoration: _inputDecoration("Specify your specialty")),
                  ),
                const SizedBox(height: 12),


                // Specialties (Multiple)
                const Text("Specialties", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),

                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _specialties.map((specialty) {
                    return Chip(
                      label: Text(specialty, style: const TextStyle(fontSize: 12, color: Colors.white)),
                      backgroundColor: AppColors.main,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      deleteIcon: const Icon(Icons.close, color: Colors.white, size: 16),
                      onDeleted: () => setState(() => _specialties.remove(specialty)),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _specialtyInputController,
                        decoration: _inputDecoration("Add Specialty"),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppColors.main),
                      onPressed: _addSpecialty,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                const Text("Address", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                TextField(controller: _streetController, decoration: _inputDecoration("Street")),
                const SizedBox(height: 16),

                TextField(controller: _buildingNrController, decoration: _inputDecoration("Building Number (Optional)")),
                const SizedBox(height: 16),

                TextField(controller: _cityController, decoration: _inputDecoration("City")),
                const SizedBox(height: 16),

// Country (Dropdown)
                DropdownButtonFormField<String>(
                  value: "Syria",
                  decoration: _inputDecoration("Country"),
                  items: ["Syria"].map((String item) {
                    return DropdownMenuItem(value: item, child: Text(item));
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedCountry = value ?? "Syria"),
                ),

                const SizedBox(height: 16),

// ✅ Details (Extra Address Information)
                TextField(
                  controller: _addressDetailsController,
                  decoration: _inputDecoration("Additional Address Details (Optional)"),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
// Opening Hours Section
                const Text("Profile Description", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _profileDescriptionController,
                  decoration: _inputDecoration("Profile Description"),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),

// Opening Hours Section
                const Text("Opening Hours", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                Column(
                  children: _openingHours.keys.map((day) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(day, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: AppColors.main),
                              onPressed: () => _addTimeSlot(day),
                            ),
                          ],
                        ),
                        Column(
                          children: List.generate(_openingHours[day]!.length, (index) {
                            final slot = _openingHours[day]![index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.background3,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("${slot['from']} - ${slot['to']}", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                  GestureDetector(
                                    onTap: () => _removeTimeSlot(day, index),
                                    child: const Icon(Icons.close, color: AppColors.mainDark, size: 18),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                // Languages Selection Section
                const SizedBox(height: 16),
                const Text("Languages", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

// Dropdown for Languages
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration("Select Language"),
                  items: _availableLanguages.map((String lang) {
                    return DropdownMenuItem(value: lang, child: Text(lang));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      if (value == "Other") {
                        _isOtherLanguage = true;
                      } else if (value != null && !_selectedLanguages.contains(value)) {
                        _selectedLanguages.add(value);
                        _isOtherLanguage = false;
                      }
                    });
                  },
                ),

// Show text field if "Other" is selected
                if (_isOtherLanguage)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: TextField(
                      controller: _otherLanguageController,
                      decoration: _inputDecoration("Specify your other language"),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          setState(() {
                            _selectedLanguages.add(value);
                            _isOtherLanguage = false;
                            _otherLanguageController.clear();
                          });
                        }
                      },
                    ),
                  ),

// Selected Languages as Chips
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: _selectedLanguages.map((lang) {
                    return Chip(
                      label: Text(lang, style: const TextStyle(fontSize: 12, color: Colors.white)),
                      backgroundColor: AppColors.main,
                      deleteIcon: const Icon(Icons.close, color: Colors.white),
                      onDeleted: () {
                        setState(() => _selectedLanguages.remove(lang));
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 30),

// Register Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _registerDoctor,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: const Text("Register", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),


              ],
            ),
          ),
        ),
      ),
    );
  }
}
