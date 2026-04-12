import 'dart:ui';
import 'package:docsera/Business_Logic/Health_page/patient_switcher_cubit.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/visit_reports_service.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/widgets/month_filter_widget.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/widgets/search_bar_widget.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/widgets/report_card_widget.dart';
import 'package:docsera/utils/full_page_loader.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/app/const.dart';
import 'visit_reports_cubit.dart';
import 'visit_report_model.dart';
import 'modular_report_model.dart';
import 'modular_report_detail_page.dart';
import 'VisitReportDetailsPage.dart';

class _ReportListItem {
  final VisitReport? legacy;
  final ModularReport? modular;
  DateTime get date => legacy?.date ?? modular!.createdAt;
  String get doctorName => legacy?.doctorName ?? modular?.doctorName ?? '';
  bool get isModular => modular != null;

  _ReportListItem.fromLegacy(VisitReport r) : legacy = r, modular = null;
  _ReportListItem.fromModular(ModularReport r) : legacy = null, modular = r;
}

class VisitReportsPage extends StatefulWidget {
  const VisitReportsPage({super.key});

  @override
  State<VisitReportsPage> createState() => _VisitReportsPageState();
}

class _VisitReportsPageState extends State<VisitReportsPage>
    with SingleTickerProviderStateMixin {

  String _search = "";
  int? _selectedYear;
  int? _selectedMonth; // null = ALL months
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) {
        final switcherState = ctx.read<PatientSwitcherCubit>().state;

        debugPrint("📘 [VisitReportsPage] Creating VisitReportsCubit with "
            "userId=${switcherState.userId}, relativeId=${switcherState.relativeId}");

        final cubit = VisitReportsCubit(service: VisitReportsService());
        cubit.updatePatient(
          newUserId: switcherState.userId,
          newRelativeId: switcherState.relativeId,
        );
        return cubit;
      },
      child: BlocListener<PatientSwitcherCubit, PatientSwitcherState>(
        listenWhen: (prev, curr) =>
        prev.userId != curr.userId || prev.relativeId != curr.relativeId,
        listener: (ctx, state) {
          debugPrint("🔁 [VisitReportsPage] PatientSwitcher changed → "
              "userId=${state.userId}, relativeId=${state.relativeId}, "
              "mainUserId=${state.mainUserId}, patientName=${state.patientName}");

          ctx.read<VisitReportsCubit>().updatePatient(
            newUserId: state.userId,
            newRelativeId: state.relativeId,
          );
        },
        child: Scaffold(
          backgroundColor: AppColors.background3,
          body: SafeArea(
            top: true,
            bottom: false,
            child: BlocBuilder<VisitReportsCubit, VisitReportsState>(
              builder: (context, state) {
                if (state.loading) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: const FullPageLoader(),
                  );
                }

                debugPrint("📄 [VisitReportsPage] rebuilding UI with "
                    "${state.reports.length} legacy + "
                    "${state.modularReports.length} modular reports in state");

                // Combine legacy + modular into unified list
                final allItems = <_ReportListItem>[
                  ...state.reports.map((r) => _ReportListItem.fromLegacy(r)),
                  ...state.modularReports.map((r) => _ReportListItem.fromModular(r)),
                ];
                allItems.sort((a, b) => b.date.compareTo(a.date));

                final years = _extractYearsUnified(allItems);
                final activeYear =
                    _selectedYear ?? (years.isNotEmpty ? years.first : null);

                final months = activeYear != null
                    ? _extractMonthsForYearUnified(allItems, activeYear)
                    : <int>[];

                final filtered = _applyFiltersUnified(
                  allItems,
                  activeYear: activeYear,
                  activeMonth: _selectedMonth,
                  query: _search,
                );

                debugPrint("🧮 [VisitReportsPage] after filters → "
                    "year=$activeYear, month=$_selectedMonth, "
                    "search='$_search', "
                    "filteredCount=${filtered.length}");

                return CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    SliverToBoxAdapter(child: _buildHeader(context)),
                    const SliverToBoxAdapter(child: SizedBox(height: 18)),
                    SliverToBoxAdapter(
                      child: SearchBarWidget(
                        onChanged: (t) => setState(() => _search = t),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    if (years.length > 1)
                      SliverToBoxAdapter(
                        child: _buildYearSelector(context, years),
                      ),
                    if (months.isNotEmpty)
                      SliverToBoxAdapter(
                        child: MonthFilterWidget(
                          months: months,
                          selectedMonth: _selectedMonth,
                          onMonthChanged: (m) {
                            setState(() => _selectedMonth = m);
                          },
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 10)),
                    if (filtered.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context)!.health_noReports,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.mainDark.withOpacity(0.6),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final item = filtered[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: item.isModular
                                  ? _buildModularReportCard(context, item.modular!)
                                  : ReportCardWidget(
                                      report: item.legacy!,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          PageRouteBuilder(
                                            transitionDuration:
                                            const Duration(milliseconds: 250),
                                            pageBuilder: (_, anim, __) =>
                                                FadeTransition(
                                                  opacity: anim,
                                                  child: VisitReportDetailsPage(
                                                    report: item.legacy!,
                                                    heroTag: "visit_${item.legacy!.appointmentId}",
                                                  ),
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<VisitReport> _applyFilters(
      List<VisitReport> reports, {
        required int? activeYear,
        required int? activeMonth,
        required String query,
      }) {
    query = query.trim().toLowerCase();

    return reports.where((r) {
      final matchesYear = activeYear == null || r.date.year == activeYear;
      final matchesMonth = activeMonth == null || r.date.month == activeMonth;
      final matchesSearch =
          query.isEmpty || r.doctorName.toLowerCase().contains(query);

      return matchesYear && matchesMonth && matchesSearch;
    }).toList();
  }

  List<_ReportListItem> _applyFiltersUnified(
      List<_ReportListItem> items, {
        required int? activeYear,
        required int? activeMonth,
        required String query,
      }) {
    query = query.trim().toLowerCase();
    return items.where((item) {
      final matchesYear = activeYear == null || item.date.year == activeYear;
      final matchesMonth = activeMonth == null || item.date.month == activeMonth;
      final matchesSearch =
          query.isEmpty || item.doctorName.toLowerCase().contains(query);
      return matchesYear && matchesMonth && matchesSearch;
    }).toList();
  }

  List<int> _extractYearsUnified(List<_ReportListItem> items) {
    return items
        .map((item) => item.date.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
  }

  List<int> _extractMonthsForYearUnified(List<_ReportListItem> items, int year) {
    return items
        .where((item) => item.date.year == year)
        .map((item) => item.date.month)
        .toSet()
        .toList()
      ..sort();
  }

  Widget _buildModularReportCard(BuildContext context, ModularReport report) {
    final t = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final formattedDate =
        "${report.createdAt.day.toString().padLeft(2, '0')}/${report.createdAt.month.toString().padLeft(2, '0')}/${report.createdAt.year}";

    final imageResult = resolveDoctorImagePathAndWidget(
      doctor: {
        "doctor_image": report.doctorImage,
        "gender": report.doctorGender ?? "unknown",
        "title": report.doctorTitle ?? "",
      },
      width: 30,
      height: 30,
    );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 250),
            pageBuilder: (_, anim, __) => FadeTransition(
              opacity: anim,
              child: ModularReportDetailPage(report: report),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.main.withOpacity(0.22)),
            ),
            child: Stack(
              children: [
                // TEXT AREA
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isRtl ? 16 : 68,
                    18,
                    isRtl ? 68 : 16,
                    14,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.doctorName ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.mainDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (report.doctorSpecialty != null &&
                                report.doctorSpecialty!.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  report.doctorSpecialty!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.mainDark.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.main.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    t.modularReport,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: AppColors.main,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.mainDark.withOpacity(0.35),
                      ),
                    ],
                  ),
                ),
                // AVATAR
                Positioned(
                  top: 10,
                  right: isRtl ? 14 : null,
                  left: isRtl ? null : 14,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.main.withOpacity(0.1),
                    backgroundImage: imageResult.imageProvider,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: Colors.white.withOpacity(0.15),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new ,
                color: AppColors.mainDark,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            AppLocalizations.of(context)!.health_reports_title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.mainDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector(BuildContext context, List<int> years) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: years.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            final active = _selectedYear == null;
            return _yearChip(
              label: AppLocalizations.of(context)!.all_label,
              active: active,
              onTap: () {
                setState(() {
                  _selectedYear = null;
                  _selectedMonth = null;
                });
              },
            );
          }

          final year = years[i - 1];
          final active = _selectedYear == year;

          return _yearChip(
            label: year.toString(),
            active: active,
            onTap: () {
              setState(() {
                _selectedYear = year;
                _selectedMonth = null;
              });
            },
          );
        },
      ),
    );
  }

  Widget _yearChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.main.withOpacity(0.28) : Colors.white.withOpacity(0.22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppColors.main : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: active ? AppColors.mainDark : AppColors.mainDark.withOpacity(0.6),
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<VisitReport> reports) {
    final filtered = _filterReports(reports);

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Text(
          AppLocalizations.of(context)!.health_noReports,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.mainDark.withOpacity(0.6),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final r = filtered[i];
        return ReportCardWidget(
          report: r,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VisitReportDetailsPage(
                  report: r,
                  heroTag: "visit_${r.appointmentId}",
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<int> _extractYears(List<VisitReport> reports) {
    return reports
        .map((r) => r.date.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // newest first
  }

  List<int> _extractMonthsForYear(List<VisitReport> reports, int year) {
    return reports
        .where((r) => r.date.year == year)
        .map((r) => r.date.month)
        .toSet()
        .toList()
      ..sort();
  }

  List<VisitReport> _filterReports(List<VisitReport> reports) {
    return reports.where((r) {
      final matchesSearch =
          _search.isEmpty || r.doctorName.toLowerCase().contains(_search.toLowerCase());

      final matchesYear = _selectedYear == null || r.date.year == _selectedYear;

      final matchesMonth = _selectedMonth == null || r.date.month == _selectedMonth;

      return matchesSearch && matchesYear && matchesMonth;
    }).toList();
  }
}
