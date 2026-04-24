import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ----------------------------------------------------------------
/// MANUAL ENTRY FORM — Shown inside the stepper bottom sheet
/// when the user taps "Can't find it? Add manually"
///
/// Returns the name and description via `onSubmit`.
/// ----------------------------------------------------------------
class HealthManualEntryForm extends StatefulWidget {
  final IconData icon;
  final void Function({
    required String name,
    String? description,
  }) onSubmit;

  const HealthManualEntryForm({
    super.key,
    required this.icon,
    required this.onSubmit,
  });

  @override
  State<HealthManualEntryForm> createState() => _HealthManualEntryFormState();
}

class _HealthManualEntryFormState extends State<HealthManualEntryForm> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _submitted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8.h),

          /// ICON + TITLE
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.main.withOpacity(0.10),
                ),
                child: Icon(widget.icon, size: 18.sp, color: AppColors.main),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  t.health_manual_entry_title,
                  style: AppTextStyles.getTitle1(context).copyWith(
                    fontSize: 14.sp,
                    color: AppColors.mainDark,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 20.h),

          /// NAME FIELD
          Text(
            t.health_manual_entry_name_label,
            style: AppTextStyles.getText2(context).copyWith(
              fontSize: 11.sp,
              color: AppColors.blackText,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: _inputDecoration(t.health_manual_entry_name_hint),
            validator: (value) {
              if (_submitted && (value == null || value.trim().isEmpty)) {
                return t.health_manual_entry_name_required;
              }
              return null;
            },
          ),

          SizedBox(height: 16.h),

          /// DESCRIPTION FIELD
          Text(
            t.health_manual_entry_desc_label,
            style: AppTextStyles.getText2(context).copyWith(
              fontSize: 11.sp,
              color: AppColors.blackText,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          TextFormField(
            controller: _descController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            decoration: _inputDecoration(t.health_manual_entry_desc_hint),
          ),

          SizedBox(height: 14.h),

          /// DISCLAIMER
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: Colors.amber.withOpacity(0.25),
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16.sp,
                  color: Colors.amber.shade700,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    t.health_manual_entry_disclaimer,
                    style: AppTextStyles.getText3(context).copyWith(
                      fontSize: 10.sp,
                      color: Colors.amber.shade800,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          /// SUBMIT BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.main,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Text(
                t.health_manual_entry_submit,
                style: AppTextStyles.getTitle2(context).copyWith(
                  fontSize: 13.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12.sp, color: AppColors.grayMain),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: AppColors.main, width: 1.4),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
    );
  }

  void _handleSubmit() {
    setState(() => _submitted = true);

    if (!_formKey.currentState!.validate()) return;

    widget.onSubmit(
      name: _nameController.text.trim(),
      description: _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : null,
    );
  }
}
