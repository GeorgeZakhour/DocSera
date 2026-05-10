import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/scaffolds/feature_scaffold.dart';

class S07Booking extends StatelessWidget {
  final int stepIndex;
  final int total;
  const S07Booking({super.key, required this.stepIndex, required this.total});

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
            'assets/images/onboarding/ic_calendar.svg',
            width: 32.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
      stepTagText: l.wizard_step_label('${stepIndex + 1}', '$total'),
      title: l.wizard_booking_title,
      body: l.wizard_booking_body,
      // Unique to screen 07
      marbles: const [
        MarbleSpec(topPct: 0.11, startPct: 0.14, sizePx: 36, period: Duration(milliseconds: 5300)),
        MarbleSpec(topPct: 0.28, startPct: 0.68, sizePx: 16, period: Duration(milliseconds: 6700), phaseOffset: Duration(milliseconds: 400)),
        MarbleSpec(topPct: 0.36, startPct: 0.14, sizePx: 26, period: Duration(milliseconds: 5600)),
        MarbleSpec(topPct: 0.07, startPct: 0.42, sizePx: 18, period: Duration(milliseconds: 7300), phaseOffset: Duration(seconds: 1)),
      ],
      capsule: const CapsuleSpec(
        topPct: 0.20,
        startPct: 0.26,
        widthPx: 116,
        heightPx: 48,
        rotation: -0.16,
      ),
    );
  }
}
