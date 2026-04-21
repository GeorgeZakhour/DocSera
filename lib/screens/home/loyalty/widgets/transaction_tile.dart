import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:intl/intl.dart';

class TransactionTile extends StatelessWidget {
  final int points;
  final String description;
  final String createdAt;
  final bool processed;

  const TransactionTile({
    super.key,
    required this.points,
    required this.description,
    required this.createdAt,
    required this.processed,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = points > 0;
    final color = isPositive ? AppColors.main : Colors.red;
    final icon = isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline;

    String formattedDate;
    try {
      formattedDate = DateFormat('dd/MM/yyyy').format(DateTime.parse(createdAt).toLocal());
    } catch (_) {
      formattedDate = '—';
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Text(formattedDate, style: AppTextStyles.getText3(context).copyWith(color: Colors.grey)),
                    if (!processed) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text('Pending', style: TextStyle(fontSize: 10.sp, color: Colors.orange)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}$points',
            style: AppTextStyles.getTitle1(context).copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
