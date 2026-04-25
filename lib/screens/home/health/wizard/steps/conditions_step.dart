import 'package:flutter/material.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import '_multi_select_section_step.dart';

class ConditionsStep extends StatelessWidget {
  const ConditionsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return MultiSelectSectionStep(
      category: 'chronic_disease',
      lottieAssetName: 'conditions',
      title: t.healthProfile_step_conditions_title,
      subtitle: t.healthProfile_step_conditions_subtitle,
      addCustomLabel: t.healthProfile_step_conditions_addCustom,
      noDataLabel: t.healthProfile_step_conditions_none,
    );
  }
}
