import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/glass_title.dart';
import '../widgets/scaffolds/feature_scaffold.dart';

class S10Documents extends StatelessWidget {
  final int stepIndex;
  final int total;
  const S10Documents({super.key, required this.stepIndex, required this.total});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return FeatureScaffold(
      heroIcon: Container(
        width: 68.w,
        height: 68.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF009092), Color(0xFF4DD0D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.main.withValues(alpha: .55),
              blurRadius: 26,
              offset: const Offset(0, 14),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/images/onboarding/ic_documents.svg',
            width: 32.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
      stepTagText: l.wizard_step_label('${stepIndex + 1}', '$total'),
      title: l.wizard_documents_title,
      body: l.wizard_documents_body,
      customTitle: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: GlassTitle(text: l.wizard_documents_title, size: 46)),
          SizedBox(width: 8.w),
          Padding(
            padding: EdgeInsets.only(top: 12.h),
            child: _BadgePill(text: l.wizard_documents_badge),
          ),
        ],
      ),
      marbles: const [
        MarbleSpec(topPct: 0.10, startPct: 0.20, sizePx: 26, period: Duration(milliseconds: 5500)),
        MarbleSpec(topPct: 0.30, startPct: 0.70, sizePx: 20, period: Duration(milliseconds: 6300), phaseOffset: Duration(milliseconds: 500)),
        MarbleSpec(topPct: 0.38, startPct: 0.14, sizePx: 30, period: Duration(milliseconds: 5800)),
        MarbleSpec(topPct: 0.13, startPct: 0.42, sizePx: 14, period: Duration(milliseconds: 7100)),
      ],
      capsule: const CapsuleSpec(
        topPct: 0.21,
        startPct: 0.30,
        widthPx: 114,
        heightPx: 46,
        rotation: -0.22,
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final String text;
  const _BadgePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: const Color(0x1A009092), // teal .10
        border: Border.all(color: const Color(0x33009092)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
          fontSize: 9.5.sp,
          letterSpacing: 0.4,
          color: const Color(0xFF007E80),
        ),
      ),
    );
  }
}
