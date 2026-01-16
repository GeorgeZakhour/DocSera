import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/Business_Logic/Account_page/profile/account_profile_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/profile/account_profile_state.dart';
import 'package:docsera/Business_Logic/Account_page/security/account_security_cubit.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/utils/input_decoration.dart';
import 'package:docsera/screens/home/account/sheets/otp_verification_sheet.dart';

class EditContactInfoSheet extends StatefulWidget {
  final String fieldType;
  final String currentValue;
  final String? customTitle;

  const EditContactInfoSheet({
    super.key,
    required this.fieldType,
    required this.currentValue,
    this.customTitle,
  });

  @override
  State<EditContactInfoSheet> createState() => _EditContactInfoSheetState();
}

class _EditContactInfoSheetState extends State<EditContactInfoSheet> {
  late TextEditingController controller;
  String? errorMessage;
  bool isChecking = false;

  @override
  void initState() {
    super.initState();
    // Pre-formatting logic
    String formattedCurrentValue = widget.currentValue;
    if (widget.fieldType == 'phoneNumber') {
      formattedCurrentValue = _formatPhoneForDisplay(widget.currentValue);
    }
    
    // Check for "Not Provided" text to clear it
    // We need context to access localization, but context is not available safely in initState for some patterns.
    // However, usually "Not Provided" comes from logic before passing here.
    // We will assume currentValue is the raw value or display value.
    // The previous logic checked against AppLocalizations.of(context)!.notProvided.
    // Since we can't do that easily in initState without context, we will handle it in build or rely on caller to pass clean data.
    // Ideally caller should pass RAW data. The caller in AccountPage passes:
    // profileState.phone or profileState.email directly.
    // But `_showEditFieldSheet` in original code did:
    // formattedCurrentValue == AppLocalizations.of(context)!.notProvided ? '' : formattedCurrentValue
    
    controller = TextEditingController(text: formattedCurrentValue);
  }

  // Helpers
  String _formatPhoneForDisplay(String phone) {
    if (phone.startsWith('00963')) return '0${phone.substring(5)}';
    return phone;
  }

  String _normalizePhoneNumber(String phone) {
    phone = phone.trim();
    if (phone.startsWith('00963')) return phone;
    if (phone.startsWith('09')) return '00963${phone.substring(1)}';
    if (phone.startsWith('9') && phone.length == 9) return '00963$phone';
    return phone;
  }
  
  bool _isValidPhoneNumber(String input) {
    if (!input.startsWith('9') && !input.startsWith('09')) return false;
    int requiredLength = input.startsWith('09') ? 10 : 9;
    return input.length == requiredLength;
  }

  @override
  Widget build(BuildContext context) {
    // We handle "Not Provided" check here if needed, but it's better if caller passes empty string for "not provided".
    // In extracted logic, we assumed caller passed profileState.phone/email which are empty strings if not provided usually.
    // Let's ensure controller text is cleared if it matches "Not Provided" localized string
    if (controller.text == AppLocalizations.of(context)!.notProvided) {
      controller.text = '';
    }

    final profileState = context.read<AccountProfileCubit>().state;
    if (profileState is! AccountProfileLoaded) return const SizedBox.shrink();

    final originalNormalizedValue = widget.fieldType == 'phoneNumber' 
        ? profileState.phone 
        : profileState.email;

    final isNotVerified = widget.fieldType == 'phoneNumber' && !profileState.isPhoneVerified;

    final title = widget.customTitle ??
        (widget.fieldType == 'phoneNumber'
            ? AppLocalizations.of(context)!.editPhoneNumber
            : AppLocalizations.of(context)!.editEmail);

    final hintText = widget.fieldType == 'phoneNumber'
        ? AppLocalizations.of(context)!.newPhoneNumber
        : AppLocalizations.of(context)!.newEmailAddress;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16.w,
          right: 16.w,
          top: 16.w
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTextStyles.getTitle1(context)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          TextFormField(
            controller: controller,
            keyboardType: widget.fieldType == 'phoneNumber'
                ? TextInputType.number
                : TextInputType.emailAddress,
            textDirection: detectTextDirection(controller.text),
            textAlign: getTextAlign(context),
            style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp),
            maxLength: widget.fieldType == 'phoneNumber' ? 10 : 100,
            decoration: getInputDecoration(hintText: hintText).copyWith(
              counterText: "",
              errorText: errorMessage,
              prefixText: widget.fieldType == 'phoneNumber' ? "+963 | " : null,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.fieldType == 'phoneNumber' &&
                      controller.text.isNotEmpty &&
                      _normalizePhoneNumber(controller.text) != originalNormalizedValue)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      child: Container(
                        width: 20.w,
                        height: 20.w,
                        decoration: BoxDecoration(
                          color: _isValidPhoneNumber(controller.text)
                              ? AppColors.main.withValues(alpha: 0.8)
                              : AppColors.red.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isValidPhoneNumber(controller.text)
                              ? Icons.check
                              : Icons.close,
                          color: Colors.white,
                          size: 14.sp,
                        ),
                      ),
                    ),
                  if (isNotVerified)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                      margin: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: AppColors.yellow.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.notVerified,
                        style: AppTextStyles.getText3(context).copyWith(
                          color: AppColors.yellow,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[\u0600-\u06FF]')),
            ],
            onChanged: (_) => setState(() => errorMessage = null),
          ),

          SizedBox(height: 16.h),

          ElevatedButton(
            onPressed: isChecking
                ? null
                : () async {
              final raw = controller.text.trim();
              final normalized = widget.fieldType == 'phoneNumber'
                  ? _normalizePhoneNumber(raw)
                  : raw;

              // Validation
              if (widget.fieldType == 'phoneNumber' && !_isValidPhoneNumber(raw)) {
                setState(() => errorMessage = AppLocalizations.of(context)!.invalidPhoneNumber);
                return;
              }

              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
              if (widget.fieldType == 'email' && !emailRegex.hasMatch(raw)) {
                setState(() => errorMessage = AppLocalizations.of(context)!.invalidEmail);
                return;
              }

              if (normalized == originalNormalizedValue) {
                setState(() => errorMessage = AppLocalizations.of(context)!.samePhone);
                return;
              }

              setState(() => isChecking = true);
              final securityCubit = context.read<AccountSecurityCubit>();

              bool available;
              if (widget.fieldType == 'phoneNumber') {
                available = await securityCubit.checkPhoneAvailability(normalized);
              } else {
                available = await securityCubit.checkEmailAvailability(raw.trim().toLowerCase());
              }

              setState(() => isChecking = false);

              if (!available) {
                setState(() => errorMessage = widget.fieldType == 'phoneNumber'
                    ? AppLocalizations.of(context)!.alreadyExistsPhone
                    : AppLocalizations.of(context)!.alreadyExistsEmail);
                return;
              }

              if (context.mounted) {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: AppColors.background2,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (context) => OtpVerificationSheet(
                      fieldType: widget.fieldType,
                      targetValue: normalized
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.main,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: Size(double.infinity, 50.h),
            ),
            child: isChecking
                ? SizedBox(
              width: 16.w,
              height: 16.h,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Text(
              (widget.fieldType == 'phoneNumber' && isNotVerified)
                  ? AppLocalizations.of(context)!.verify
                  : (widget.fieldType == 'email' && originalNormalizedValue.isEmpty)
                  ? AppLocalizations.of(context)!.add
                  : AppLocalizations.of(context)!.save,
              style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
            ),
          ),
          SizedBox(height: 16.h), // Safe area bottom padding
        ],
      ),
    );
  }
}
