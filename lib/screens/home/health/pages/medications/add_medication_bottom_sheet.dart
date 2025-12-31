
import 'package:docsera/Business_Logic/Health_page/health_cubit.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/models/health_models.dart';
import 'package:docsera/screens/home/health/services/health_records_service.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_master_search_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_medication_date_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_medication_dosage_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_recap_step.dart';
import 'package:docsera/screens/home/health/widgets/steps/health_stepper_bottom_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


/// ===============================================================
/// ADD MEDICATION BOTTOM SHEET
/// ===============================================================
class AddMedicationBottomSheet extends StatefulWidget {
  const AddMedicationBottomSheet({super.key});

  @override
  State<AddMedicationBottomSheet> createState() =>
      _AddMedicationBottomSheetState();
}

class _AddMedicationBottomSheetState extends State<AddMedicationBottomSheet> {
  int _step = 1;

  HealthMasterItem? _selectedMedication;
  DateTime? _startDate;
  String? _dosage;

  bool _loadingSave = false;

  // ------------------------------
  // BACK BUTTON HANDLER
  // ------------------------------
  void _back() {
    if (_step == 1) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  // ------------------------------
  // SAVE MEDICATION RECORD
  // ------------------------------
  Future<void> _saveRecord() async {
    final t = AppLocalizations.of(context)!;
    final cubit = context.read<HealthCubit>();

    if (_selectedMedication == null) return;

    setState(() => _loadingSave = true);

    await cubit.addRecord(
      master: _selectedMedication!, // نمرر الـ master نفسه
      startDate: _startDate,
      severity: null,

      // notes يجب أن تكون String؟ وليس Map
      notes: _dosage != null && _dosage!.isNotEmpty
          ? _dosage
          : null,

      // خطوة ضرورية جداً
      isArabicNotes: Directionality.of(context) == TextDirection.rtl,
    );


    setState(() => _loadingSave = false);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return HealthStepperBottomSheet(
      step: _step,
      onBack: _back,

      titles: [
        t.medications_add_title,
        t.medications_step2_title,
        t.medications_step3_title,
        t.medications_recap_title,
      ],

      steps: [
        // --------------------------------------------------------
        // STEP 1 — SEARCH MEDICATION
        // --------------------------------------------------------
        HealthMasterSearchStep<HealthMasterItem>(
          onSearch: (q) =>
              HealthRecordsService().searchMaster("medication", q),
          getTitle: (item, isAr) => isAr ? item.nameAr : item.nameEn,
          getSubtitle: (item, isAr) =>
          isAr ? (item.descriptionAr ?? "") : (item.descriptionEn ?? ""),
          icon: Icons.medication_rounded,
          isDisabled: (_) => false,
          onSelect: (item) {
            _selectedMedication = item;
            setState(() => _step = 2);
          },
          emptyResultsText: t.medications_no_results,
          alreadyAddedText: "",
          searchValue: t.medications_search_value,
          headerText: t.medications_search_header,
        ),

        // --------------------------------------------------------
        // STEP 2 — FULL DATE PICKER
        // --------------------------------------------------------
        MedicationDateStep(
          selectedDate: _startDate,
          onChanged: (date) {
            setState(() {
              _startDate = date;
            });
          },
          onNext: () {
            if (_startDate == null) return;
            setState(() => _step = 3);
          },
        ),

        // --------------------------------------------------------
        // STEP 3 — DOSAGE & FREQUENCY
        // --------------------------------------------------------
        MedicationDosageStep(
          dosage: _dosage,
          onChanged: (txt) => _dosage = txt,
          onNext: () => setState(() => _step = 4),
        ),

        // --------------------------------------------------------
        // STEP 4 — RECAP
        // --------------------------------------------------------
        HealthRecapStep(
          title: t.medications_recap_title,
          saveText: t.save,
          loading: _loadingSave,
          onSave: _saveRecord,
          items: [
            RecapItemData(
              title: t.medications_name,
              value: _selectedMedication != null
                  ? (Directionality.of(context) == TextDirection.rtl
                  ? _selectedMedication!.nameAr
                  : _selectedMedication!.nameEn)
                  : "",
            ),
            RecapItemData(
              title: t.medications_start_date,
              value: _startDate != null
                  ? "${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}"
                  : t.notProvided,
            ),
            RecapItemData(
              title: t.medications_dosage_title,
              value: _dosage?.trim().isNotEmpty == true
                  ? _dosage!
                  : t.notProvided,
            ),
          ],
        ),
      ],
    );
  }
}

