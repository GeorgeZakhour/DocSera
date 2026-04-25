import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/Business_Logic/Health_page/health_cubit.dart';
import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_cubit.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/models/health_models.dart';
import 'package:docsera/screens/home/health/services/health_records_service.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_manual_entry_sheet.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_multi_select_list.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_no_data_button.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_search_field.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_step_scaffold.dart';

/// Shared step widget for the multi-select sections of the wizard.
/// Provides a scoped HealthCubit for [category], an inline search field,
/// and snapshot tracking so newly-checked items don't get tagged
/// "Already in your profile" — only items present at wizard entry do.
///
/// When [searchOnly] is true, no master shortlist is loaded on init;
/// items only appear once the user types something. Used by Medications
/// because the medication catalog is too large to enumerate.
class MultiSelectSectionStep extends StatelessWidget {
  final String category;
  final String lottieAssetName;
  final String title;
  final String subtitle;
  final String addCustomLabel;
  final String noDataLabel;
  final bool searchOnly;

  const MultiSelectSectionStep({
    super.key,
    required this.category,
    required this.lottieAssetName,
    required this.title,
    required this.subtitle,
    required this.addCustomLabel,
    required this.noDataLabel,
    this.searchOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    // Wizard is main-user only in v1.
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
        searchOnly: searchOnly,
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
  final bool searchOnly;

  const _Body({
    required this.lottieAssetName,
    required this.title,
    required this.subtitle,
    required this.addCustomLabel,
    required this.noDataLabel,
    required this.searchOnly,
  });

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _noTapped = false;

  // Default shortlist (loaded once unless searchOnly).
  List<HealthMasterItem> _shortlist = [];
  bool _shortlistLoaded = false;

  // Snapshot of records that existed at wizard step entry. Items added
  // during this session are NOT in this set, so they won't get the
  // "Already in your profile" tag.
  Set<String> _initiallyExistingIds = {};
  bool _snapshotTaken = false;

  // Search.
  String _query = '';
  List<HealthMasterItem> _searchResults = [];
  bool _searching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    if (!widget.searchOnly) {
      _loadShortlist();
    } else {
      _shortlistLoaded = true;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
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

  void _onQueryChanged(String q) {
    _searchDebounce?.cancel();
    final trimmed = q.trim();
    setState(() {
      _query = q;
    });
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 280), () async {
      final cubit = context.read<HealthCubit>();
      final r = await cubit.searchMaster(trimmed);
      if (!mounted) return;
      setState(() {
        _searchResults = r;
        _searching = false;
      });
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
      master ??= _shortlist.firstWhere(
        (m) => m.id == item.id,
        orElse: () => _searchResults.firstWhere(
          (m) => m.id == item.id,
          orElse: () => throw StateError('Master id ${item.id} not found'),
        ),
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
    final t = AppLocalizations.of(context)!;
    final wizard = context.read<HealthProfileWizardCubit>();
    return BlocBuilder<HealthCubit, HealthState>(
      builder: (context, healthState) {
        // Capture initial snapshot the first time records finish loading.
        if (!_snapshotTaken && !healthState.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _snapshotTaken) return;
            setState(() {
              _initiallyExistingIds =
                  healthState.records.map((r) => r.master.id).toSet();
              _snapshotTaken = true;
            });
          });
        }

        final isAr = Directionality.of(context) == TextDirection.rtl;
        final loading = healthState.isLoading || !_shortlistLoaded;
        final existing = healthState.records;
        final selectedIds = existing.map((r) => r.master.id).toSet();

        // Source list: search results when querying, else the shortlist.
        // (When searchOnly + empty query, this is empty.)
        final hasQuery = _query.trim().isNotEmpty;
        final sourceList = hasQuery ? _searchResults : _shortlist;
        final sourceFiltered = sourceList
            .where((m) => !existing.any((r) => r.master.id == m.id))
            .toList();

        final items = <MultiSelectItem>[
          ...existing.map((r) => MultiSelectItem(
                id: r.master.id,
                label: isAr && r.master.nameAr.isNotEmpty
                    ? r.master.nameAr
                    : r.master.nameEn,
                isExisting: _initiallyExistingIds.contains(r.master.id),
              )),
          ...sourceFiltered.map((m) => MultiSelectItem(
                id: m.id,
                label: isAr && m.nameAr.isNotEmpty ? m.nameAr : m.nameEn,
                isExisting: false,
              )),
        ];

        final anySelected = selectedIds.isNotEmpty;
        final canNext = anySelected || _noTapped;
        final showEmptySearchHint = widget.searchOnly && !hasQuery && existing.isEmpty;

        return WizardStepScaffold(
          lottieAssetName: widget.lottieAssetName,
          title: widget.title,
          subtitle: widget.subtitle,
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WizardSearchField(
                      onChanged: _onQueryChanged,
                      hint: t.healthProfile_search_hint,
                    ),
                    SizedBox(height: 14.h),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_searching)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                child: const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                            else if (showEmptySearchHint && items.isEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                child: Center(
                                  child: Text(
                                    t.healthProfile_search_hint,
                                    style: TextStyle(
                                      color: AppColors.grayMain,
                                      fontSize: 12.5.sp,
                                    ),
                                  ),
                                ),
                              )
                            else if (hasQuery && items.isEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                child: Center(
                                  child: Text(
                                    t.healthProfile_search_no_results,
                                    style: TextStyle(
                                      color: AppColors.grayMain,
                                      fontSize: 12.5.sp,
                                    ),
                                  ),
                                ),
                              )
                            else
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
                              confirmed: _noTapped,
                              onTap: () => setState(() => _noTapped = true),
                              onChange: () =>
                                  setState(() => _noTapped = false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          onSkip: () => wizard.skip(),
          onNext: canNext ? () => wizard.next() : null,
          nextEnabled: canNext,
        );
      },
    );
  }
}
