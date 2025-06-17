import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/Business_Logic/Available_appointments_page/doctor_schedule_cubit.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/appointment_details.dart';
import 'package:docsera/models/patient_profile.dart';
import 'package:docsera/screens/doctors/appointment/appointment_confirm.dart';
import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


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
  Map<String, List<Map<String, dynamic>>> categorizedAppointments = {};
  Set<String> expandedDates = {};
  String? selectedSlotId;
  Timestamp? selectedTimestamp;
  String? selectedTime;
  int maxDisplayedDates = 6;
  bool _isFetched = false; // ✅ متغير لضمان استدعاء الفيتش مرة واحدة



  @override
  void initState() {
    super.initState();
    maxDisplayedDates = 6; // ✅ استخدم القيمة الافتراضية فقط هنا
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isFetched) {
      context.read<DoctorScheduleCubit>().fetchDoctorAppointments(widget.appointmentDetails.doctorId, context);
      _isFetched = true; // ✅ منع استدعاء الفيتش أكثر من مرة
    }
  }




  void _onSlotSelected(String slotId, Timestamp timestamp, String time) {
    Navigator.push(
      context,
      fadePageRoute(
        ConfirmationPage(
          appointmentDetails: widget.appointmentDetails,
          appointmentId: slotId,
          appointmentTimestamp: timestamp,
          appointmentTime: time,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.availableAppointments,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: BlocBuilder<DoctorScheduleCubit, DoctorScheduleState>(
          builder: (context, state) {
            if (state is DoctorScheduleLoading) {
              return _buildShimmerLoading(); // ✅ شاشة تحميل أثناء الجلب
            } else if (state is DoctorScheduleLoaded) {
              return _buildAppointmentsList(state, context);
            } else if (state is DoctorScheduleEmpty) {
              return Center(
                child: Text(
                  AppLocalizations.of(context)!.noAvailableAppointments,
                  style: AppTextStyles.getText2(context),
                ),
              );
            } else {
              return Center(
                child: Text(
                  AppLocalizations.of(context)!.errorLoadingAppointments,
                  style: AppTextStyles.getText2(context).copyWith(color: Colors.red),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Column(
      children: List.generate(7, (index) => Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: ShimmerWidget(
          width: double.infinity,
          height: 40.h, // ✅ نفس حجم بطاقة الموعد
          radius: 12.r,
        ),
      )),
    );
  }

  Widget _buildAppointmentsList(DoctorScheduleLoaded state, BuildContext context) {
    List<MapEntry<String, List<Map<String, dynamic>>>> appointmentList = state.appointments.entries.toList();
    int maxDisplayedDates = state.maxDisplayedDates; // ✅ استخدم maxDisplayedDates من الحالة
    List<MapEntry<String, List<Map<String, dynamic>>>> displayedAppointments = appointmentList.take(maxDisplayedDates).toList();


    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: displayedAppointments.length + 1, // ✅ إضافة زر "عرض المزيد"
            itemBuilder: (context, index) {
              if (index < displayedAppointments.length) {
                return _buildDateContainer(displayedAppointments[index].key, displayedAppointments[index].value, context);
              } else if (state.appointments.length > state.maxDisplayedDates) {
                return _buildShowMoreButton(state);
              } else {
                return SizedBox.shrink();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateContainer(String date, List<Map<String, dynamic>> times, BuildContext context) {
    final state = context.watch<DoctorScheduleCubit>().state;
    bool isExpanded = (state is DoctorScheduleLoaded) ? state.expandedDates.contains(date) : false;

    return Column(
      children: [
        SizedBox(height: 12.h),
        Container(
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
              GestureDetector(
                onTap: () {
                  context.read<DoctorScheduleCubit>().toggleExpand(date);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      date,
                      style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp, color: Colors.black87),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: AppColors.main,
                      size: 20.sp,
                    ),
                  ],
                ),
              ),
              if (isExpanded) ...[
                Divider(color: Colors.grey.shade300, thickness: 1),
                Wrap(
                  spacing: 10.w,
                  runSpacing: 10.h,
                  children: times.map((timeSlot) {
                    return GestureDetector(
                      onTap: () => _onSlotSelected(timeSlot['id'], timeSlot['timestamp'], timeSlot['time']),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
                        decoration: BoxDecoration(
                          color: AppColors.main.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          timeSlot['time'],
                          style: AppTextStyles.getText2(context).copyWith(color: AppColors.main, fontWeight: FontWeight.w500),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShowMoreButton(DoctorScheduleLoaded state) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: GestureDetector(
        onTap: () {
          context.read<DoctorScheduleCubit>().loadMoreDates(state.maxDisplayedDates);
        },
        child: Container(
          width: double.infinity * 0.9, // ✅ الزر أضيق قليلاً من الحاويات العلوية
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: AppColors.mainDark, width: 1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          alignment: Alignment.center,
          child: Text(
            AppLocalizations.of(context)!.showMore,
            style: AppTextStyles.getText3(context).copyWith(fontWeight: FontWeight.bold, color: AppColors.mainDark),
          ),
        ),
      ),
    );
  }
}
