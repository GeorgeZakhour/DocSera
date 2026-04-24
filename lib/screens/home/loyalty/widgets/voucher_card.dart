import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/voucher_model.dart';
import 'package:intl/intl.dart';

class VoucherCard extends StatelessWidget {
  final VoucherModel voucher;
  final VoidCallback onTap;
  final int index;

  const VoucherCard({super.key, required this.voucher, required this.onTap, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final statusColor = voucher.isActive
        ? AppColors.main
        : voucher.isUsed
            ? const Color(0xFF4CAF50)
            : Colors.grey;

    String expiresText;
    try {
      final expires = DateTime.parse(voucher.expiresAt).toLocal();
      final diff = expires.difference(DateTime.now());
      if (voucher.isActive && diff.isNegative) {
        expiresText = AppLocalizations.of(context)!.voucherExpired;
      } else if (voucher.isActive) {
        expiresText = AppLocalizations.of(context)!.daysLeft(diff.inDays, diff.inHours % 24);
      } else {
        expiresText = DateFormat('dd/MM/yyyy').format(expires);
      }
    } catch (_) {
      expiresText = '—';
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 24 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: statusColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor.withOpacity(0.15), statusColor.withOpacity(0.06)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(
                    voucher.isActive
                        ? Icons.confirmation_number_rounded
                        : voucher.isUsed
                            ? Icons.check_circle_rounded
                            : Icons.timer_off_rounded,
                    color: statusColor,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 14.w),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voucher.getLocalizedTitle(locale),
                        style: AppTextStyles.getText2(context).copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              voucher.code,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12.sp, color: Colors.grey[400]),
                          SizedBox(width: 4.w),
                          Text(
                            expiresText,
                            style: AppTextStyles.getText3(context).copyWith(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded, size: 12.sp, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
