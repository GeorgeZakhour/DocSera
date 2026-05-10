import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/scaffolds/celebration_scaffold.dart';
import '../widgets/scaffolds/feature_scaffold.dart' show MarbleSpec;

class S15EarnPoints extends StatelessWidget {
  const S15EarnPoints({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return CelebrationScaffold(
      orbContent: const _PointsCounter(),
      title: l.wizard_earn_title,
      body: l.wizard_earn_body,
      marbles: const [
        MarbleSpec(topPct: 0.09, startPct: 0.20, sizePx: 16, period: Duration(milliseconds: 5300)),
        MarbleSpec(topPct: 0.14, startPct: 0.18, sizePx: 22, period: Duration(milliseconds: 6400)),
        MarbleSpec(topPct: 0.40, startPct: 0.16, sizePx: 12, period: Duration(milliseconds: 5800), phaseOffset: Duration(milliseconds: 700)),
        MarbleSpec(topPct: 0.46, startPct: 0.18, sizePx: 24, period: Duration(milliseconds: 7100)),
      ],
      sparklePositions: const [
        Offset(0.30, 0.20),
        Offset(0.66, 0.20),
        Offset(0.42, 0.40),
      ],
      sparkleIcon: SvgPicture.asset(
        'assets/images/onboarding/ic_points.svg',
        width: 14.w,
        colorFilter: const ColorFilter.mode(Color(0xFF009092), BlendMode.srcIn),
      ),
    );
  }
}

/// Counter that ticks "+0" → "+25" over 1.4s with easing, then loops with a 3s pause.
class _PointsCounter extends StatefulWidget {
  const _PointsCounter();

  @override
  State<_PointsCounter> createState() => _PointsCounterState();
}

class _PointsCounterState extends State<_PointsCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _ctrl
              ..reset()
              ..forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final n = (Curves.easeOut.transform(_ctrl.value) * 100).round();
        return Text(
          '+$n',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: 48.sp,
            color: const Color(0xFF009092),
            shadows: const [
              Shadow(color: Color(0x4D009092), blurRadius: 14, offset: Offset(0, 6)),
            ],
          ),
        );
      },
    );
  }
}
