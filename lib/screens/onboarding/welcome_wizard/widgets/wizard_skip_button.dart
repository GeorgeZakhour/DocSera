import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class WizardSkipButton extends StatelessWidget {
  final VoidCallback onTap;
  const WizardSkipButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PositionedDirectional(
      top: 22.h,
      start: 22.w,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(8.w),
          child: Text(
            l.wizard_skip_button,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w500,
              fontSize: 12.sp,
              color: const Color(0xA6004146), // teal-near-black .65
            ),
          ),
        ),
      ),
    );
  }
}
