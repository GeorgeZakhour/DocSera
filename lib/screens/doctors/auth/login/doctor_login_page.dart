import 'package:docsera/app/const.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:crypto/crypto.dart'; // For hashing
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/screens/doctors/doctor_panel/doctor_dashboard.dart';
import 'dart:convert'; // For utf8 encoding
import 'package:flutter/material.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DoctorLoginPage extends StatefulWidget {
  const DoctorLoginPage({super.key});

  @override
  State<DoctorLoginPage> createState() => _DoctorLoginPageState();
}

class _DoctorLoginPageState extends State<DoctorLoginPage> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isPasswordVisible = false;
  bool isValid = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
  }

  /// **🔐 Hash the password using SHA-256**
  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// **🚀 Log in doctor using FirebaseAuth + Firestore**
  Future<void> _logInDoctor() async {
    try {
      final input = _inputController.text.trim();
      final hashedPassword = _hashPassword(_passwordController.text);

      // ✅ Fetch doctor from Firestore (email or phone number)
      QuerySnapshot doctorQuery = await FirebaseFirestore.instance
          .collection('doctors')
          .where('email', isEqualTo: input)
          .limit(1)
          .get();

      if (doctorQuery.docs.isEmpty) {
        // If no doctor found with email, try phone number
        doctorQuery = await FirebaseFirestore.instance
            .collection('doctors')
            .where('phoneNumber', isEqualTo: input)
            .limit(1)
            .get();
      }

      if (doctorQuery.docs.isNotEmpty) {
        final doctorDoc = doctorQuery.docs.first;
        final doctorData = doctorDoc.data() as Map<String, dynamic>;

        final storedPassword = doctorData['password']?.toString();
        final inputPassword = hashedPassword.toString();

        if (storedPassword == inputPassword) {
          // ✅ Save doctor info in SharedPreferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isDoctorLoggedIn', true);
          await prefs.setString('doctorId', doctorDoc.id); // 🔥 Store Doctor ID
          await prefs.setString('doctorName', '${doctorData['firstName']} ${doctorData['lastName']}');
          await prefs.setString('doctorEmail', doctorData['email'] ?? 'Not provided');
          await prefs.setString('doctorPhone', doctorData['phoneNumber']?.toString() ?? 'Not provided');

          print("✅ Doctor ID stored in SharedPreferences: ${doctorDoc.id}");

          // ✅ Navigate to `DoctorPanel` Instead of `DoctorDashboard`
          Navigator.pushAndRemoveUntil(
            context,
            fadePageRoute(DoctorDashboard(doctorData: doctorData)), // ✅ Navigate to DoctorDashboard
                (route) => false, // Remove previous pages
          );

        } else {
          print("❌ Password Mismatch! Login Failed.");
          setState(() {
            errorMessage = 'Incorrect email/phone or password';
          });
        }
      } else {
        print("❌ Doctor Not Found!");
        setState(() {
          errorMessage = 'Doctor not found';
        });
      }
    } catch (e) {
      print("❌ Error in login: $e");
      setState(() {
        errorMessage = 'Error: $e';
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(
      "Doctor Log In", // Dynamic title
      style: const TextStyle(
        color: AppColors.whiteText,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Log In as a Doctor",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // 🟢 Email or Phone Number Input
            TextFormField(
              controller: _inputController,
              textDirection: detectTextDirection(_inputController.text), // ✅ ضبط الاتجاه ديناميكيًا
              textAlign: getTextAlign(context),
              decoration: const InputDecoration(
                labelText: 'Email or Phone Number',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  isValid = value.isNotEmpty;
                  errorMessage = null; // Remove error message
                });
              },
            ),
            const SizedBox(height: 10),

            // 🔵 Password Input
            TextFormField(
              controller: _passwordController,
              obscureText: !isPasswordVisible,
              textDirection: detectTextDirection(_passwordController.text), // ✅ ضبط الاتجاه ديناميكيًا
              textAlign: getTextAlign(context),
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      isPasswordVisible = !isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 🔴 Error Message
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: const TextStyle(color: AppColors.red, fontSize: 12),
              ),
            const SizedBox(height: 20),

            // ✅ Login Button
            ElevatedButton(
              onPressed: isValid ? _logInDoctor : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isValid ? AppColors.main : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const SizedBox(
                width: double.infinity,
                child: Center(
                  child: Text(
                    'Log In',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
