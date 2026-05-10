import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/scaffolds/feature_scaffold.dart';

class S09VisitReports extends StatelessWidget {
  final int stepIndex;
  final int total;
  const S09VisitReports({super.key, required this.stepIndex, required this.total});

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
            'assets/images/onboarding/ic_report.svg',
            width: 32.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
      stepTagText: l.wizard_step_label('${stepIndex + 1}', '$total'),
      title: l.wizard_reports_title,
      body: l.wizard_reports_body,
      marbles: const [
        MarbleSpec(topPct: 0.12, startPct: 0.15, sizePx: 30, period: Duration(milliseconds: 5400)),
        MarbleSpec(topPct: 0.32, startPct: 0.66, sizePx: 14, period: Duration(milliseconds: 6900)),
        MarbleSpec(topPct: 0.40, startPct: 0.20, sizePx: 22, period: Duration(milliseconds: 5100), phaseOffset: Duration(milliseconds: 700)),
        MarbleSpec(topPct: 0.07, startPct: 0.50, sizePx: 18, period: Duration(milliseconds: 7500)),
      ],
      capsule: const CapsuleSpec(
        topPct: 0.22,
        startPct: 0.28,
        widthPx: 122,
        heightPx: 44,
        rotation: -0.20,
      ),
    );
  }
}
