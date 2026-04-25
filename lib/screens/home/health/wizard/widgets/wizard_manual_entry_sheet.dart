// lib/screens/home/health/wizard/widgets/wizard_manual_entry_sheet.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
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
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mainDark,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: t.health_manual_entry_title,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  TextField(
                    controller: _desc,
                    decoration: InputDecoration(
                      labelText: t.description,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(t.cancel),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.main,
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
                          child: Text(t.save),
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
