import 'package:docsera/app/const.dart';
import 'package:docsera/screens/doctors/doctor_panel/doctor_dashboard.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> _logInDoctor() async {
    try {
      final input = _inputController.text.trim();
      final password = _passwordController.text.trim();

      final authResponse = await Supabase.instance.client.auth
          .signInWithPassword(email: input, password: password);

      final userId = authResponse.user?.id;
      if (userId == null) throw Exception("doctorNotFound");

      // ✅ جلب بيانات الطبيب من جدول doctors
      final doctorResponse = await Supabase.instance.client
          .from('doctors')
          .select()
          .eq('id', userId)
          .single();

      // ✅ حفظ البيانات محليًا
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDoctorLoggedIn', true);
      await prefs.setString('doctorId', doctorResponse['id']);
      await prefs.setString('doctorName', '${doctorResponse['first_name']} ${doctorResponse['last_name']}');
      await prefs.setString('doctorEmail', doctorResponse['email'] ?? 'Not provided');
      await prefs.setString('doctorPhone', doctorResponse['phone_number'] ?? 'Not provided');

      Navigator.pushAndRemoveUntil(
        context,
        fadePageRoute(DoctorDashboard(doctorData: doctorResponse)),
            (route) => false,
      );
    } catch (e) {
      print("❌ Login Error: $e");
      setState(() {
        if (e.toString().contains("Invalid login credentials")) {
          errorMessage = 'Incorrect email or password';
        } else {
          errorMessage = 'Doctor not found or login failed';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: const Text(
        "Doctor Log In",
        style: TextStyle(
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
            TextFormField(
              controller: _inputController,
              textDirection: detectTextDirection(_inputController.text),
              textAlign: getTextAlign(context),
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  isValid = value.isNotEmpty;
                  errorMessage = null;
                });
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _passwordController,
              obscureText: !isPasswordVisible,
              textDirection: detectTextDirection(_passwordController.text),
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
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: const TextStyle(color: AppColors.red, fontSize: 12),
              ),
            const SizedBox(height: 20),
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
