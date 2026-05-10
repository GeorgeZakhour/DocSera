import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/scaffolds/celebration_scaffold.dart';
import '../widgets/scaffolds/feature_scaffold.dart' show MarbleSpec;

class S16Vouchers extends StatelessWidget {
  const S16Vouchers({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return CelebrationScaffold(
      orbContent: SvgPicture.asset(
        'assets/images/onboarding/ic_qr.svg',
        width: 110.w,
        colorFilter: const ColorFilter.mode(Color(0xFF009092), BlendMode.srcIn),
      ),
      title: l.wizard_vouchers_title,
      body: l.wizard_vouchers_body,
      // Unique to screen 16 — different from screen 15
      marbles: const [
        MarbleSpec(topPct: 0.11, startPct: 0.16, sizePx: 18, period: Duration(milliseconds: 5500)),
        MarbleSpec(topPct: 0.16, startPct: 0.72, sizePx: 26, period: Duration(milliseconds: 6300)),
        MarbleSpec(topPct: 0.38, startPct: 0.74, sizePx: 16, period: Duration(milliseconds: 5900), phaseOffset: Duration(milliseconds: 600)),
        MarbleSpec(topPct: 0.42, startPct: 0.14, sizePx: 22, period: Duration(milliseconds: 6700)),
      ],
      sparklePositions: const [
        Offset(0.34, 0.18),
        Offset(0.62, 0.20),
        Offset(0.30, 0.40),
      ],
      sparkleIcon: SvgPicture.asset(
        'assets/images/onboarding/ic_points.svg',
        width: 12.w,
        colorFilter: const ColorFilter.mode(Color(0xFF009092), BlendMode.srcIn),
      ),
    );
  }
}
