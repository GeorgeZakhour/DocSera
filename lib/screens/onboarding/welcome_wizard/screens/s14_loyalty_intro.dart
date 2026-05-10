import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/scaffolds/manifesto_scaffold.dart';
import '../widgets/scaffolds/feature_scaffold.dart' show MarbleSpec;

class S14LoyaltyIntro extends StatelessWidget {
  const S14LoyaltyIntro({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ManifestoScaffold(
      iconTag: Container(
        width: 64.w,
        height: 64.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF009092), Color(0xFF4DD0D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.main.withValues(alpha: .55),
              blurRadius: 26, offset: const Offset(0, 12), spreadRadius: -6,
            ),
          ],
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/images/onboarding/ic_loyalty.svg',
            width: 32.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
      title: l.wizard_loyalty_title,
      body: l.wizard_loyalty_body,
      marbles: const [
        MarbleSpec(topPct: 0.16, startPct: 0.20, sizePx: 22, period: Duration(milliseconds: 5400)),
        MarbleSpec(topPct: 0.20, startPct: 0.42, sizePx: 14, period: Duration(milliseconds: 6800), phaseOffset: Duration(milliseconds: 400)),
        MarbleSpec(topPct: 0.50, startPct: 0.16, sizePx: 18, period: Duration(milliseconds: 5800)),
      ],
    );
  }
}
