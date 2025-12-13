import 'dart:ui';

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ClosedBanner extends StatelessWidget {
  final String doctorName;

  const ClosedBanner({
    Key? key,
    required this.doctorName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          color: AppColors.main.withOpacity(0.5),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline,
                size: 18,
                color: Colors.black54,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  local.conversationClosedByDoctor(doctorName),
                  style: AppTextStyles.getText2(context).copyWith(
                    fontSize: 11.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
