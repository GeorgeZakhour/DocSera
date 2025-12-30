import 'package:docsera/Business_Logic/Health_page/health_cubit.dart';
import 'package:docsera/Business_Logic/Health_page/patient_switcher_cubit.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/models/health_models.dart';
import 'package:docsera/screens/home/health/pages/allergies/add_allergy_bottom_sheet.dart';
import 'package:docsera/screens/home/health/services/health_records_service.dart';
import 'package:docsera/screens/home/health/widgets/health_delete_confirm_dialog.dart';
import 'package:docsera/screens/home/health/widgets/health_empty_view.dart';
import 'package:docsera/screens/home/health/widgets/health_no_items_view.dart';
import 'package:docsera/screens/home/health/widgets/health_record_card.dart';
import 'package:docsera/screens/home/health/widgets/health_record_details_dialog.dart';
import 'package:docsera/screens/home/health/widgets/health_record_options_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../utils/full_page_loader.dart';



class AllergiesPage extends StatelessWidget {
  const AllergiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final switcher = context.read<PatientSwitcherCubit>().state;

    return BlocProvider(
      create: (_) => HealthCubit(
        category: "allergy",
        service: HealthRecordsService(),
        userId: switcher.userId,
        relativeId: switcher.relativeId,
      )..loadRecords(),
      child: BlocListener<PatientSwitcherCubit, PatientSwitcherState>(
        listenWhen: (prev, curr) =>
        prev.userId != curr.userId || prev.relativeId != curr.relativeId,
        listener: (context, state) {
          // كل ما تغيّر المريض، حدث الـ HealthCubit
          final healthCubit = context.read<HealthCubit>();
          print(
              "🔁 [AllergiesPage] patient changed → userId=${state.userId}, relativeId=${state.relativeId}");
          healthCubit.updatePatient(
            newUserId: state.userId,
            newRelativeId: state.relativeId,
          );
        },

        child: Scaffold(
          extendBody: true,
          backgroundColor: AppColors.background2,

          appBar: AppBar(
            backgroundColor: AppColors.main,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              t.health_allergies_title,
              style: AppTextStyles.getTitle1(context).copyWith(
                color: Colors.white,
                fontSize: 12.sp,
              ),
            ),
          ),

          floatingActionButton: BlocBuilder<HealthCubit, HealthState>(
            builder: (context, state) {
              if (state.records.isEmpty) {
                return const SizedBox.shrink();
              }

              return FloatingActionButton.extended(
                onPressed: () {
                  final cubit = context.read<HealthCubit>();
                  _openAddAllergyBottomSheet(context, cubit);
                },
                backgroundColor: AppColors.main,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
                icon: Icon(Icons.add_rounded, size: 20.sp, color: Colors.white),
                label: Text(
                  t.allergies_header_add_btn,
                  style: AppTextStyles.getText2(context).copyWith(
                    color: Colors.white,
                    fontSize: 11.sp,
                  ),
                ),
              );
            },
          ),

          body: SafeArea(
            top: true,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),

              child: BlocBuilder<HealthCubit, HealthState>(
                builder: (context, state) {
                  if (state.isLoading && state.records.isEmpty) {
                    return const Center(
                      child: FullPageLoader(),
                    );
                  }

                  // EMPTY — NO RECORDS AND NOT DECLARED "NO ALLERGIES"
                  if (state.records.isEmpty && !state.noItemsDeclared) {
                    return HealthEmptyView(
                      icon: Icons.coronavirus_rounded,
                      title: t.allergies_empty_title,
                      subtitle: t.allergies_empty_subtitle,
                      primaryButtonText: t.allergies_empty_add,

                      onPrimaryPressed: () {
                        final cubit = context.read<HealthCubit>();
                        _openAddAllergyBottomSheet(context, cubit);
                      },

                      secondaryText: t.allergies_empty_no_allergies,
                      onSecondaryPressed: () {
                        context.read<HealthCubit>().setNoItemsDeclared(true);
                      },
                    );
                  }

                  // EMPTY — DECLARED NO ALLERGIES
                  if (state.records.isEmpty && state.noItemsDeclared) {
                    return HealthNoItemsView(
                      icon: Icons.check_circle_rounded,
                      title: t.allergies_no_allergies_title,
                      subtitle: t.allergies_no_allergies_subtitle,
                      changeDecisionText: t.allergies_no_allergies_change,
                      onChangeDecision: () {
                        context.read<HealthCubit>().setNoItemsDeclared(false);
                      },
                      addButtonText: t.allergies_no_allergies_add,
                      onAddPressed: () {
                        final cubit = context.read<HealthCubit>();
                        _openAddAllergyBottomSheet(context, cubit);
                      },
                    );
                  }

                  /// WITH RECORDS
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        t.allergies_header_title,
                        style: AppTextStyles.getTitle1(context).copyWith(
                          color: AppColors.mainDark,
                          fontSize: 14.sp,
                        ),
                      ),

                      SizedBox(height: 4.h),

                      Text(
                        t.allergies_header_subtitle,
                        style: AppTextStyles.getText3(context).copyWith(
                          fontSize: 10.sp,
                          color: AppColors.grayMain,
                        ),
                      ),

                      SizedBox(height: 16.h),

                      Expanded(
                        child: _AllergyRecordsList(
                          records: state.records,
                          onDelete: (id) =>
                              context.read<HealthCubit>().deleteRecord(id),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openAddAllergyBottomSheet(BuildContext context, HealthCubit cubit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) {
        return BlocProvider.value(
          value: cubit,
          child: const AddAllergyBottomSheet(),
        );
      },
    );
  }
}

class _AllergyRecordsList extends StatelessWidget {
  final List<HealthRecord> records;
  final void Function(String id) onDelete;

  const _AllergyRecordsList({
    required this.records,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return ListView.separated(
      padding: EdgeInsets.only(
        bottom: 96.h,
      ),      itemCount: records.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (context, index) {
        final record = records[index];
        final master = record.master;

        // Title & Subtitle
        final title =
        isArabic && master.nameAr.isNotEmpty ? master.nameAr : master.nameEn;

        final desc = isArabic
            ? (master.descriptionAr ?? '')
            : (master.descriptionEn ?? '');

        // SEVERITY
        String? severityLabel;
        Color severityColor = AppColors.grayMain;

        switch (record.severity) {
          case "low":
            severityLabel = t.severity_mild;
            severityColor = Colors.green;
            break;

          case "medium":
            severityLabel = t.severity_moderate;
            severityColor = Colors.orange;
            break;

          case "high":
            severityLabel = t.severity_severe;
            severityColor = Colors.red;
            break;
        }

        final year = record.startDate != null
            ? record.startDate!.year.toString()
            : t.notProvided;

        return HealthRecordCard(
          icon: Icons.coronavirus_rounded,
          title: title,
          subtitle: desc,

          highlighted: record.isConfirmed,
          highlightColor: AppColors.main,

          tags: [
            if (severityLabel != null)
              _tag(severityLabel!, severityColor),

            _tag(year, Colors.blueGrey),

            _tag(
              record.isConfirmed ? t.confirmed_true : t.confirmed_false,
              record.isConfirmed ? AppColors.main : AppColors.background3,
              icon: record.isConfirmed
                  ? Icons.verified_rounded
                  : Icons.info_outline_rounded,
            ),
          ],

          onTap: () => _openDetails(context, record),
          onMenu: () => _openMenu(context, record),
        );
      },
    );
  }

  Widget _tag(String label, Color color, {IconData? icon}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 10.sp, color: color),
          if (icon != null)
            SizedBox(width: 3.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.sp,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _openDetails(BuildContext context, HealthRecord record) {
    final t = AppLocalizations.of(context)!;
    final master = record.master;
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    final name =
    isArabic && master.nameAr.isNotEmpty ? master.nameAr : master.nameEn;

    final desc =
    isArabic && (master.descriptionAr?.isNotEmpty ?? false)
        ? master.descriptionAr!
        : (master.descriptionEn ?? '');

    final severityLocalized = {
      'low': t.low,
      'medium': t.medium,
      'high': t.high,
    };

    showDialog(
      context: context,
      builder: (_) => HealthRecordDetailsDialog(
        icon: Icons.coronavirus_rounded,
        title: t.allergy_information,
        deleteText: t.delete,
        closeText: t.close,

        onDelete: () {
          Navigator.pop(context);
          _openDelete(context, record.id);
        },

        rows: [
          DetailRow(t.allergyName, name),
          if (desc.isNotEmpty) DetailRow(t.description, desc),
          DetailRow(t.severity, severityLocalized[record.severity] ?? t.notProvided),
          DetailRow(t.year, record.startDate != null ? record.startDate!.year.toString() : t.notProvided),
          DetailRow(t.source, record.source == "doctor" ? t.doctor : t.patient),
          DetailRow(t.addedAt, _format(context, record.createdAt)),
          if (record.updatedAt != null && record.updatedAt != record.createdAt)
            DetailRow(t.updatedAt, _format(context, record.updatedAt)),
        ],
      ),
    );
  }

  void _openMenu(BuildContext context, HealthRecord record) {
    final t = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      builder: (_) => HealthRecordOptionsMenu(
        showText: t.showDetails,
        deleteText: t.delete,

        onShowDetails: () {
          Navigator.pop(context);
          _openDetails(context, record);
        },

        onDelete: () {
          Navigator.pop(context);
          _openDelete(context, record.id);
        },
      ),
    );
  }

  void _openDelete(BuildContext context, String id) {
    final t = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (_) => HealthDeleteConfirmDialog(
        title: t.deleteTheAllergy,
        message: t.areYouSureToDeleteAllergy,
        deleteText: t.delete,
        cancelText: t.cancel,
        onConfirm: () {
          Navigator.pop(context);
          onDelete(id);
        },
      ),
    );
  }

  String _format(BuildContext context, DateTime? dt) {
    final t = AppLocalizations.of(context)!;
    if (dt == null) return t.notProvided;

    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }
}
