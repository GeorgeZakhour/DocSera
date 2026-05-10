import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/scaffolds/celebration_scaffold.dart';
import '../widgets/scaffolds/feature_scaffold.dart' show MarbleSpec;

class S06PersonalGifts extends StatelessWidget {
  const S06PersonalGifts({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return CelebrationScaffold(
      orbContent: SvgPicture.asset(
        'assets/images/onboarding/ic_gift.svg',
        width: 110.w,
      ),
      title: l.wizard_gifts_title,
      body: l.wizard_gifts_body,
      // Unique to screen 06 — different from screen 05
      marbles: const [
        MarbleSpec(topPct: 0.10, startPct: 0.22, sizePx: 16, period: Duration(milliseconds: 5400)),
        MarbleSpec(topPct: 0.16, startPct: 0.18, sizePx: 26, period: Duration(milliseconds: 6500)),
        MarbleSpec(topPct: 0.38, startPct: 0.12, sizePx: 12, period: Duration(milliseconds: 5800), phaseOffset: Duration(milliseconds: 700)),
        MarbleSpec(topPct: 0.44, startPct: 0.16, sizePx: 22, period: Duration(milliseconds: 7100)),
      ],
      sparklePositions: const [
        Offset(0.32, 0.18),
        Offset(0.65, 0.22),
        Offset(0.36, 0.38),
      ],
      sparkleIcon: SvgPicture.asset(
        'assets/images/onboarding/ic_points.svg',
        width: 14.w,
        colorFilter: const ColorFilter.mode(Color(0xFF009092), BlendMode.srcIn),
      ),
    );
  }
}
