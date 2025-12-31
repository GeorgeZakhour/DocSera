import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class MonthFilterWidget extends StatelessWidget {
  final List<int> months;          // dynamic months list
  final int? selectedMonth;
  final ValueChanged<int?> onMonthChanged;

  const MonthFilterWidget({
    super.key,
    required this.months,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: months.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          if (i == 0) {
            final active = selectedMonth == null;
            return _chip(
              context,
              AppLocalizations.of(context)!.all_label,
              active,
                  () => onMonthChanged(null),
            );
          }

          final month = months[i - 1];
          final active = month == selectedMonth;

          return GestureDetector(
            onTap: () => onMonthChanged(month),
            child: _chip(
              context,
              _localizedMonth(context, month),
              active,
                  () => onMonthChanged(month),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(BuildContext context, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 35,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: active ? AppColors.main.withOpacity(0.25) : Colors.white.withOpacity(0.18),
          border: Border.all(
            color: active ? AppColors.main : AppColors.main.withOpacity(0.2),
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              color: active ? AppColors.mainDark : AppColors.mainDark.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  String _localizedMonth(BuildContext context, int month) {
    final t = AppLocalizations.of(context)!;

    return [
      "",
      t.month_jan,
      t.month_feb,
      t.month_mar,
      t.month_apr,
      t.month_may,
      t.month_jun,
      t.month_jul,
      t.month_aug,
      t.month_sep,
      t.month_oct,
      t.month_nov,
      t.month_dec
    ][month];
  }
}
