import 'package:docsera/Business_Logic/Health_page/health_cubit.dart';
import 'package:docsera/screens/home/health/models/health_models.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_master_search_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_recap_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_stepper_bottom_sheet.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_year_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class AddSurgeryBottomSheet extends StatefulWidget {
  const AddSurgeryBottomSheet({super.key});

  @override
  State<AddSurgeryBottomSheet> createState() => _AddSurgeryBottomSheetState();
}

class _AddSurgeryBottomSheetState extends State<AddSurgeryBottomSheet> {
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
      severity: null, // الجراحة لا تحتوي على severity
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

    final existingIds = cubit.state.records.map((e) => e.master.id).toSet();

    return HealthStepperBottomSheet(
      step: step,
      onBack: _back,

      titles: [
        t.addSurgery_step1_title,
        t.addSurgery_step2_title,
        t.addSurgery_step3_title,
      ],

      steps: [
        /// STEP 1 — SELECT SURGERY
        HealthMasterSearchStep<HealthMasterItem>(
          onSearch: (q) => cubit.searchMaster(q),
          getTitle: (item, isAr) =>
          isAr && item.nameAr.isNotEmpty ? item.nameAr : item.nameEn,
          getSubtitle: (item, isAr) =>
          isAr ? (item.descriptionAr ?? "") : (item.descriptionEn ?? ""),
          icon: Icons.local_hospital_rounded,
          isDisabled: (item) => existingIds.contains(item.id),
          alreadyAddedText: t.already_added,
          emptyResultsText: t.noResults,
          searchValue: t.health_operations_title,
          headerText: t.addSurgery_step1_desc,
          onSelect: (item) {
            selectedMaster = item;
            _next();
          },
        ),

        /// STEP 2 — YEAR
        HealthYearStep(
          title: t.addSurgery_step2_title,
          subtitle: t.addSurgery_step2_desc,
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

        /// STEP 3 — RECAP
        HealthRecapStep(
          title: t.surgery_information,
          saveText: t.save,
          loading: saving,
          items: [
            RecapItemData(
              title: t.surgery_name,
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
          infoText: t.addSurgery_recap_description,
          onSave: _save,
        ),
      ],
    );
  }
}
