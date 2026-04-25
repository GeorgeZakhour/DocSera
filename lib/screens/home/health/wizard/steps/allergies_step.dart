import 'package:flutter/material.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import '_multi_select_section_step.dart';

class AllergiesStep extends StatelessWidget {
  const AllergiesStep({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return MultiSelectSectionStep(
      category: 'allergy',
      lottieAssetName: 'allergies',
      title: t.healthProfile_step_allergies_title,
      subtitle: t.healthProfile_step_allergies_subtitle,
      addCustomLabel: t.healthProfile_step_allergies_addCustom,
      noDataLabel: t.healthProfile_step_allergies_none,
    );
  }
}
