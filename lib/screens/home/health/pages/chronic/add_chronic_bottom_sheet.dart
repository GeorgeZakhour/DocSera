import 'package:docsera/Business_Logic/Health_page/health_cubit.dart';
import 'package:docsera/screens/home/health/models/health_models.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_master_search_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_options_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_recap_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_stepper_bottom_sheet.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_year_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class AddChronicBottomSheet extends StatefulWidget {
  const AddChronicBottomSheet({super.key});

  @override
  State<AddChronicBottomSheet> createState() => _AddChronicBottomSheetState();
}

class _AddChronicBottomSheetState extends State<AddChronicBottomSheet> {
  int step = 1;

  HealthMasterItem? selectedMaster;
  String? selectedSeverity;
  int? selectedYear;

  bool saving = false;

  void _next() => setState(() => step++);
  void _back() {
    if (step == 1) Navigator.pop(context);
    else setState(() => step--);
  }

  Future<void> _save() async {
    if (selectedMaster == null) return;

    final cubit = context.read<HealthCubit>();
    setState(() => saving = true);

    await cubit.addRecord(
      master: selectedMaster!,
      severity: selectedSeverity,
      startDate: selectedYear != null ? DateTime(selectedYear!, 1, 1) : null,
      notes: null,
      isArabicNotes: Directionality.of(context) == TextDirection.rtl,
    );

    if (!mounted) return;
    setState(() => saving = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cubit = context.read<HealthCubit>();

    final existing = cubit.state.records.map((e) => e.master.id).toSet();

    return HealthStepperBottomSheet(
      step: step,
      onBack: _back,

      titles: [
        t.addChronic_step1_title,
        t.addChronic_step2_title,
        t.addChronic_step3_title,
        t.addChronic_step4_title,
      ],

      steps: [
        /// STEP 1 — SELECT CHRONIC DISEASE
        HealthMasterSearchStep<HealthMasterItem>(
          onSearch: (q) => cubit.searchMaster(q),
          getTitle: (item, isAr) =>
          isAr ? (item.nameAr.isNotEmpty ? item.nameAr : item.nameEn) : item.nameEn,
          getSubtitle: (item, isAr) =>
          isAr ? (item.descriptionAr ?? "") : (item.descriptionEn ?? ""),
          icon: Icons.favorite_rounded,
          isDisabled: (item) => existing.contains(item.id),
          alreadyAddedText: t.chronic_already_added,
          emptyResultsText: t.noResults,
          searchValue: t.health_chronic_title,
          headerText: t.addChronic_step1_desc,
          onSelect: (item) {
            selectedMaster = item;
            _next();
          },
        ),

        /// STEP 2 — SEVERITY LEVEL
        HealthOptionsStep<String>(
          title: t.addChronic_severity_title,
          subtitle: t.addChronic_severity_desc,
          options: {
            'low': t.low,
            'medium': t.medium,
            'high': t.high,
          },
          selected: selectedSeverity,
          onSelect: (v) => setState(() => selectedSeverity = v),
          nextText: t.next,
          skippable: true,
          skipText: t.skip,
          onSkip: () {
            selectedSeverity = null;
            _next();
          },
          onNext: _next,
        ),

        /// STEP 3 — YEAR
        HealthYearStep(
          title: t.addChronic_year_title,
          subtitle: t.addChronic_year_desc,
          years: List.generate(60, (i) => DateTime.now().year - i),
          selectedYear: selectedYear,
          onChanged: (v) => setState(() => selectedYear = v),
          skippable: true,
          skipText: t.skip,
          nextText: t.next,
          onSkip: () {
            selectedYear = null;
            _next();
          },
          onNext: _next,
        ),

        /// STEP 4 — RECAP
        HealthRecapStep(
          title: t.addChronic_recap_title,
          saveText: t.save,
          loading: saving,
          items: [
            RecapItemData(
              title: t.chronic_name,
              value: selectedMaster == null
                  ? ""
                  : (selectedMaster!.nameAr.isNotEmpty
                  ? selectedMaster!.nameAr
                  : selectedMaster!.nameEn),
            ),
            if (selectedSeverity != null)
              RecapItemData(
                title: t.addChronic_recap_severity,
                value: {
                  'low': t.low,
                  'medium': t.medium,
                  'high': t.high,
                }[selectedSeverity]!,
              ),
            if (selectedYear != null)
              RecapItemData(
                title: t.year,
                value: selectedYear.toString(),
              ),
          ],
          infoText: t.addChronic_recap_description,
          onSave: _save,
        ),
      ],
    );
  }
}
