import 'package:docsera/Business_Logic/Health_page/health_cubit.dart';
import 'package:docsera/screens/home/health/models/health_models.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_master_search_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_recap_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_stepper_bottom_sheet.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_year_step.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:docsera/gen_l10n/app_localizations.dart';

class AddVaccineBottomSheet extends StatefulWidget {
  const AddVaccineBottomSheet({super.key});

  @override
  State<AddVaccineBottomSheet> createState() => _AddVaccineBottomSheetState();
}

class _AddVaccineBottomSheetState extends State<AddVaccineBottomSheet> {
  int step = 1;

  HealthMasterItem? selectedMaster;
  int? selectedYear;

  bool saving = false;

  void _next() => setState(() => step++);

  void _back() {
    if (step == 1) {
      Navigator.pop(context);
    } else {
      setState(() => step--);
    }
  }

  Future<void> _save() async {
    if (selectedMaster == null) return;

    final cubit = context.read<HealthCubit>();
    setState(() => saving = true);

    await cubit.addRecord(
      master: selectedMaster!,
      severity: null, // اللقاحات لا تستخدم severity
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
        t.addVaccine_step1_title,
        t.addVaccine_step2_title,
        t.addVaccine_step3_title,
      ],

      steps: [
        /// STEP 1 — SELECT VACCINE
        HealthMasterSearchStep<HealthMasterItem>(
          onSearch: (q) => cubit.searchMaster(q),
          getTitle: (item, isAr) =>
          isAr ? (item.nameAr.isNotEmpty ? item.nameAr : item.nameEn) : item.nameEn,
          getSubtitle: (item, isAr) =>
          isAr ? (item.descriptionAr ?? "") : (item.descriptionEn ?? ""),
          icon: Icons.vaccines_rounded,
          isDisabled: (item) => existing.contains(item.id),
          alreadyAddedText: t.already_added,
          emptyResultsText: t.noResults,
          searchValue: t.health_vaccines_title,
          headerText: t.addVaccine_step1_desc,
          onSelect: (item) {
            selectedMaster = item;
            _next();
          },
        ),

        /// STEP 2 — YEAR
        HealthYearStep(
          title: t.addVaccine_step2_title,
          subtitle: t.addVaccine_step2_desc,
          years: List.generate(40, (i) => DateTime.now().year - i),
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

        /// STEP 3 — RECAP
        HealthRecapStep(
          title: t.vaccine_information,
          saveText: t.save,
          loading: saving,
          items: [
            RecapItemData(
              title: t.vaccine_name,
              value: selectedMaster == null
                  ? ""
                  : (selectedMaster!.nameAr.isNotEmpty
                  ? selectedMaster!.nameAr
                  : selectedMaster!.nameEn),
            ),
            if (selectedYear != null)
              RecapItemData(
                title: t.year,
                value: selectedYear.toString(),
              ),
          ],
          infoText: t.addVaccine_recap_description,
          onSave: _save,
        ),
      ],
    );
  }
}
