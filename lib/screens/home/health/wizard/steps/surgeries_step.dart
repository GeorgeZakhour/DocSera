import 'package:flutter/material.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import '_multi_select_section_step.dart';

class SurgeriesStep extends StatelessWidget {
  const SurgeriesStep({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return MultiSelectSectionStep(
      category: 'surgery',
      lottieAssetName: 'surgeries',
      title: t.healthProfile_step_surgeries_title,
      subtitle: t.healthProfile_step_surgeries_subtitle,
      addCustomLabel: t.healthProfile_step_surgeries_addCustom,
      noDataLabel: t.healthProfile_step_surgeries_none,
    );
  }
}
