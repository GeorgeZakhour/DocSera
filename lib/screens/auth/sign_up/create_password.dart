import 'package:docsera/screens/auth/sign_up/terms_of_use_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../app/const.dart';
import '../../../app/text_styles.dart';
import '../../../models/sign_up_info.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CreatePasswordPage extends StatefulWidget {
  final SignUpInfo signUpInfo;

  const CreatePasswordPage({super.key, required this.signUpInfo});

  @override
  State<CreatePasswordPage> createState() => _CreatePasswordPageState();
}

class _CreatePasswordPageState extends State<CreatePasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  double _strength = 0.0;
  String _strengthLabel = "";
  Color _strengthColor = Colors.transparent;
  bool _showProgressBar = false;
  String _hintMessage = "";
  bool _isPasswordValid = false;

  /// Method to check password strength and update UI accordingly
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

    // Complexity checks
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasSymbol = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    final hasExcessiveRepeatedCharacters =
    password.contains(RegExp(r'(.)\1{2,}')); // Three or more repeated characters
    final isSimplePattern =
    password.contains(RegExp(r'(abcd|qwerty|1234)')); // Simple patterns

    // Rule: Password length less than 8
    if (password.length < 8) {
      _setStrength(
        strength: 0.25,
        label: AppLocalizations.of(context)!.weakPassword,
        color: AppColors.red,
        hint: AppLocalizations.of(context)!.useEightCharacters,
        isValid: false,
      );
    }
    // Rule: Simple patterns
    else if (isSimplePattern) {
      _setStrength(
        strength: 0.25,
        label: AppLocalizations.of(context)!.weakPassword,
        color: AppColors.red,
        hint: AppLocalizations.of(context)!.passwordTooSimple,
        isValid: false,
      );
    }
    // Rule: Excessive repeated characters
    else if (hasExcessiveRepeatedCharacters &&
        (!hasUppercase || !hasLowercase || !hasNumber || !hasSymbol)) {
      _setStrength(
        strength: 0.5,
        label: AppLocalizations.of(context)!.fairPassword,
        color: Colors.orange,
        hint: AppLocalizations.of(context)!.passwordRepeatedCharacters,
        isValid: false,
      );
    }
    // Rule: Missing complexity
    else if (!hasUppercase || !hasLowercase || !hasNumber || !hasSymbol) {
      _setStrength(
        strength: 0.5,
        label: AppLocalizations.of(context)!.fairPassword,
        color: Colors.orange,
        hint: AppLocalizations.of(context)!.passwordTooSimple,
        isValid: false,
      );
    }
    // Rule: Good password (length < 12 but meets complexity)
    else if (password.length < 12) {
      _setStrength(
        strength: 0.75,
        label: AppLocalizations.of(context)!.goodPassword,
        color: Colors.green[300]!,
        isValid: true,
      );
    }
    // Rule: Strong password (length >= 12 and meets complexity)
    else {
      _setStrength(
        strength: 1.0,
        label: AppLocalizations.of(context)!.strongPassword,
        color: Colors.green[800]!,
        isValid: true,
      );
    }
  }

  /// Helper method to update password strength properties
  void _setStrength({
    required double strength,
    required String label,
    required Color color,
    String hint = "",
    required bool isValid,
  }) {
    setState(() {
      _strength = strength;
      _strengthLabel = label;
      _strengthColor = color;
      _hintMessage = hint;
      _isPasswordValid = isValid;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.signUp,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.createPassword,
              style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
            ),
            SizedBox(height: 20.h),

            // Password Field with Strength Indicator
            _buildPasswordField(),

            SizedBox(height: 10.h),

            // Strength Label and Hint
            if (_showProgressBar) ...[
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
            ],

            SizedBox(height: 20.h),

            // Progress Bar
            LinearProgressIndicator(
              value: 0.65,
              backgroundColor: AppColors.main.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.main),
              minHeight: 4,
            ),
            SizedBox(height: 20.h),

            // Continue Button
            _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  /// Password Field with Visibility Toggle
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9!@#\$%^&*()_+{}\[\]:;"<>,.?\/\\|`~\-]')),
    ],
      obscureText: !_isPasswordVisible,
      textDirection: detectTextDirection(_passwordController.text),
      textAlign: getTextAlign(context),
      style: AppTextStyles.getText2(context),
      onChanged: (value) {
        _checkPasswordStrength(value);
        widget.signUpInfo.password = value;
      },
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.password,
        labelStyle: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.r),
          borderSide: BorderSide(color: AppColors.main, width: 2),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            size: 20.sp,
            color: Colors.grey,
          ),
          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
      ),
    );
  }

  /// Continue Button
  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity, // ✅ يخلي الزر ياخد العرض الكامل
      child: ElevatedButton(
        onPressed: _isPasswordValid
            ? () {
          // final hashedPassword = sha256.convert(utf8.encode(_passwordController.text)).toString();
          widget.signUpInfo.password = _passwordController.text;
          Navigator.push(
            context,
            fadePageRoute(TermsOfUsePage(signUpInfo: widget.signUpInfo)),
          );
        }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isPasswordValid ? AppColors.main : Colors.grey,
          padding: EdgeInsets.symmetric(vertical: 12.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
        child: Text(
          AppLocalizations.of(context)!.continueButton,
          style: AppTextStyles.getText2(context).copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
