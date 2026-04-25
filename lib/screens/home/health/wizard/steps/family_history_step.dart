import 'package:flutter/material.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import '_multi_select_section_step.dart';

class FamilyHistoryStep extends StatelessWidget {
  const FamilyHistoryStep({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return MultiSelectSectionStep(
      category: 'family_history',
      lottieAssetName: 'family',
      title: t.healthProfile_step_family_title,
      subtitle: t.healthProfile_step_family_subtitle,
      addCustomLabel: t.healthProfile_step_family_addCustom,
      noDataLabel: t.healthProfile_step_family_none,
    );
  }
}
