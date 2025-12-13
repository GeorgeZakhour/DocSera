import 'dart:convert';

import 'package:docsera/Business_Logic/Health_page/health_cubit.dart';
import 'package:docsera/screens/home/health/models/health_models.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_family_member_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_master_search_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_recap_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_stepper_bottom_sheet.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_year_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/what_age_step.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class AddFamilyBottomSheet extends StatefulWidget {
  const AddFamilyBottomSheet({super.key});

  @override
  State<AddFamilyBottomSheet> createState() => _AddFamilyBottomSheetState();
}

class _AddFamilyBottomSheetState extends State<AddFamilyBottomSheet> {
  int step = 1;

  HealthMasterItem? selectedMaster;
  List<String> selectedMembers = [];
  int? diagnosisAge;

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
      severity: null,
      startDate: null,
      notes: jsonEncode({
        "family_members": selectedMembers,
        "diagnosis_age": diagnosisAge,
      }),
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
        t.addFamily_step1_title,
        t.addFamily_step2_title,
        t.addFamily_step3_title,
        t.addFamily_step4_title,
      ],
      steps: [
        /// STEP 1 — SEARCH CONDITION
        HealthMasterSearchStep(
          onSearch: cubit.searchMaster,
          getTitle: (i, isAr) => isAr && i.nameAr.isNotEmpty ? i.nameAr : i.nameEn,
          getSubtitle: (i, isAr) =>
          isAr ? (i.descriptionAr ?? "") : (i.descriptionEn ?? ""),
          icon: Icons.group_rounded,
          isDisabled: (i) => existing.contains(i.id),
          alreadyAddedText: t.already_added,
          emptyResultsText: t.noResults,
          searchValue: t.health_family_title,
          headerText: t.addFamily_step1_desc,
          onSelect: (i) {
            selectedMaster = i;
            _next();
          },
        ),

        /// STEP 2 — SELECT FAMILY MEMBERS
        FamilyMembersStep(
          selected: selectedMembers,
          onChanged: (list) => selectedMembers = list,
          onNext: _next,
        ),

        /// STEP 3 — AGE DIAGNOSIS
        FamilyAgeStep(
          age: diagnosisAge,
          onChanged: (v) => diagnosisAge = v,
          onNext: _next,
        ),

        /// STEP 4 — RECAP
        HealthRecapStep(
          title: t.addFamily_step4_title,
          saveText: t.save,
          loading: saving,
          infoText: t.addFamily_recap_description,
          items: [
            RecapItemData(
              title: t.family_condition,
              value: selectedMaster == null
                  ? ""
                  : (selectedMaster!.nameAr.isNotEmpty
                  ? selectedMaster!.nameAr
                  : selectedMaster!.nameEn),
            ),
            RecapItemData(
              title: t.family_members,
              value: selectedMembers.join(", "),
            ),
            RecapItemData(
              title: t.family_age_at_diagnosis,
              value: diagnosisAge?.toString() ?? t.notProvided,
            ),
          ],
          onSave: _save,
        ),
      ],
    );
  }
}
