import 'package:docsera/Business_Logic/Available_appointments_page/doctor_schedule_cubit.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/appointment_details.dart';
import 'package:docsera/models/patient_profile.dart';
import 'package:docsera/screens/doctors/appointment/appointment_confirm.dart';
import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/utils/time_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorAppointmentsPage extends StatefulWidget {
  final PatientProfile patientProfile;
  final AppointmentDetails appointmentDetails;

  const DoctorAppointmentsPage({
    Key? key,
    required this.patientProfile,
    required this.appointmentDetails,
  }) : super(key: key);

  @override
  State<DoctorAppointmentsPage> createState() => _DoctorAppointmentsPageState();
}

class _DoctorAppointmentsPageState extends State<DoctorAppointmentsPage> {
  String _schedulingMode = 'default';
  bool _loadingMode = true;

  // ✅ امسك مرجع الكيوبِت بشكل آمن لتجنّب قراءة الـ context في dispose()
  late DoctorScheduleCubit _sched;
  bool _didInitCubit = false;

  @override
  void initState() {
    super.initState();
    // لا نستخدم context.read هنا لتفادي مشاكل دورة الحياة في dispose
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitCubit) {
      _sched = context.read<DoctorScheduleCubit>();
      _sched.expandedDates.clear(); // ✅ اطوِ كل البطاقات عند الدخول
      _bootstrapFetch();
      _didInitCubit = true;
    }
  }

  @override
  void dispose() {
    // ✅ تفريغ التوسيع عند مغادرة الصفحة (آمن لأننا نستخدم المرجع مباشرةً)
    _sched.expandedDates.clear();
    super.dispose();
  }

  Future<void> _bootstrapFetch() async {
    final doctorId = widget.appointmentDetails.doctorId;
    final reasonId = widget.appointmentDetails.reasonId;

    if (doctorId.isEmpty) return;

    try {
      final data = await Supabase.instance.client
          .from('doctors')
          .select('appointment_scheduling_mode')
          .eq('id', doctorId)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _schedulingMode = (data?['appointment_scheduling_mode'] as String?) ?? 'default';
        _loadingMode = false;
      });

      debugPrint('[Schedule/UI] Scheduling mode for doctor=$doctorId → $_schedulingMode');

      // 2) استدعاء الكيوبِت وفق النمط
      if (_schedulingMode == 'custom_by_reason' && reasonId?.isNotEmpty == true) {
        debugPrint('[Schedule/UI] Fetch with reason=$reasonId');
        _sched.fetchDoctorAppointments(
          doctorId,
          context,
          reasonId: reasonId,
        );
      } else {
        debugPrint('[Schedule/UI] Fetch default (no reason)');
        _sched.fetchDoctorAppointments(
          doctorId,
          context,
        );
      }
    } catch (e, st) {
      debugPrint('[Schedule/UI] Error while bootstrapping mode: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loadingMode = false;
      });
    }
  }

  Future<void> _refetch() async {
    // ✅ عند إعادة التحميل تأكد أيضًا من طيّ الكل
    _sched.expandedDates.clear();
    await _bootstrapFetch();
  }

  void _onSlotSelected(String slotId, DateTime timestamp, String time) {
    Navigator.push(
      context,
      fadePageRoute(
        ConfirmationPage(
          appointmentDetails: widget.appointmentDetails,
          appointmentId: slotId,
          appointmentTimestamp: timestamp,
          appointmentTime: time,                // ← صيغة 12 ساعة جاهزة
          reasonLabel: widget.patientProfile.reason, // ← مرّر اسم السبب هنا
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final reasonLabel = isRtl ? 'السبب' : 'Reason';

    return BaseScaffold(
      title: Text(
        l.availableAppointments,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // شارة لعرض السبب المختار: "Reason : X" أو "السبب : X"
            if ((widget.patientProfile.reason).trim().isNotEmpty) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.main.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.main.withOpacity(0.2)),
                ),
                child: Text(
                  '$reasonLabel : ${widget.patientProfile.reason}',
                  style: AppTextStyles.getText2(context).copyWith(
                    fontSize: 11.sp,
                    color: AppColors.mainDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 12.h),
            ],

            if (_loadingMode)
              Expanded(child: _buildShimmerLoading())
            else
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.main,
                  onRefresh: _refetch,
                  child: BlocBuilder<DoctorScheduleCubit, DoctorScheduleState>(
                    builder: (context, state) {
                      if (state is DoctorScheduleLoading) {
                        return _buildShimmerLoading();
                      } else if (state is DoctorScheduleLoaded) {
                        return _buildAppointmentsList(state);
                      } else if (state is DoctorScheduleEmpty) {
                        return Center(
                          child: Text(
                            l.noAvailableAppointments,
                            style: AppTextStyles.getText2(context),
                            textAlign: TextAlign.center,
                          ),
                        );
                      } else if (state is DoctorScheduleError) {
                        return _buildError(l);
                      } else {
                        return _buildError(l);
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l.errorLoadingAppointments,
            style: AppTextStyles.getText2(context).copyWith(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),
          OutlinedButton(
            onPressed: _refetch,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.mainDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            ),
            child: Text(
              l.retry,
              style: AppTextStyles.getText3(context).copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.mainDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 7,
      itemBuilder: (_, __) => Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: ShimmerWidget(
          width: double.infinity,
          height: 40.h,
          radius: 12.r,
        ),
      ),
    );
  }

  Widget _buildAppointmentsList(DoctorScheduleLoaded state) {
    final l = AppLocalizations.of(context)!;

    final displayedEntries = state.appointments.entries.take(state.maxDisplayedDates).toList();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: displayedEntries.length + (state.appointments.length > state.maxDisplayedDates ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < displayedEntries.length) {
          final entry = displayedEntries[index];
          return _buildDateContainer(entry.key, entry.value);
        } else {
          return _buildShowMoreButton(state, l);
        }
      },
    );
  }


  Widget _buildDateContainer(String date, List<Map<String, dynamic>> times) {
    final l = AppLocalizations.of(context)!;
    final state = context.watch<DoctorScheduleCubit>().state;
    final isExpanded = state is DoctorScheduleLoaded && state.expandedDates.contains(date);

    // البطاقة كلها قابلة للنقر للتوسيع/الطي
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => _sched.toggleExpand(date),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    date,
                    style: AppTextStyles.getTitle1(context).copyWith(
                      fontSize: 12.sp,
                      color: Colors.black87,
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.main,
                    size: 20.sp,
                  ),
                ],
              ),

              if (isExpanded) ...[
                Divider(color: Colors.grey.shade300, thickness: 1),

                if (times.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.h),
                    child: Text(
                      l.noAvailableAppointments,
                      style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp),
                    ),
                  )
                else
                  Wrap(
                    spacing: 10.w,
                    runSpacing: 10.h,
                    children: times.map((slot) {
                      final DateTime tsUtc = slot['timestamp'] as DateTime; // UTC
                      final String id = slot['id'] as String;

                      // صيغة الوقت المحلي (UTC+3) مع تعريب ص/م تلقائي:
                      final String label = format12hLocalized(context, tsUtc);

                      return GestureDetector(
                        onTap: () => _onSlotSelected(id, tsUtc, label),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
                          decoration: BoxDecoration(
                            color: AppColors.main.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: AppColors.main.withOpacity(0.25)),
                          ),
                          child: Text(
                            label,
                            style: AppTextStyles.getText2(context).copyWith(
                              color: AppColors.main,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShowMoreButton(DoctorScheduleLoaded state, AppLocalizations l) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 6.h),
      child: GestureDetector(
        onTap: () => _sched.loadMoreDates(state.maxDisplayedDates),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: AppColors.mainDark, width: 1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          alignment: Alignment.center,
          child: Text(
            l.showMore,
            style: AppTextStyles.getText3(context).copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.mainDark,
            ),
          ),
        ),
      ),
    );
  }
}
