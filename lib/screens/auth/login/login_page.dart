import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/login/login_otp.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart'; // For hashing
import 'package:docsera/app/const.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'dart:convert'; // For utf8 encoding
import 'package:flutter/material.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/services/firestore/firestore_user_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:local_auth/local_auth.dart'; // Face ID Auth
import '../../../Business_Logic/Account_page/user_cubit.dart';
import 'package:device_info_plus/device_info_plus.dart';



class LogInPage extends StatefulWidget {
  final String? preFilledInput; // Optional pre-filled email or phone number

  const LogInPage({super.key, this.preFilledInput});

  @override
  State<LogInPage> createState() => _LogInPageState();
}

class _LogInPageState extends State<LogInPage> {
  late TextEditingController _inputController;
  final TextEditingController _passwordController = TextEditingController();
  final FirestoreUserService _firestoreService = FirestoreUserService();
  final FirebaseAuth _auth = FirebaseAuth.instance; // ✅ Use FirebaseAuth
  final LocalAuthentication auth = LocalAuthentication();
  bool isPasswordVisible = false;
  bool isValid = false;
  bool isFaceIdEnabled = false;
  String? errorMessage;
  bool isLoading = false;
  String biometricType = ""; // Default empty string
  bool biometricAvailable = false;
  bool isFaceID = false;


  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: widget.preFilledInput);
    isValid = widget.preFilledInput != null && widget.preFilledInput!.isNotEmpty;
    _checkBiometricType();
  }







  Future<void> _checkBiometricType() async {
    final prefs = await SharedPreferences.getInstance();
    final isBiometricEnabled = prefs.getBool('enableFaceID') ?? false;

    if (!isBiometricEnabled) return;

    final availableBiometrics = await auth.getAvailableBiometrics();
    setState(() {
      biometricAvailable = availableBiometrics.isNotEmpty;
      isFaceID = availableBiometrics.contains(BiometricType.face);
    });

    print("✅ Biometric available: $biometricAvailable");
    print("✅ Is Face ID: $isFaceID");
  }


  /// **🔐 Hash the password using SHA-256**
  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<String> getDeviceId() async {
    final info = DeviceInfoPlugin();
    final androidInfo = await info.androidInfo;
    return androidInfo.id ?? androidInfo.serialNumber ?? androidInfo.device ?? '';
  }



  /// ✅ تنسيق الرقم لصيغة 00963 كما في صفحة التسجيل
  String getFormattedPhoneNumber(String phone) {
    phone = phone.trim();
    if (phone.startsWith('09')) {
      phone = phone.substring(1);
    }
    return "00963$phone";
  }


  Future<void> _logInUser() async {
    setState(() => isLoading = true);

    try {
      final input = _inputController.text.trim();
      final password = _passwordController.text;

      // ✅ التحقق إذا كان إدخال المستخدم رقم هاتف
      final isPhone = RegExp(r'^0\d{9}$').hasMatch(input) || RegExp(r'^00963\d{9}$').hasMatch(input);
      final formattedPhone = isPhone ? getFormattedPhoneNumber(input) : null;

      print("📥 المستخدم أدخل: $input");
      if (isPhone) {
        print("📞 تم التعرف عليه كرقم هاتف وتم تنسيقه إلى: $formattedPhone");
      } else {
        print("📧 تم التعرف عليه كإيميل: $input");
      }

      // ✅ جلب بيانات المستخدم من Firestore
      final userDoc = await _firestoreService.getUserByEmailOrPhone(isPhone ? formattedPhone! : input);
      final userData = userDoc.data();

      if (userData == null) throw Exception("❌ لم يتم العثور على بيانات المستخدم");

      // ✅ استخراج الإيميل الوهمي لتسجيل الدخول
      final fakeEmail = userData['fakeEmail'];
      if (fakeEmail == null || fakeEmail.isEmpty) throw Exception("❌ الإيميل الوهمي غير موجود");

      print("📨 الإيميل الوهمي الذي سيتم استخدامه لتسجيل الدخول: $fakeEmail");

      // ✅ تسجيل الدخول باستخدام FirebaseAuth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: fakeEmail,
        password: password,
      );

      final userId = userCredential.user?.uid;
      if (userId == null) throw Exception("❌ لم يتم العثور على معرف المستخدم");

      // ✅ تخزين البيانات في SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userId);
      await prefs.setString('userName', '${userData['firstName']} ${userData['lastName']}');
      await prefs.setString('userEmail', userData['email'] ?? '');
      await prefs.setString('userPhone', userData['phoneNumber'] ?? '');
      await prefs.setString('userPassword', password); // للبصمة

      // ✅ تحديث الـ Cubit
      context.read<UserCubit>().loadUserData(context);

      // ✅ الانتقال للواجهة الرئيسية
      if (context.mounted) {
        final deviceId = await getDeviceId();
        final trustedDevices = (userData['trustedDevices'] as List?) ?? [];
        final is2FAEnabled = userData['twoFactorAuthEnabled'] == true;

        if (is2FAEnabled && !trustedDevices.contains(deviceId)) {
          // 👇 إرسال رمز OTP والتنقل إلى صفحة تحقق OTP المخصصة لتسجيل الدخول
          final phone = userData['phoneNumber'];

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => LoginOTPPage(
                phoneNumber: phone,
                userId: userDoc.id, // ✅ الحل هنا
              ),
            ),
                (route) => false,
          );
        } else {
          // 👇 المستخدم موثق مسبقًا أو تحقق بخطوتين غير مفعل
          Navigator.pushAndRemoveUntil(
            context,
            fadePageRoute(CustomBottomNavigationBar()),
                (route) => false,
          );
        }
      }


    } catch (e) {
      print("❌ خطأ أثناء تسجيل الدخول: $e");
      setState(() {
        errorMessage = AppLocalizations.of(context)!.loginError(e.toString());
      });
    } finally {
      setState(() => isLoading = false);
    }
  }




  Future<void> _authenticateWithFaceID() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('userPhone');
      final savedPassword = prefs.getString('userPassword');

      print("🟢 [DEBUG] Checking Saved Credentials for Biometric Login");
      print("🔹 Saved Phone: ${savedPhone ?? 'Not Found'}");
      print("🔹 Password Exists: ${savedPassword != null}");

      if (savedPhone == null || savedPassword == null) {
        print("❌ No saved credentials.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.faceIdNoCredentials)),
        );
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: biometricType == AppLocalizations.of(context)!.faceIdTitle
            ? AppLocalizations.of(context)!.faceIdPrompt
            : AppLocalizations.of(context)!.fingerprintPrompt,
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (authenticated) {
        final formattedDisplayPhone = savedPhone.startsWith('00963')
            ? '0${savedPhone.substring(5)}'
            : savedPhone;

        print("✅ Auto-filled from biometric: $formattedDisplayPhone");

        setState(() {
          _inputController.text = formattedDisplayPhone;
          _passwordController.text = savedPassword;
          isValid = true;
        });

        await _logInUser(); // ✅ نفذ تسجيل الدخول تلقائيًا بعد تعبئة الحقول
      }
    } catch (e) {
      print("❌ Biometric Authentication Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.faceIdFailed)),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.logIn,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.logIn,
                style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp, color: AppColors.mainDark)),
            SizedBox(height: 20.h),

            // 🟢 Email or Phone Number Input
            TextFormField(
              controller: _inputController,
              textDirection: detectTextDirection(_inputController.text), // ✅ ضبط الاتجاه ديناميكيًا
              textAlign: getTextAlign(context),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.emailOrPhone,
                labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                border: const OutlineInputBorder(),
                hintStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
              ),
              // onTap: () async {
              //   if (isFaceIdEnabled) {
              //     _showBiometricLoginSheet(); // ✅ Suggest biometric login first
              //   }
              // },
              onChanged: (value) {
                setState(() {
                  isValid = value.isNotEmpty;
                  errorMessage = null;
                });
              },
            ),
            SizedBox(height: 10.h),

            // 🔵 Password Input
            TextFormField(
              controller: _passwordController,
              obscureText: !isPasswordVisible,
              textDirection: detectTextDirection(_inputController.text), // ✅ ضبط الاتجاه ديناميكيًا
              textAlign: getTextAlign(context),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.password,
                labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    size: 16.sp,
                  ),
                  onPressed: () {
                    setState(() {
                      isPasswordVisible = !isPasswordVisible;
                    });
                  },
                ),
              ),
              // onTap: () async {
              //   if (isFaceIdEnabled) {
              //     _showBiometricLoginSheet(); // ✅ Suggest biometric login first
              //   }
              // },
            ),
            if (errorMessage != null) SizedBox(height: 10.h),

            // 🔴 Error Message
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: AppTextStyles.getText2(context).copyWith(color: AppColors.red),
              ),

            // 🔵 بعد حقل كلمة المرور مباشرة:
            SizedBox(height: 5.h),
            Align(
              alignment: AlignmentDirectional.centerStart, // ✅ يتكيف مع اللغات RTL/LTR
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.sp),
                child: TextButton(
                  onPressed: () {
                    // 🚀 تنفيذ وظيفة استعادة كلمة المرور لاحقًا
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, // ✅ إزالة أي هوامش داخل الزر
                    minimumSize: Size(0, 0), // ✅ تقليل المساحة القابلة للنقر
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap, // ✅ تقليل حجم الضغط
                    overlayColor: Colors.transparent, // ✅ تأثير عند النقر
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.forgotPassword, // 🔹 نص متعدد اللغات
                    style: AppTextStyles.getText3(context).copyWith(
                      color: AppColors.mainDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 20.h),

            // ✅ Login Button
            ElevatedButton(
              onPressed: isValid ? _logInUser : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isValid ? AppColors.main : Colors.grey,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.r),
                ),
                minimumSize: Size(double.infinity, 50.h),
              ),
              child: isLoading
                  ? SizedBox(
                width: 15.w,
                height: 15.h,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                AppLocalizations.of(context)!.logIn,
                style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
              ),
            ),

            if (biometricAvailable)
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    onTap: _authenticateWithFaceID,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 50.h),
                      child: isFaceID
                          ? Image.asset(
                        'assets/images/face_Id.png',
                        width: 65.w,
                        height: 65.w,
                        color: AppColors.main,
                      )
                          : Image.asset(
                        'assets/images/fingerprint.png',
                        width: 55.w,
                        height: 55.w,
                        color: AppColors.main,
                      ),
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
