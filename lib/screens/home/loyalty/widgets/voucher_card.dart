import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/voucher_model.dart';
import 'package:intl/intl.dart';

class VoucherCard extends StatelessWidget {
  final VoucherModel voucher;
  final VoidCallback onTap;

  const VoucherCard({super.key, required this.voucher, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final statusColor = voucher.isActive ? AppColors.main : voucher.isUsed ? Colors.green : Colors.grey;

    String expiresText;
    try {
      final expires = DateTime.parse(voucher.expiresAt).toLocal();
      final diff = expires.difference(DateTime.now());
      if (voucher.isActive && diff.isNegative) {
        expiresText = 'Expired';
      } else if (voucher.isActive) {
        expiresText = '${diff.inDays}d ${diff.inHours % 24}h left';
      } else {
        expiresText = DateFormat('dd/MM/yyyy').format(expires);
      }
    } catch (_) {
      expiresText = '—';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: statusColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 3, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                voucher.isActive ? Icons.confirmation_number : voucher.isUsed ? Icons.check_circle : Icons.timer_off,
                color: statusColor,
                size: 22.sp,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voucher.getLocalizedTitle(locale),
                    style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    voucher.code,
                    style: TextStyle(fontSize: 13.sp, color: statusColor, fontWeight: FontWeight.w600, letterSpacing: 1.5),
                  ),
                  SizedBox(height: 2.h),
                  Text(expiresText, style: AppTextStyles.getText3(context).copyWith(color: Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14.sp, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
