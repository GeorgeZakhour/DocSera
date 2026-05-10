import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/scaffolds/celebration_scaffold.dart';
import '../widgets/scaffolds/feature_scaffold.dart' show MarbleSpec;

class S05Promotions extends StatelessWidget {
  const S05Promotions({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return CelebrationScaffold(
      orbContent: SvgPicture.asset(
        'assets/images/onboarding/ic_promo.svg',
        width: 100.w,
        colorFilter: const ColorFilter.mode(Color(0xFF009092), BlendMode.srcIn),
      ),
      title: l.wizard_promotions_title,
      body: l.wizard_promotions_body,
      // Unique to screen 05
      marbles: const [
        MarbleSpec(topPct: 0.08, startPct: 0.18, sizePx: 14, period: Duration(milliseconds: 5200)),
        MarbleSpec(topPct: 0.13, startPct: 0.72, sizePx: 24, period: Duration(milliseconds: 6300)),
        MarbleSpec(topPct: 0.36, startPct: 0.18, sizePx: 18, period: Duration(milliseconds: 5700), phaseOffset: Duration(milliseconds: 600)),
        MarbleSpec(topPct: 0.42, startPct: 0.74, sizePx: 28, period: Duration(milliseconds: 7200)),
      ],
      sparklePositions: const [
        Offset(0.28, 0.20),
        Offset(0.68, 0.18),
        Offset(0.40, 0.42),
      ],
      sparkleIcon: SvgPicture.asset(
        'assets/images/onboarding/ic_points.svg',
        width: 14.w,
        colorFilter: const ColorFilter.mode(Color(0xFF009092), BlendMode.srcIn),
      ),
    );
  }
}
