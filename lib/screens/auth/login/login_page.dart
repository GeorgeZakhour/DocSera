import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/app/text_styles.dart';
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


  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: widget.preFilledInput);
    isValid = widget.preFilledInput != null && widget.preFilledInput!.isNotEmpty;
    _checkFaceIdAvailability();
  }

  Future<void> _checkFaceIdAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    bool isEnabled = prefs.getBool('enableFaceID') ?? false;
    String savedBiometricType = prefs.getString('biometricType') ?? AppLocalizations.of(context)!.biometricTitle;

    // ✅ Load saved email and password
    String? savedEmail = prefs.getString('userEmail');
    String? savedPassword = prefs.getString('userPassword');

    setState(() {
      isFaceIdEnabled = isEnabled;
      biometricType = savedBiometricType;
    });

    print("🟢 Face ID Enabled: $isFaceIdEnabled");
    print("🟢 Biometric Type: $biometricType");
    print("🟢 Saved Email: $savedEmail");
    print("🟢 Saved Password: ${savedPassword != null ? 'Exists' : 'Not Found'}");

    if (isEnabled && savedEmail != null && savedPassword != null) {
      print("✅ Suggesting Face ID Login");
      _authenticateWithFaceID();
    }
  }


  /// **🔐 Hash the password using SHA-256**
  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // /// **🚀 Log in user using FirebaseAuth + Firestore**
  // Future<void> _logInUser() async {
  //   setState(() => isLoading = true);
  //   try {
  //     final input = _inputController.text.trim();
  //     final hashedPassword = _hashPassword(_passwordController.text);
  //
  //     final userDoc = await _firestoreService.getUserByEmailOrPhone(input);
  //     if (userDoc.exists) {
  //       final userData = userDoc.data();
  //       final storedPassword = userData?['password'];
  //
  //       if (storedPassword == hashedPassword) {
  //         SharedPreferences prefs = await SharedPreferences.getInstance();
  //
  //         // ✅ Preserve Face ID settings
  //         bool wasFaceIdEnabled = prefs.getBool('enableFaceID') ?? false;
  //         String? biometricType = prefs.getString('biometricType');
  //
  //         // ✅ Ensure credentials are saved
  //         await prefs.setBool('isLoggedIn', true);
  //         await prefs.setString('userId', userDoc.id);
  //         await prefs.setString('userName', '${userData?['firstName']} ${userData?['lastName']}');
  //         await prefs.setString('userEmail', userData?['email'] ?? '');
  //         await prefs.setString('userPhone', userData?['phoneNumber'] ?? '');
  //         await prefs.setString('userPassword', _passwordController.text); // ✅ Store plain password for biometric login
  //
  //         // ✅ Restore Face ID settings
  //         await prefs.setBool('enableFaceID', wasFaceIdEnabled);
  //         if (biometricType != null) {
  //           await prefs.setString('biometricType', biometricType);
  //         }
  //
  //         print("✅ [DEBUG] Saved Credentials for Face ID: Email = ${prefs.getString('userEmail')}, Password Exists: ${prefs.getString('userPassword') != null}");
  //
  //         // ✅ Reload user data
  //         context.read<UserCubit>().loadUserData(context);
  //
  //         // ✅ Navigate to Home
  //         if (mounted) {
  //           Navigator.pushAndRemoveUntil(
  //             context,
  //             fadePageRoute(CustomBottomNavigationBar()),
  //                 (route) => false,
  //           );
  //         }
  //       }
  //
  //       else {
  //         setState(() {
  //           errorMessage = AppLocalizations.of(context)!.incorrectPassword;
  //         });
  //       }
  //     } else {
  //       setState(() {
  //         errorMessage = AppLocalizations.of(context)!.userNotFound;
  //       });
  //     }
  //   } catch (e) {
  //     setState(() {
  //       errorMessage = AppLocalizations.of(context)!.loginError(e.toString());
  //     });
  //   } finally {
  //     setState(() => isLoading = false);
  //   }
  // }

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
        Navigator.pushAndRemoveUntil(
          context,
          fadePageRoute(CustomBottomNavigationBar()),
              (route) => false,
        );
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




  Future<void> _authenticateWithFaceID({bool allowDismiss = false}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? savedEmail = prefs.getString('userEmail');
      String? savedPassword = prefs.getString('userPassword');

      // ✅ Debugging: Check if credentials are stored properly
      print("🟢 [DEBUG] Checking Saved Credentials for Face ID Login");
      print("🔹 Email: ${savedEmail ?? 'Not Found'}");
      print("🔹 Password Exists: ${savedPassword != null}");

      if (savedEmail == null || savedPassword == null) {
        print("❌ No saved credentials for Face ID login.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.faceIdNoCredentials)),
        );
        return;
      }

      bool authenticated = await auth.authenticate(
        localizedReason: biometricType == AppLocalizations.of(context)!.faceIdTitle
            ? AppLocalizations.of(context)!.faceIdPrompt
            : AppLocalizations.of(context)!.fingerprintPrompt,
        options: AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        setState(() {
          _inputController.text = savedEmail;
          _passwordController.text = savedPassword;
          isValid = true;
        });

        print("✅ Auto-filled credentials with Face ID");
      }
    } catch (e) {
      print("❌ Face ID Authentication Error: $e");

      if (allowDismiss) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.faceIdFailed)),
        );
      }
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

            if (isFaceIdEnabled)
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: _authenticateWithFaceID,
                    child: Container(
                      width: 150.w,
                      height: 150.h,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, // ✅ توسيط كل شيء داخل الدائرة
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            biometricType == AppLocalizations.of(context)!.faceIdTitle
                                ? Icons.face
                                : Icons.fingerprint,
                            size: 70.w, // ✅ أيقونة كبيرة
                            color: AppColors.main,
                          ),
                          SizedBox(height: 8.h),
                          Flexible(
                            child: Text(
                              biometricType == AppLocalizations.of(context)!.faceIdTitle
                                  ? AppLocalizations.of(context)!.logInWithFaceId
                                  : AppLocalizations.of(context)!.logInWithFingerprint,
                              style: AppTextStyles.getText3(context).copyWith(
                                color: AppColors.main,
                              ),
                              textAlign: TextAlign.center, // ✅ توسيط النص داخل الدائرة
                            ),
                          ),
                        ],
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
