import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/Business_Logic/Health_page/health_cubit.dart';
import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_cubit.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/models/health_models.dart';
import 'package:docsera/screens/home/health/services/health_records_service.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_manual_entry_sheet.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_multi_select_list.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_no_data_button.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_step_scaffold.dart';

/// Medications wizard step. Unlike the other multi-select sections, this one
/// has no master shortlist — the catalog is too large to enumerate. The user
/// must search to find an item, or use the manual-entry sheet.
class MedicationsStep extends StatelessWidget {
  const MedicationsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return BlocProvider(
      create: (_) => HealthCubit(
        category: 'medication',
        service: HealthRecordsService(),
        userId: userId,
        relativeId: null,
      )..loadRecords(),
      child: const _Body(),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body();
  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _noTapped = false;
  String _query = '';
  List<HealthMasterItem> _searchResults = [];
  bool _searching = false;

  Future<void> _runSearch(String q) async {
    final cubit = context.read<HealthCubit>();
    setState(() {
      _query = q;
      _searching = true;
    });
    final r = await cubit.searchMaster(q);
    if (!mounted) return;
    setState(() {
      _searchResults = r;
      _searching = false;
    });
  }

  Future<void> _onToggle(MultiSelectItem item, bool checked) async {
    final cubit = context.read<HealthCubit>();
    setState(() => _noTapped = false);

    if (checked) {
      HealthMasterItem? master;
      for (final r in cubit.state.records) {
        if (r.master.id == item.id) {
          master = r.master;
          break;
        }
      }
      master ??= _searchResults.firstWhere(
        (m) => m.id == item.id,
        orElse: () =>
            throw StateError('Master id ${item.id} not found in search results'),
      );
      await cubit.addRecord(
        master: master,
        severity: null,
        startDate: null,
        notes: null,
        isArabicNotes: Directionality.of(context) == TextDirection.rtl,
      );
    } else {
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
    final t = AppLocalizations.of(context)!;
    final result = await showWizardManualEntrySheet(
      context,
      title: t.healthProfile_step_medications_title,
    );
    if (result == null || !mounted) return;
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
    final t = AppLocalizations.of(context)!;
    final wizard = context.read<HealthProfileWizardCubit>();
    return BlocBuilder<HealthCubit, HealthState>(
      builder: (context, healthState) {
        final isAr = Directionality.of(context) == TextDirection.rtl;
        final loading = healthState.isLoading;
        final existing = healthState.records;
        final selectedIds = existing.map((r) => r.master.id).toSet();

        // Items: existing first (always), then search results filtered to
        // exclude items already in `existing`.
        final items = <MultiSelectItem>[
          ...existing.map((r) => MultiSelectItem(
                id: r.master.id,
                label: isAr && r.master.nameAr.isNotEmpty
                    ? r.master.nameAr
                    : r.master.nameEn,
                isExisting: true,
              )),
          if (_query.isNotEmpty)
            ..._searchResults
                .where((m) => !existing.any((r) => r.master.id == m.id))
                .map((m) => MultiSelectItem(
                      id: m.id,
                      label: isAr && m.nameAr.isNotEmpty
                          ? m.nameAr
                          : m.nameEn,
                      isExisting: false,
                    )),
        ];

        final anySelected = selectedIds.isNotEmpty;
        final canNext = anySelected || _noTapped;

        return WizardStepScaffold(
          lottieAssetName: 'medications',
          title: t.healthProfile_step_medications_title,
          subtitle: t.healthProfile_step_medications_subtitle,
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        onChanged: _runSearch,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText:
                              t.healthProfile_step_medications_subtitle,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      if (_searching)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (items.isNotEmpty)
                        WizardMultiSelectList(
                          items: items,
                          selectedIds: selectedIds,
                          onToggle: _onToggle,
                          onAddManual: _onAddManual,
                          addManualLabel:
                              t.healthProfile_step_medications_addCustom,
                        ),
                      SizedBox(height: 16.h),
                      WizardNoDataButton(
                        label: t.healthProfile_step_medications_none,
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
