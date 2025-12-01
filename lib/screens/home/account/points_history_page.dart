import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../../Business_Logic/Account_page/points_history/points_history_cubit.dart';
import '../../../Business_Logic/Account_page/points_history/points_history_state.dart';


class PointsHistoryPage extends StatefulWidget {
  final String userId;

  const PointsHistoryPage({super.key, required this.userId});

  @override
  State<PointsHistoryPage> createState() => _PointsHistoryPageState();
}

class _PointsHistoryPageState extends State<PointsHistoryPage>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _progressAnim;
  late ScrollController _scroll;

  final pull = PullRefreshController();
  static const pullThreshold = 70.0;

  static const int goalPoints = 50;

  String _formatDate(String? dt) {
    if (dt == null) return "—";
    try {
      return DateFormat("dd/MM/yyyy").format(DateTime.parse(dt).toLocal());
    } catch (_) {
      return "—";
    }
  }

  String _formatTime(String? time, BuildContext context) {
    if (time == null) return "—";

    try {
      final dt = DateFormat("HH:mm:ss").parse(time);
      String formatted = DateFormat("h:mm a").format(dt);

      if (Localizations.localeOf(context).languageCode == "ar") {
        formatted = formatted.replaceAll("AM", "ص").replaceAll("PM", "م");
      }

      return formatted;
    } catch (_) {
      return "—";
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scroll = ScrollController();
    _scroll.addListener(_handleScroll);
  }

  @override
  void dispose() {
    super.dispose();
    _scroll.dispose();
  }

  void _handleScroll() {
    if (_scroll.position.pixels < 0) {
      final double pullAmount =
      _scroll.position.pixels.abs().clamp(0.0, 90.0);

      if (!pull.isRefreshing) {
        pull.updateOffset(pullAmount);
      }
    }
  }



  void _animateProgress(double percent) {
    _progressAnim = Tween<double>(begin: 0, end: percent).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PointsHistoryCubit()..loadHistory(widget.userId),
      child: Scaffold(
        backgroundColor: AppColors.background2,
        appBar: AppBar(
          backgroundColor: AppColors.main,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            AppLocalizations.of(context)!.pointsHistory,
            style:
            AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
          ),
        ),
        body: BlocConsumer<PointsHistoryCubit, PointsHistoryState>(
          listener: (context, state) {
            if (state is PointsHistoryLoaded) {
              double percent = state.totalPoints / goalPoints;
              if (percent > 1) percent = 1;
              _animateProgress(percent);
            }
          },
          builder: (context, state) {
            if (state is PointsHistoryLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is PointsHistoryError) {
              return Center(
                child: Text(AppLocalizations.of(context)!.errorOccurred,
                    style: AppTextStyles.getText2(context)),
              );
            }

            if (state is PointsHistoryLoaded) {
              return Stack(
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // -----------------------------
                      // 1. Detect user pulling down
                      // -----------------------------
                      if (notification is OverscrollNotification && notification.overscroll < 0) {
                        final double pullAmount =
                        (pull.offset - notification.overscroll).clamp(0.0, 90.0);

                        if (!pull.isRefreshing) {
                          pull.updateOffset(pullAmount);
                        }
                      }

                      // -----------------------------
                      // 2. Detect RELEASE (drag ended)
                      // -----------------------------
                      if (notification is ScrollUpdateNotification &&
                          notification.dragDetails == null) {

                        if (pull.offset > pullThreshold && !pull.isRefreshing) {
                          pull.startRefresh(() async {
                            await context
                                .read<PointsHistoryCubit>()
                                .loadHistory(widget.userId, silent: true);

                            HapticFeedback.mediumImpact();
                          });
                        }
                        else {
                          pull.updateOffset(0);
                        }
                      }

                      return false;
                    },

                    child: CustomScrollView(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _HeaderDelegate(
                            minExtent: 150.h,
                            maxExtent: 150.h,
                            child: _buildHeader(context, state.totalPoints),
                          ),
                        ),
                    
                        // Space under header
                        SliverToBoxAdapter(child: SizedBox(height: 6.h)),
                    
                        // LIST
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            childCount: state.items.length,
                                (context, index) {
                              final item = state.items[index];
                              final doctor = item["doctor_name"] ?? "—";
                              final date = _formatDate(item["appointment_date"]);
                    
                              return _buildHistoryCard(
                                context: context,
                                item: item,
                                doctor: doctor,
                                date: date,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ---- SMALL MOVING DOT ----
                  AnimatedBuilder(
                    animation: pull,
                    builder: (_, __) {
                      if (pull.offset == 0 && !pull.isRefreshing) return SizedBox();

                      double y = pull.offset.clamp(0, pullThreshold);
                      double opacity = (y / pullThreshold).clamp(0.0, 1.0);

                      return Positioned(
                        top: 150.h - 10 + y * 0.5,
                        left: MediaQuery.of(context).size.width / 2 - 4,
                        child: Opacity(
                          opacity: opacity,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.main,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            }

            return SizedBox();
          },
        ),
      ),
    );
  }

  // HEADER
  Widget _buildHeader(BuildContext context, int totalPoints) {
    double percent = totalPoints / goalPoints;
    if (percent > 1) percent = 1;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 22.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.main.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child:
                Icon(Icons.stars, color: AppColors.main, size: 24.sp),
              ),
              SizedBox(width: 16.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.rewardPoints,
                      style: AppTextStyles.getTitle1(context)
                          .copyWith(color: AppColors.mainDark)),
                  SizedBox(height: 4.h),
                  Text(
                    "$totalPoints ${AppLocalizations.of(context)!.points}",
                    style: AppTextStyles.getTitle1(context)
                        .copyWith(color: AppColors.main),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return LinearProgressIndicator(
                value: _progressAnim.value,
                minHeight: 13.h,
                backgroundColor: AppColors.main.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(AppColors.main),
                borderRadius: BorderRadius.circular(20.r),
              );
            },
          ),
          SizedBox(height: 6.h),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "${(percent * 100).round()}% ($totalPoints/$goalPoints)",
              style: AppTextStyles.getText3(context)
                  .copyWith(color: AppColors.mainDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard({
    required BuildContext context,
    required Map<String, dynamic> item,
    required String doctor,
    required String date,
  }) {
    return InkWell(
      onTap: () => _showDetails(context, item),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        padding:
        EdgeInsets.symmetric(horizontal: 16.w, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 3,
                offset: Offset(0, 1))
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.stars, color: AppColors.main, size: 16.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.completedAppointment,
                      style: AppTextStyles.getText2(context).copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.mainDark)),
                  SizedBox(height: 3.h),
                  Text(
                    "${AppLocalizations.of(context)!.withDoctor} $doctor  —  ${AppLocalizations.of(context)!.onDate} $date",
                    style: AppTextStyles.getText3(context),
                  ),
                ],
              ),
            ),
            Text(
              "+${item["points"]}",
              style: AppTextStyles.getTitle1(context)
                  .copyWith(color: AppColors.main),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAccomplished(String? raw, BuildContext context) {
    if (raw == null) return "—";
    try {
      final dt = DateTime.parse(raw).toLocal();
      final date = DateFormat("dd/MM/yyyy").format(dt);
      String time = DateFormat("h:mm a").format(dt);

      if (Localizations.localeOf(context).languageCode == "ar") {
        time = time.replaceAll("AM", "ص").replaceAll("PM", "م");
      }

      return "$date   -   $time";
    } catch (_) {
      return raw;
    }
  }

  void _showDetails(BuildContext context, Map<String, dynamic> item) {
    final doctor = item["doctor_name"] ?? "—";
    final date = _formatDate(item["appointment_date"]);
    final time = _formatTime(item["appointment_time"], context);
    final patient = item["patient_name"] ?? "—";
    final isRelative = item["is_relative"] == true;
    final accomplished = item["created_at"];

    final patientDisplay = isRelative
        ? "$patient (${AppLocalizations.of(context)!.relative})"
        : patient;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(18.r),
        ),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.completedAppointment,
                style: AppTextStyles.getTitle1(context)
                    .copyWith(color: AppColors.mainDark),
              ),

              SizedBox(height: 22.h),

              _infoRow(context, AppLocalizations.of(context)!.patient, patientDisplay),
              _infoRow(context, AppLocalizations.of(context)!.doctor, doctor),
              _infoRow(context, AppLocalizations.of(context)!.date, date),
              _infoRow(context, AppLocalizations.of(context)!.time, time),

              _infoRow(
                context,
                AppLocalizations.of(context)!.accomplishedAt,
                _formatAccomplished(accomplished, context),
              ),

              SizedBox(height: 26.h),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main,
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context)!.close,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                  ),
                ),
              ),

              SizedBox(height: 10.h),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Text("$label:   ",
              style: AppTextStyles.getText2(context)
                  .copyWith(fontWeight: FontWeight.bold)),
          Expanded(
              child:
              Text(value, style: AppTextStyles.getText2(context))),
        ],
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minExtent;
  final double maxExtent;

  _HeaderDelegate(
      {required this.child,
        required this.minExtent,
        required this.maxExtent});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: child);
  }

  @override
  bool shouldRebuild(_HeaderDelegate old) =>
      old.child != child ||
          old.minExtent != minExtent ||
          old.maxExtent != maxExtent;
}


class PullRefreshController extends ChangeNotifier {
  double offset = 0.0;
  bool isRefreshing = false;

  void updateOffset(double newOffset) {
    offset = newOffset;
    notifyListeners();
  }

  Future<void> startRefresh(Future<void> Function() onRefresh) async {
    if (isRefreshing) return;
    isRefreshing = true;
    notifyListeners();

    await onRefresh();

    isRefreshing = false;
    offset = 0.0;
    notifyListeners();
  }
}



