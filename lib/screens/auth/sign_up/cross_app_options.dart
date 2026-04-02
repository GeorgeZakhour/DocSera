import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/sign_up_info.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/auth/sign_up/sign_up_phone.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CrossAppOptionsPage extends StatefulWidget {
  final SignUpInfo signUpInfo;
  const CrossAppOptionsPage({super.key, required this.signUpInfo});

  @override
  State<CrossAppOptionsPage> createState() => _CrossAppOptionsPageState();
}

class _CrossAppOptionsPageState extends State<CrossAppOptionsPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();

  bool _isLoading = false;
  String _selectedOption = ''; // 'existing' or 'new'
  bool _isPasswordVisible = false;
  bool _isNewPasswordVisible = false;

  double _strength = 0.0;
  String _strengthLabel = "";
  Color _strengthColor = Colors.transparent;
  bool _showProgressBar = false;
  String _hintMessage = "";
  bool _isPasswordValid = false;

  void _checkPasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() {
        _showProgressBar = false;
        _strength = 0.0;
        _strengthLabel = "";
        _strengthColor = Colors.transparent;
        _hintMessage = "";
        _isPasswordValid = false;
      });
      return;
    }

    _showProgressBar = true;

    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasSymbol = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    final hasExcessiveRepeatedCharacters = password.contains(RegExp(r'(.)\1{2,}'));
    final isSimplePattern = password.contains(RegExp(r'(abcd|qwerty|1234)'));

    if (password.length < 8) {
      _setStrength(
        strength: 0.25,
        label: AppLocalizations.of(context)!.weakPassword,
        color: AppColors.red,
        hint: AppLocalizations.of(context)!.useEightCharacters,
        isValid: false,
      );
    } else if (isSimplePattern) {
      _setStrength(
        strength: 0.25,
        label: AppLocalizations.of(context)!.weakPassword,
        color: AppColors.red,
        hint: AppLocalizations.of(context)!.passwordTooSimple,
        isValid: false,
      );
    } else if (hasExcessiveRepeatedCharacters && (!hasUppercase || !hasLowercase || !hasNumber || !hasSymbol)) {
      _setStrength(
        strength: 0.5,
        label: AppLocalizations.of(context)!.fairPassword,
        color: Colors.orange,
        hint: AppLocalizations.of(context)!.passwordRepeatedCharacters,
        isValid: false,
      );
    } else if (!hasUppercase || !hasLowercase || !hasNumber || !hasSymbol) {
      _setStrength(
        strength: 0.5,
        label: AppLocalizations.of(context)!.fairPassword,
        color: Colors.orange,
        hint: AppLocalizations.of(context)!.passwordTooSimple,
        isValid: false,
      );
    } else if (password.length < 12) {
      _setStrength(
        strength: 0.75,
        label: AppLocalizations.of(context)!.goodPassword,
        color: Colors.green[300]!,
        isValid: true,
      );
    } else {
      _setStrength(
        strength: 1.0,
        label: AppLocalizations.of(context)!.strongPassword,
        color: Colors.green[800]!,
        isValid: true,
      );
    }
  }

  void _setStrength({required double strength, required String label, required Color color, String hint = "", required bool isValid}) {
    setState(() {
      _strength = strength;
      _strengthLabel = label;
      _strengthColor = color;
      _hintMessage = hint;
      _isPasswordValid = isValid;
    });
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: AppColors.red,
    ));
  }

  Future<void> _submitExisting() async {
    final local = AppLocalizations.of(context)!;
    final pass = _passwordController.text.trim();
    if (pass.isEmpty) {
      _showSnack(local.passwordHint);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Verify the existing password via cross_app_signup edge function
      await Supabase.instance.client.functions.invoke(
        'cross_app_signup',
        body: {
          'email': widget.signUpInfo.email,
          'password': pass,
          'app': 'docsera',
        },
      );

      // Sign out — session will be re-established during final registration in RecapPage
      await Supabase.instance.client.auth.signOut();

      // Proceed to the next step (Phone → Identity → Terms → Recap)
      widget.signUpInfo.password = pass;
      if (mounted) {
        Navigator.push(
          context,
          fadePageRoute(SignUpFirstPage(signUpInfo: widget.signUpInfo)),
        );
      }
    } catch (e) {
      if (e.toString().contains('wrong_password')) {
        _showSnack(local.wrongPassword);
      } else {
        _showSnack(local.errorUpdatingProfile);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitNew() async {
    final local = AppLocalizations.of(context)!;
    final oldPass = _passwordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confPass = _confirmNewPasswordController.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confPass.isEmpty) {
      _showSnack(local.fillAllFields);
      return;
    }
    if (newPass != confPass) {
      _showSnack(local.passwordsDoNotMatch);
      return;
    }
    if (!_isPasswordValid) {
      _showSnack(_hintMessage.isNotEmpty ? _hintMessage : local.weakPassword);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Verify identity by trying to sign in with the old password
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: widget.signUpInfo.email!,
          password: oldPass,
        );
      } catch (e) {
        _showSnack(local.wrongPassword);
        setState(() => _isLoading = false);
        return;
      }
      
      // 2. Change password
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPass));

      // 3. Call cross_app_signup with the new password to ensure consistency
      await Supabase.instance.client.functions.invoke(
        'cross_app_signup',
        body: {
          'email': widget.signUpInfo.email,
          'password': newPass,
          'app': 'docsera',
        },
      );

      // Sign out — session will be re-established during final registration in RecapPage
      await Supabase.instance.client.auth.signOut();

      widget.signUpInfo.password = newPass;

      if (mounted) {
        Navigator.push(
          context,
          fadePageRoute(SignUpFirstPage(signUpInfo: widget.signUpInfo)),
        );
      }
    } catch (e) {
      _showSnack(local.errorUpdatingProfile);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    return BaseScaffold(
      title: Text(
        local.signUp,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              local.crossAppOptionsTitle,
              style: AppTextStyles.getTitle1(context).copyWith(fontSize: 18.sp),
            ),
            SizedBox(height: 10.h),
            Text(
              local.crossAppOptionsMessage,
              style: AppTextStyles.getText2(context).copyWith(color: Colors.grey[700]),
            ),
            SizedBox(height: 24.h),
            
            if (_selectedOption.isEmpty) ...[
              ElevatedButton(
                onPressed: () => setState(() => _selectedOption = 'existing'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(local.useExistingPassword, style: AppTextStyles.getText2(context).copyWith(color: AppColors.whiteText, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 16.h),
              OutlinedButton(
                onPressed: () => setState(() => _selectedOption = 'new'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: AppColors.main),
                ),
                child: Text(local.createNewPassword, style: AppTextStyles.getText2(context).copyWith(color: AppColors.main, fontWeight: FontWeight.bold)),
              ),
            ] else ...[
               Text(
                  local.verifyCurrentPassword,
                  style: AppTextStyles.getText1(context).copyWith(fontSize: 14.sp),
               ),
               SizedBox(height: 10.h),
               TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  style: AppTextStyles.getText2(context),
                  decoration: InputDecoration(
                    labelText: local.passwordHint,
                    labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.r)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25.r),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25.r),
                      borderSide: const BorderSide(color: AppColors.main, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    )
                  ),
               ),
               
               if (_selectedOption == 'new') ...[
                  SizedBox(height: 24.h),
                  Divider(color: Colors.grey[300]),
                  SizedBox(height: 16.h),
                  Center(
                    child: Text(
                       local.newPasswordWillApplyToBoth,
                       style: AppTextStyles.getText3(context).copyWith(color: Colors.orange[800], fontWeight: FontWeight.bold),
                       textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextFormField(
                     controller: _newPasswordController,
                     obscureText: !_isNewPasswordVisible,
                     style: AppTextStyles.getText2(context),
                     onChanged: (value) {
                       _checkPasswordStrength(value);
                     },
                     decoration: InputDecoration(
                       labelText: local.createNewPassword,
                       labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.r)),
                       enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.r),
                        borderSide: const BorderSide(color: Colors.grey),
                       ),
                       focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.r),
                        borderSide: const BorderSide(color: AppColors.main, width: 2),
                       ),
                       suffixIcon: IconButton(
                         icon: Icon(_isNewPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                         onPressed: () => setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
                       )
                     ),
                  ),
                  SizedBox(height: 5.h),
                  if (_showProgressBar) ...[
                    // ── Password Strength Progress Bar ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: LinearProgressIndicator(
                        value: _strength,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                        minHeight: 6.h,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      _strengthLabel,
                      style: AppTextStyles.getText2(context).copyWith(color: _strengthColor),
                    ),
                    SizedBox(height: 5.h),
                    if (_hintMessage.isNotEmpty)
                      Text(
                        _hintMessage,
                        style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                      ),
                    SizedBox(height: 10.h),
                  ],
                  SizedBox(height: 11.h),
                  TextFormField(
                     controller: _confirmNewPasswordController,
                     obscureText: !_isNewPasswordVisible,
                     style: AppTextStyles.getText2(context),
                     decoration: InputDecoration(
                       labelText: local.confirmPassword,
                       labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.r)),
                       enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.r),
                        borderSide: const BorderSide(color: Colors.grey),
                       ),
                       focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.r),
                        borderSide: const BorderSide(color: AppColors.main, width: 2),
                       ),
                     ),
                  ),
               ],

               SizedBox(height: 32.h),
               ElevatedButton(
                  onPressed: _isLoading ? null : (_selectedOption == 'existing' ? _submitExisting : _submitNew),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.main,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(local.continueButton, style: AppTextStyles.getText2(context).copyWith(color: AppColors.whiteText, fontWeight: FontWeight.bold)),
               ),
               SizedBox(height: 16.h),
               Center(
                 child: TextButton(
                    onPressed: _isLoading ? null : () {
                       setState(() {
                          _selectedOption = '';
                          _passwordController.clear();
                          _newPasswordController.clear();
                          _confirmNewPasswordController.clear();
                       });
                    },
                    child: Text(local.back, style: AppTextStyles.getText2(context).copyWith(color: Colors.grey[600])),
                 ),
               )
            ],
            
            SizedBox(height: 30.h),
          ],
        ),
      ),
    );
  }
}
