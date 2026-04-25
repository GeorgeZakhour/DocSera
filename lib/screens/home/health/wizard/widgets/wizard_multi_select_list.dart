import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class MultiSelectItem {
  final String id;
  final String label;
  final bool isExisting; // true => already in patient_medical_records

  const MultiSelectItem({
    required this.id,
    required this.label,
    required this.isExisting,
  });
}

/// Multi-select list rendering items with checkbox rows + a trailing
/// "+ Add manual entry" affordance. Existing-records-first ordering is
/// the caller's responsibility — pass them at the top of [items].
///
/// Optional [onEditChecked] surfaces a small pencil icon next to checked
/// items, letting the user add optional details (severity / year) after
/// the fact without leaving the wizard step.
class WizardMultiSelectList extends StatelessWidget {
  final List<MultiSelectItem> items;
  final Set<String> selectedIds;
  final void Function(MultiSelectItem item, bool checked) onToggle;
  final VoidCallback onAddManual;
  final String addManualLabel;
  final void Function(MultiSelectItem item)? onEditChecked;

  const WizardMultiSelectList({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.onToggle,
    required this.onAddManual,
    required this.addManualLabel,
    this.onEditChecked,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.main.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++)
            _Row(
              item: items[i],
              checked: selectedIds.contains(items[i].id),
              isLast: i == items.length - 1,
              onChanged: (v) => onToggle(items[i], v),
              alreadyTag: t.healthProfile_already_in_profile,
              onEdit: onEditChecked == null
                  ? null
                  : () => onEditChecked!(items[i]),
            ),
          InkWell(
            onTap: onAddManual,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              child: Row(
                children: [
                  Icon(Icons.add, color: AppColors.main, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    addManualLabel,
                    style: AppTextStyles.getText1(context).copyWith(
                      color: AppColors.main,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final MultiSelectItem item;
  final bool checked;
  final bool isLast;
  final ValueChanged<bool> onChanged;
  final String alreadyTag;
  final VoidCallback? onEdit;
  const _Row({
    required this.item,
    required this.checked,
    required this.isLast,
    required this.onChanged,
    required this.alreadyTag,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!checked);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: checked ? AppColors.main.withValues(alpha: 0.06) : null,
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: AppColors.main.withValues(alpha: 0.10),
                  ),
                ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.main,
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: AppTextStyles.getText1(context).copyWith(
                      color: AppColors.mainDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.isExisting)
                    Padding(
                      padding: EdgeInsets.only(top: 2.h),
                      child: Text(
                        alreadyTag,
                        style: AppTextStyles.getText3(context).copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppColors.mainDark.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (checked && onEdit != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onEdit,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(6.w),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 16.sp,
                      color: AppColors.main,
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
