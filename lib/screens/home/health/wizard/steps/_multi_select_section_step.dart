import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/Business_Logic/Health_page/health_cubit.dart';
import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_cubit.dart';
import 'package:docsera/screens/home/health/models/health_models.dart';
import 'package:docsera/screens/home/health/services/health_records_service.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_manual_entry_sheet.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_multi_select_list.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_no_data_button.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_step_scaffold.dart';

/// Shared step widget for the 4 multi-select sections of the wizard
/// (allergies, conditions, surgeries, family history). Wraps its body in a
/// scoped HealthCubit for the given [category] so existing add/delete
/// helpers Just Work.
class MultiSelectSectionStep extends StatelessWidget {
  final String category;
  final String lottieAssetName;
  final String title;
  final String subtitle;
  final String addCustomLabel;
  final String noDataLabel;

  const MultiSelectSectionStep({
    super.key,
    required this.category,
    required this.lottieAssetName,
    required this.title,
    required this.subtitle,
    required this.addCustomLabel,
    required this.noDataLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Wizard is main-user only in v1 (relatives out of scope per spec §2).
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return BlocProvider(
      create: (_) => HealthCubit(
        category: category,
        service: HealthRecordsService(),
        userId: userId,
        relativeId: null,
      )..loadRecords(),
      child: _Body(
        lottieAssetName: lottieAssetName,
        title: title,
        subtitle: subtitle,
        addCustomLabel: addCustomLabel,
        noDataLabel: noDataLabel,
      ),
    );
  }
}

class _Body extends StatefulWidget {
  final String lottieAssetName;
  final String title;
  final String subtitle;
  final String addCustomLabel;
  final String noDataLabel;

  const _Body({
    required this.lottieAssetName,
    required this.title,
    required this.subtitle,
    required this.addCustomLabel,
    required this.noDataLabel,
  });

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _noTapped = false;
  List<HealthMasterItem> _shortlist = [];
  bool _shortlistLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadShortlist();
  }

  Future<void> _loadShortlist() async {
    final cubit = context.read<HealthCubit>();
    final master = await cubit.searchMaster('');
    if (!mounted) return;
    setState(() {
      _shortlist = master;
      _shortlistLoaded = true;
    });
  }

  Future<void> _onToggle(MultiSelectItem item, bool checked) async {
    final cubit = context.read<HealthCubit>();
    setState(() => _noTapped = false);

    if (checked) {
      // Find master either in existing records or shortlist
      HealthMasterItem? master;
      for (final r in cubit.state.records) {
        if (r.master.id == item.id) {
          master = r.master;
          break;
        }
      }
      master ??= _shortlist.firstWhere(
        (m) => m.id == item.id,
        orElse: () => throw StateError('Master id ${item.id} not found'),
      );
      await cubit.addRecord(
        master: master,
        severity: null,
        startDate: null,
        notes: null,
        isArabicNotes: Directionality.of(context) == TextDirection.rtl,
      );
    } else {
      // Find existing record id and delete (deleteRecord takes patient_medical_records.id)
      String? recordId;
      for (final r in cubit.state.records) {
        if (r.master.id == item.id) {
          recordId = r.id;
          break;
        }
      }
      if (recordId != null) {
        await cubit.deleteRecord(recordId);
      }
    }
  }

  Future<void> _onAddManual() async {
    final result = await showWizardManualEntrySheet(
      context,
      title: widget.title,
    );
    if (result == null) return;
    if (!mounted) return;
    final cubit = context.read<HealthCubit>();
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final master = await cubit.createCustomMasterItem(
      nameEn: result.name,
      nameAr: result.name,
      descriptionEn: isAr ? null : result.description,
      descriptionAr: isAr ? result.description : null,
    );
    await cubit.addRecord(
      master: master,
      severity: null,
      startDate: null,
      notes: null,
      isArabicNotes: isAr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wizard = context.read<HealthProfileWizardCubit>();
    return BlocBuilder<HealthCubit, HealthState>(
      builder: (context, healthState) {
        final isAr = Directionality.of(context) == TextDirection.rtl;
        final loading = healthState.isLoading || !_shortlistLoaded;
        final existing = healthState.records;
        final selectedIds = existing.map((r) => r.master.id).toSet();
        final shortlistFiltered = _shortlist
            .where((m) => !existing.any((r) => r.master.id == m.id))
            .toList();

        final items = <MultiSelectItem>[
          ...existing.map((r) => MultiSelectItem(
                id: r.master.id,
                label: isAr && r.master.nameAr.isNotEmpty
                    ? r.master.nameAr
                    : r.master.nameEn,
                isExisting: true,
              )),
          ...shortlistFiltered.map((m) => MultiSelectItem(
                id: m.id,
                label: isAr && m.nameAr.isNotEmpty ? m.nameAr : m.nameEn,
                isExisting: false,
              )),
        ];

        final anySelected = selectedIds.isNotEmpty;
        final canNext = anySelected || _noTapped;

        return WizardStepScaffold(
          lottieAssetName: widget.lottieAssetName,
          title: widget.title,
          subtitle: widget.subtitle,
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WizardMultiSelectList(
                        items: items,
                        selectedIds: selectedIds,
                        onToggle: _onToggle,
                        onAddManual: _onAddManual,
                        addManualLabel: widget.addCustomLabel,
                      ),
                      SizedBox(height: 16.h),
                      WizardNoDataButton(
                        label: widget.noDataLabel,
                        anySelected: anySelected,
                        onTap: () => setState(() => _noTapped = true),
                      ),
                    ],
                  ),
                ),
          onSkip: () => wizard.skip(),
          onNext: canNext ? () => wizard.next() : null,
          nextEnabled: canNext,
        );
      },
    );
  }
}
