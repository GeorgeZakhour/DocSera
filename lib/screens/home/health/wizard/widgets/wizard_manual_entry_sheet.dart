// lib/screens/home/health/wizard/widgets/wizard_manual_entry_sheet.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

typedef ManualEntryResult = ({String name, String? description});

/// Shows a glassmorphic dialog for manually entering a custom item
/// (allergy / condition / surgery / family condition / medication).
///
/// Returns a `ManualEntryResult` record on save, or null if cancelled.
Future<ManualEntryResult?> showWizardManualEntrySheet(
  BuildContext context, {
  required String title,
}) {
  return showDialog<ManualEntryResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _ManualEntrySheetDialog(title: title),
  );
}

class _ManualEntrySheetDialog extends StatefulWidget {
  final String title;
  const _ManualEntrySheetDialog({required this.title});
  @override
  State<_ManualEntrySheetDialog> createState() =>
      _ManualEntrySheetDialogState();
}

class _ManualEntrySheetDialogState extends State<_ManualEntrySheetDialog> {
  final _name = TextEditingController();
  final _desc = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: AppColors.main.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: AppTextStyles.getTitle2(context).copyWith(
                      color: AppColors.mainDark,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  TextFormField(
                    controller: _name,
                    style: AppTextStyles.getText2(context),
                    decoration: InputDecoration(
                      labelText: t.health_manual_entry_name_label,
                      labelStyle: AppTextStyles.getText2(context).copyWith(
                        color: Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.r),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.r),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.r),
                        borderSide:
                            const BorderSide(color: AppColors.main, width: 2),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  TextFormField(
                    controller: _desc,
                    style: AppTextStyles.getText2(context),
                    decoration: InputDecoration(
                      labelText: t.health_manual_entry_desc_label,
                      labelStyle: AppTextStyles.getText2(context).copyWith(
                        color: Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.r),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.r),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.r),
                        borderSide:
                            const BorderSide(color: AppColors.main, width: 2),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            side: BorderSide(
                              color: AppColors.grayMain.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            t.cancel,
                            style: AppTextStyles.getText2(context).copyWith(
                              color: AppColors.grayMain,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.main,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          onPressed: () {
                            if (_name.text.trim().isEmpty) return;
                            Navigator.pop(
                              context,
                              (
                                name: _name.text.trim(),
                                description: _desc.text.trim().isEmpty
                                    ? null
                                    : _desc.text.trim(),
                              ),
                            );
                          },
                          child: Text(
                            t.save,
                            style: AppTextStyles.getText2(context).copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
