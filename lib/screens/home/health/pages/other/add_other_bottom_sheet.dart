import 'package:docsera/screens/home/health/models/health_models.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_manual_entry_form.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_master_search_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_options_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_recap_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_stepper_bottom_sheet.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_year_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

import 'package:docsera/Business_Logic/Health_page/health_cubit.dart';

class AddOtherBottomSheet extends StatefulWidget {
  const AddOtherBottomSheet({super.key});

  @override
  State<AddOtherBottomSheet> createState() => _AddOtherBottomSheetState();
}

class _AddOtherBottomSheetState extends State<AddOtherBottomSheet> {
  int step = 1;

  HealthMasterItem? selectedMaster;
  String? selectedSeverity;
  int? selectedYear;

  bool saving = false;

  /// Whether we're showing the manual entry form instead of search
  bool _showManualForm = false;

  void _next() => setState(() => step++);
  void _back() {
    if (_showManualForm) {
      // Return from manual form back to search
      setState(() => _showManualForm = false);
      return;
    }
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
      severity: selectedSeverity,
      startDate: selectedYear != null ? DateTime(selectedYear!, 1, 1) : null,
      notes: null,
      isArabicNotes: Directionality.of(context) == TextDirection.rtl,
    );

    if (mounted) {
      setState(() => saving = false);
      Navigator.pop(context);
    }
  }

  Future<void> _handleManualSubmit({
    required String name,
    String? description,
  }) async {
    final cubit = context.read<HealthCubit>();
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    try {
      final masterItem = await cubit.createCustomMasterItem(
        nameEn: isArabic ? name : name,
        nameAr: isArabic ? name : name,
        descriptionEn: isArabic ? null : description,
        descriptionAr: isArabic ? description : null,
      );

      setState(() {
        selectedMaster = masterItem;
        _showManualForm = false;
      });
      _next();
    } catch (e) {
      debugPrint("❌ Error creating custom master item: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
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
        t.addAllergy_step1_title,
        t.addAllergy_step2_title,
        t.addAllergy_step3_title,
        t.addAllergy_step4_title,
      ],
      steps: [
        /// STEP 1 — SEARCH MASTER or MANUAL ENTRY FORM
        _showManualForm
            ? HealthManualEntryForm(
                icon: Icons.monitor_heart_rounded,
                onSubmit: ({required name, description}) {
                  _handleManualSubmit(
                    name: name,
                    description: description,
                  );
                },
              )
            : HealthMasterSearchStep<HealthMasterItem>(
                onSearch: (q) => cubit.searchMaster(q),
                getTitle: (item, isAr) =>
                isAr && item.nameAr.isNotEmpty ? item.nameAr : item.nameEn,
                getSubtitle: (item, isAr) =>
                isAr ? (item.descriptionAr ?? "") : (item.descriptionEn ?? ""),
                icon: Icons.monitor_heart_rounded,
                isDisabled: (item) => existingIds.contains(item.id),
                alreadyAddedText: t.already_added,
                emptyResultsText: t.noResults,
                searchValue: t.health_other_title,
                headerText: t.addAllergy_step1_desc,
                onManualEntry: () {
                  setState(() => _showManualForm = true);
                },
                onSelect: (item) {
                  selectedMaster = item;
                  _next();
                },
              ),

        /// STEP 2 — SEVERITY
        HealthOptionsStep<String>(
          title: t.addAllergy_severity_title,
          subtitle: t.addAllergy_severity_desc,
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
          title: t.addAllergy_year_title,
          subtitle: t.addAllergy_year_desc,
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

        /// STEP 4 — RECAP
        HealthRecapStep(
          title: Directionality.of(context) == TextDirection.rtl ? "إضافة معلومات صحية أخرى" : "Add Other Health Info",
          saveText: t.save,
          loading: saving,
          items: [
            RecapItemData(
              title: t.addAllergy_recap_allergy,
              value: selectedMaster == null
                  ? ""
                  : (selectedMaster!.nameAr.isNotEmpty
                  ? selectedMaster!.nameAr
                  : selectedMaster!.nameEn),
            ),
            if (selectedSeverity != null)
              RecapItemData(
                title: t.addAllergy_recap_severity,
                value: {
                  'low': t.low,
                  'medium': t.medium,
                  'high': t.high,
                }[selectedSeverity]!,
              ),
            if (selectedYear != null)
              RecapItemData(
                title: t.addAllergy_recap_year,
                value: selectedYear.toString(),
              ),
          ],
          infoText: t.addAllergy_recap_description,
          onSave: _save,
        ),
      ],
    );
  }
}
