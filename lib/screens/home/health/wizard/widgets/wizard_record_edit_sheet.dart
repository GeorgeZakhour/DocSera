import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/models/health_models.dart';

/// Result of the wizard's optional-details edit sheet.
class WizardRecordEdit {
  /// New severity (one of `'low' | 'medium' | 'high'`) or null to clear.
  final String? severity;

  /// New year (mapped to Jan 1st of that year as `start_date`) or null
  /// to clear.
  final int? year;

  /// True if the user explicitly cleared severity (vs. omitted).
  final bool setSeverity;

  /// True if the user explicitly cleared year (vs. omitted).
  final bool setYear;

  const WizardRecordEdit({
    required this.severity,
    required this.year,
    required this.setSeverity,
    required this.setYear,
  });
}

/// Bottom sheet for adding optional severity + year on a record that
/// was added via the wizard. Shown when the user taps the edit pencil
/// next to a checked item.
Future<WizardRecordEdit?> showWizardRecordEditSheet(
  BuildContext context, {
  required String itemLabel,
  required HealthRecord record,
}) {
  return showModalBottomSheet<WizardRecordEdit>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (sheetCtx) => _Sheet(
      itemLabel: itemLabel,
      record: record,
    ),
  );
}

class _Sheet extends StatefulWidget {
  final String itemLabel;
  final HealthRecord record;
  const _Sheet({required this.itemLabel, required this.record});

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  late String? _severity;
  late int? _year;

  @override
  void initState() {
    super.initState();
    _severity = widget.record.severity;
    _year = widget.record.startDate?.year;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final showSeverity = widget.record.master.severityAllowed;
    final currentYear = DateTime.now().year;
    final years = List.generate(40, (i) => currentYear - i);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.itemLabel,
              style: AppTextStyles.getTitle2(context).copyWith(
                color: AppColors.mainDark,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            Text(
              t.healthProfile_optional_details_subtitle,
              style: AppTextStyles.getText3(context).copyWith(
                color: AppColors.grayMain,
              ),
            ),
            SizedBox(height: 18.h),
            if (showSeverity) ...[
              Text(
                t.severity,
                style: AppTextStyles.getText2(context).copyWith(
                  color: AppColors.mainDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.h),
              _SeverityRow(
                value: _severity,
                onChanged: (v) => setState(() => _severity = v),
                t: t,
              ),
              SizedBox(height: 18.h),
            ],
            Text(
              t.year,
              style: AppTextStyles.getText2(context).copyWith(
                color: AppColors.mainDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8.h),
            _YearChips(
              years: years,
              value: _year,
              onChanged: (v) => setState(() => _year = v),
            ),
            SizedBox(height: 24.h),
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
                      Navigator.pop(
                        context,
                        WizardRecordEdit(
                          severity: _severity,
                          year: _year,
                          setSeverity: showSeverity,
                          setYear: true,
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
    );
  }
}

class _SeverityRow extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final AppLocalizations t;
  const _SeverityRow({
    required this.value,
    required this.onChanged,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final options = <({String code, String label, Color color})>[
      (code: 'low', label: t.severity_mild, color: Colors.green),
      (code: 'medium', label: t.severity_moderate, color: Colors.orange),
      (code: 'high', label: t.severity_severe, color: Colors.red),
    ];
    return Row(
      children: [
        for (int i = 0; i < options.length; i++) ...[
          Expanded(
            child: _SeverityChip(
              option: options[i],
              selected: value == options[i].code,
              onTap: () => onChanged(value == options[i].code ? null : options[i].code),
            ),
          ),
          if (i != options.length - 1) SizedBox(width: 8.w),
        ],
      ],
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final ({String code, String label, Color color}) option;
  final bool selected;
  final VoidCallback onTap;
  const _SeverityChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: selected
              ? option.color.withValues(alpha: 0.14)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? option.color
                : AppColors.grayMain.withValues(alpha: 0.35),
            width: selected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          option.label,
          style: AppTextStyles.getText2(context).copyWith(
            color: selected ? option.color : AppColors.grayMain,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _YearChips extends StatelessWidget {
  final List<int> years;
  final int? value;
  final ValueChanged<int?> onChanged;
  const _YearChips({
    required this.years,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: years.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (_, i) {
          final y = years[i];
          final selected = value == y;
          return InkWell(
            onTap: () => onChanged(selected ? null : y),
            borderRadius: BorderRadius.circular(99),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: selected
                    ? AppColors.main.withValues(alpha: 0.12)
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppColors.main
                      : AppColors.grayMain.withValues(alpha: 0.35),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(
                y.toString(),
                style: AppTextStyles.getText2(context).copyWith(
                  color: selected ? AppColors.mainDark : AppColors.grayMain,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
