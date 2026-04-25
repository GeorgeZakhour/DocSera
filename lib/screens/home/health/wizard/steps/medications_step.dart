import 'package:flutter/material.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import '_multi_select_section_step.dart';

/// Medications wizard step. Uses the shared multi-select section step
/// with `searchOnly: true` because the medication catalog is too large
/// to enumerate as an initial shortlist.
class MedicationsStep extends StatelessWidget {
  const MedicationsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return MultiSelectSectionStep(
      category: 'medication',
      lottieAssetName: 'medications',
      title: t.healthProfile_step_medications_title,
      subtitle: t.healthProfile_step_medications_subtitle,
      addCustomLabel: t.healthProfile_step_medications_addCustom,
      noDataLabel: t.healthProfile_step_medications_none,
      searchOnly: true,
    );
  }
}
