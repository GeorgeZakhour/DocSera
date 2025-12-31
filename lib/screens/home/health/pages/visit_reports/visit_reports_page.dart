import 'package:docsera/Business_Logic/Health_page/patient_switcher_cubit.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/visit_reports_service.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/widgets/month_filter_widget.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/widgets/search_bar_widget.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/widgets/report_card_widget.dart';
import 'package:docsera/utils/full_page_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/app/const.dart';
import 'visit_reports_cubit.dart';
import 'visit_report_model.dart';
import 'VisitReportDetailsPage.dart';

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

        print("📘 [VisitReportsPage] Creating VisitReportsCubit with "
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
          print("🔁 [VisitReportsPage] PatientSwitcher changed → "
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

                print("📄 [VisitReportsPage] rebuilding UI with "
                    "${state.reports.length} reports in state");

                final years = _extractYears(state.reports);
                final activeYear =
                    _selectedYear ?? (years.isNotEmpty ? years.first : null);

                final months = activeYear != null
                    ? _extractMonthsForYear(state.reports, activeYear)
                    : <int>[];

                final filtered = _applyFilters(
                  state.reports,
                  activeYear: activeYear,
                  activeMonth: _selectedMonth,
                  query: _search,
                );

                print("🧮 [VisitReportsPage] after filters → "
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
                            final r = filtered[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: ReportCardWidget(
                                report: r,
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
                                              report: r,
                                              heroTag: "visit_${r.appointmentId}",
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
