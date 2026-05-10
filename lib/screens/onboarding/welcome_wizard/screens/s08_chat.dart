import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/scaffolds/feature_scaffold.dart';

class S08Chat extends StatelessWidget {
  final int stepIndex;
  final int total;
  const S08Chat({super.key, required this.stepIndex, required this.total});

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
            'assets/images/onboarding/ic_chat.svg',
            width: 32.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
      stepTagText: l.wizard_step_label('${stepIndex + 1}', '$total'),
      title: l.wizard_chat_title,
      body: l.wizard_chat_body,
      // Unique to screen 08
      marbles: const [
        MarbleSpec(topPct: 0.14, startPct: 0.20, sizePx: 22, period: Duration(milliseconds: 4900)),
        MarbleSpec(topPct: 0.09, startPct: 0.62, sizePx: 32, period: Duration(milliseconds: 6400)),
        MarbleSpec(topPct: 0.34, startPct: 0.16, sizePx: 14, period: Duration(milliseconds: 5800), phaseOffset: Duration(milliseconds: 900)),
        MarbleSpec(topPct: 0.40, startPct: 0.74, sizePx: 24, period: Duration(milliseconds: 6900)),
      ],
      capsule: const CapsuleSpec(
        topPct: 0.23,
        startPct: 0.34,
        widthPx: 108,
        heightPx: 42,
        rotation: -0.26,
      ),
    );
  }
}
