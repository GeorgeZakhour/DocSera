import 'dart:ui';

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RelativeBanner extends StatelessWidget {
  final String patientName;

  const RelativeBanner({
    Key? key,
    required this.patientName,
  }) : super(key: key);

  bool _isArabicText(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  String _getInitials(String name) {
    final isAr = _isArabicText(name);
    final parts = name.trim().split(' ');
    if (isAr) {
      final firstChar = parts.first.isNotEmpty ? parts.first[0] : '';
      return firstChar == 'ه' ? 'هـ' : firstChar;
    } else {
      final first = parts.isNotEmpty ? parts[0][0] : '';
      final second = parts.length > 1 ? parts[1][0] : '';
      return (first + second).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final isArabic = _isArabicText(patientName);

    final avatar = CircleAvatar(
      radius: 10.r,
      backgroundColor: AppColors.main.withOpacity(0.9),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Transform.translate(
          offset: const Offset(0, -1.5),
          child: Text(
            _getInitials(patientName),
            style: AppTextStyles.getText3(context).copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.whiteText,
              fontSize: 9.sp,
              height: 1.0,
            ),
            textAlign: TextAlign.center,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
          ),
        ),
      ),
    );

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          color: Colors.white10.withOpacity(0.65),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Row(
            children: isArabic
                ? [
              Text(
                '${local.messageForPatient}   ',
                style: AppTextStyles.getText2(context).copyWith(
                  fontSize: 10.sp,
                  color: Colors.black87,
                ),
              ),
              avatar,
              SizedBox(width: 6.w),
              Text(
                patientName,
                style: AppTextStyles.getText2(context).copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(width: 6.w),
            ]
                : [
              avatar,
              SizedBox(width: 6.w),
              Text(
                patientName,
                style: AppTextStyles.getText2(context).copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                local.messageForPatient,
                style: AppTextStyles.getText2(context).copyWith(
                  fontSize: 12.sp,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
