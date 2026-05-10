import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/scaffolds/feature_scaffold.dart';

class S02Search extends StatelessWidget {
  final int stepIndex;
  final int total;
  const S02Search({super.key, required this.stepIndex, required this.total});

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
            'assets/images/onboarding/ic_search.svg',
            width: 32.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
      stepTagText: l.wizard_step_label('${stepIndex + 1}', '$total'),
      title: l.wizard_search_title,
      body: l.wizard_search_body,
      // Unique marble layout for Screen 02 — different from screens 01, 03.
      marbles: const [
        MarbleSpec(topPct: 0.13, startPct: 0.16, sizePx: 32, period: Duration(milliseconds: 5000)),
        MarbleSpec(topPct: 0.26, startPct: 0.70, sizePx: 18, period: Duration(milliseconds: 6500)),
        MarbleSpec(topPct: 0.33, startPct: 0.12, sizePx: 38, period: Duration(milliseconds: 5500), phaseOffset: Duration(milliseconds: 500)),
        MarbleSpec(topPct: 0.09, startPct: 0.36, sizePx: 14, period: Duration(milliseconds: 7000), phaseOffset: Duration(seconds: 1)),
      ],
      capsule: const CapsuleSpec(
        topPct: 0.21,
        startPct: 0.30,
        widthPx: 110,
        heightPx: 44,
        rotation: -0.21, // -12 deg in radians
      ),
    );
  }
}
