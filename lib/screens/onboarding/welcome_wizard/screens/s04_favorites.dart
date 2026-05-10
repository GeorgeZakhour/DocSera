import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/scaffolds/feature_scaffold.dart';

class S04Favorites extends StatelessWidget {
  final int stepIndex;
  final int total;
  const S04Favorites({super.key, required this.stepIndex, required this.total});

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
            'assets/images/onboarding/ic_heart.svg',
            width: 32.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
      stepTagText: l.wizard_step_label('${stepIndex + 1}', '$total'),
      title: l.wizard_favorites_title,
      body: l.wizard_favorites_body,
      // Unique to screen 04 — different sizes/positions than screens 03 and 05.
      marbles: const [
        MarbleSpec(topPct: 0.15, startPct: 0.13, sizePx: 22, period: Duration(milliseconds: 4800)),
        MarbleSpec(topPct: 0.10, startPct: 0.50, sizePx: 16, period: Duration(milliseconds: 6800), phaseOffset: Duration(milliseconds: 300)),
        MarbleSpec(topPct: 0.32, startPct: 0.74, sizePx: 30, period: Duration(milliseconds: 5200)),
        MarbleSpec(topPct: 0.40, startPct: 0.16, sizePx: 18, period: Duration(milliseconds: 6100), phaseOffset: Duration(milliseconds: 1200)),
      ],
      capsule: const CapsuleSpec(
        topPct: 0.20,
        startPct: 0.32,
        widthPx: 124,
        heightPx: 42,
        rotation: -0.24,
      ),
    );
  }
}
