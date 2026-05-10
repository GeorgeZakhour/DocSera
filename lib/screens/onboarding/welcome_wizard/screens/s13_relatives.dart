import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/scaffolds/feature_scaffold.dart';

class S13Relatives extends StatelessWidget {
  final int stepIndex;
  final int total;
  const S13Relatives({super.key, required this.stepIndex, required this.total});

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
            'assets/images/onboarding/ic_family.svg',
            width: 32.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
      stepTagText: l.wizard_step_label('${stepIndex + 1}', '$total'),
      title: l.wizard_relatives_title,
      body: l.wizard_relatives_body,
      marbles: const [
        MarbleSpec(topPct: 0.13, startPct: 0.21, sizePx: 24, period: Duration(milliseconds: 5700)),
        MarbleSpec(topPct: 0.27, startPct: 0.66, sizePx: 16, period: Duration(milliseconds: 6200)),
        MarbleSpec(topPct: 0.36, startPct: 0.18, sizePx: 32, period: Duration(milliseconds: 5300), phaseOffset: Duration(milliseconds: 600)),
        MarbleSpec(topPct: 0.09, startPct: 0.40, sizePx: 12, period: Duration(milliseconds: 7600)),
      ],
      capsule: const CapsuleSpec(
        topPct: 0.21,
        startPct: 0.27,
        widthPx: 116,
        heightPx: 44,
        rotation: -0.18,
      ),
    );
  }
}
