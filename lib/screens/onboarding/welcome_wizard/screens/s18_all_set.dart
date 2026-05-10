import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/glass_title.dart';
import '../widgets/scaffolds/feature_scaffold.dart' show MarbleSpec;
import '../widgets/scaffolds/showcase_scaffold.dart';

class S18AllSet extends StatelessWidget {
  final String firstName;
  const S18AllSet({super.key, required this.firstName});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ShowcaseScaffold(
      orbContent: SvgPicture.asset(
        'assets/images/docsera_main.svg',
        width: 80.w,
      ),
      title: GlassTitle(
        text: l.wizard_allset_title(firstName),
        size: 32,
        textAlign: TextAlign.center,
      ),
      tagline: l.wizard_allset_body,
      marbles: const [
        MarbleSpec(topPct: 0.12, startPct: 0.20, sizePx: 16, period: Duration(milliseconds: 5500)),
        MarbleSpec(topPct: 0.22, startPct: 0.65, sizePx: 26, period: Duration(milliseconds: 6500)),
        MarbleSpec(topPct: 0.42, startPct: 0.16, sizePx: 12, period: Duration(milliseconds: 5800), phaseOffset: Duration(milliseconds: 700)),
        MarbleSpec(topPct: 0.46, startPct: 0.72, sizePx: 22, period: Duration(milliseconds: 7100)),
      ],
    );
  }
}
