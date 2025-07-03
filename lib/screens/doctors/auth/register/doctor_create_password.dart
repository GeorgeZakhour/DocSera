import 'package:docsera/screens/doctors/doctor_panel/doctor_dashboard.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../app/const.dart';

class DoctorCreatePasswordPage extends StatefulWidget {
  final String doctorId;
  final String email;

  const DoctorCreatePasswordPage({super.key, required this.doctorId, required this.email});

  @override
  State<DoctorCreatePasswordPage> createState() => _DoctorCreatePasswordPageState();
}

class _DoctorCreatePasswordPageState extends State<DoctorCreatePasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isPasswordValid = false;

  /// Hash the password before storing
  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<void> _savePassword() async {
    if (_isPasswordValid) {
      final hashedPassword = _hashPassword(_passwordController.text);

      try {
        await Supabase.instance.client.from('doctors').update({
          "password": hashedPassword,
          "last_updated": DateTime.now().toIso8601String(),
        }).eq('id', widget.doctorId);


        // ✅ Save doctor info in SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isDoctorLoggedIn', true);
        await prefs.setString('doctorId', widget.doctorId);
        await prefs.setString('doctorEmail', widget.email);

        print("✅ Doctor registered & logged in. ID: ${widget.doctorId}");

        // ✅ Navigate directly to Doctor Dashboard
        Navigator.pushAndRemoveUntil(
          context,
          fadePageRoute( DoctorDashboard()),
              (route) => false, // Remove all previous routes
        );
      } catch (e) {
        print("❌ Error saving password: $e");
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(
      "Set Password", // Dynamic title
      style: const TextStyle(
        color: AppColors.whiteText,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              onChanged: (value) => setState(() => _isPasswordValid = value.length >= 8),
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isPasswordValid ? _savePassword : null,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.main),
              child: const Text("Save & Continue"),
            ),
          ],
        ),
      ),
    );
  }
}
