import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/Business_Logic/Available_appointments_page/doctor_schedule_cubit.dart';
import 'package:docsera/models/appointment_details.dart';
import 'package:docsera/models/patient_profile.dart';
import 'package:docsera/screens/doctors/appointment/select_patient_page.dart';
import 'package:docsera/screens/home/appointment/reschedule_confirmation_page.dart';
import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../app/text_styles.dart';
import '../../doctors/appointment/appointment_confirm.dart';
import 'appointment_cancel_confirmation.dart' show AppointmentCancelledPage;


class AppointmentDetailsPage extends StatelessWidget {

  final Map<String, dynamic> appointment;
  final bool isUpcoming; // 🔹 New flag to differentiate


  const AppointmentDetailsPage({
    Key? key,
    required this.appointment,
    required this.isUpcoming, // Defaults to false (for past appointments)
  }) : super(key: key);


  /// 🔹 Open Google Maps with the given address
  void _openMaps(String address) async {
    String encodedAddress = Uri.encodeComponent(address);
    Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encodedAddress");

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $googleMapsUrl';
    }
  }

  void _addToCalendar(BuildContext context) {
    DateTime startTime = DateTime.parse(appointment['timestamp']);
    DateTime endTime = startTime.add(Duration(minutes: 30)); // Assuming a 30 min appointment

    final Event event = Event(
      title: 'Appointment with ${appointment['doctorTitle'] ?? ''}${appointment['doctorName'] ?? 'Doctor'}',
      description: 'Reason: ${appointment['reason'] ?? 'No reason provided'}',
      location: "${appointment['clinicAddress']['street'] ?? ''}, ${appointment['clinicAddress']['city'] ?? ''}",
      startDate: startTime,
      endDate: endTime,
      allDay: false,
    );

    // 🔍 Debug prints for terminal
    print("🔗 Adding Event to Calendar:");
    print("📅 Title: ${event.title}");
    print("📄 Description: ${event.description}");
    print("📍 Location: ${event.location}");
    print("🕑 Start Time: ${event.startDate}");
    print("🕑 End Time: ${event.endDate}");
    print("📅 All Day Event: ${event.allDay}");


    Add2Calendar.addEvent2Cal(event).then((success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '📅 Appointment added to your calendar!' : '⚠️ Failed to add appointment.'),
        ),
      );
    });
  }

  void _shareAppointmentDetails() {
    DateTime appointmentDate = DateTime.parse(appointment['timestamp']);
    String formattedDate = DateFormat("EEEE, d MMMM yyyy").format(appointmentDate);
    String formattedTime = DateFormat("HH:mm").format(appointmentDate);

    String doctorName = "${appointment['doctorTitle'] ?? ''} ${appointment['doctorName'] ?? 'Doctor'}".trim();
    Map<String, dynamic> clinicAddress = appointment['clinicAddress'] ?? {};

    String formattedAddress = "${clinicAddress['street'] ?? ''} ${clinicAddress['buildingNr'] ?? ''}, "
        "${clinicAddress['city'] ?? ''}, ${clinicAddress['country'] ?? ''}";

    String shareText = """
📅 **Appointment Details**:

👨‍⚕️ Doctor: $doctorName
📍 Location: ${appointment['clinicName'] ?? 'Clinic not specified'}
🏡 Address: $formattedAddress
📅 Date: $formattedDate
🕑 Time: $formattedTime
📝 Reason: ${appointment['reason'] ?? 'No reason provided'}

Shared from DocSera App
""";

    Share.share(shareText, subject: "Appointment with $doctorName");
  }

  void _showRescheduleAppointmentSheet(BuildContext context) async {
    DateTime appointmentDate = DateTime.parse(appointment['timestamp']);
    DateTime now = DateTime.now();
    Duration difference = appointmentDate.difference(now);

    final bool isTooLate = difference < const Duration(hours: 24);
    final bool isShortNotice = difference >= const Duration(hours: 24) && difference <= const Duration(hours: 48);

    // 🔍 تحقق من وجود مواعيد متاحة
    final availableSlots = await FirebaseFirestore.instance
        .collection('doctors')
        .doc(appointment['doctorId'])
        .collection('appointments')
        .where('booked', isEqualTo: false)
        .where('timestamp', isGreaterThan: Timestamp.now())
        .get();

    final hasAvailable = availableSlots.docs.isNotEmpty;

    if (isTooLate) {
      // ⛔️ أقل من 24 ساعة – ممنوع إعادة الجدولة
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(
                        AppLocalizations.of(context)!.reschedule,
                        style: AppTextStyles.getTitle1(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.blackText,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 25.h),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset('assets/images/empty_calendar.png', height: 70, width: 70),
                    Positioned(
                      bottom: -10,
                      right: -10,
                      child: Icon(Icons.access_time, color: AppColors.orangeText, size: 35),
                    ),
                  ],
                ),
                SizedBox(height: 35.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30.r),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.tooLateToReschedule,
                    style: TextStyle(color: AppColors.orangeText, fontWeight: FontWeight.bold, fontSize: 12.sp),
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  AppLocalizations.of(context)!.rescheduleTimeLimitNote,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.getText3(context).copyWith(fontSize: 11.sp),
                ),
                SizedBox(height: 25.h),
              ],
            ),
          );
        },
      );
      return;
    }

    if (!hasAvailable) {
      // ⛔️ لا يوجد مواعيد متاحة
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(
                        AppLocalizations.of(context)!.reschedule,
                        style: AppTextStyles.getTitle1(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.blackText,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 25.h),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset('assets/images/empty_calendar.png', height: 70, width: 70),
                    Positioned(
                      bottom: -10,
                      right: -10,
                      child: Icon(Icons.info_outline, color: AppColors.red.withOpacity(0.8), size: 35),
                    ),
                  ],
                ),
                SizedBox(height: 35.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE7E7),
                    borderRadius: BorderRadius.circular(30.r),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.noAvailableAppointments,
                    style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 12.sp),
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  AppLocalizations.of(context)!.cancelInsteadNote,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.getText3(context).copyWith(fontSize: 11.sp),
                ),
                SizedBox(height: 25.h),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showCancelAppointmentSheet(context);
                  },
                  child: Text(
                    AppLocalizations.of(context)!.cancelAppointmentAction.toUpperCase(),
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.sp),
                  ),
                ),
              ],
            ),
          );
        },
      );
      return;
    }

    // ✅ الحالة الأخيرة: في وقت كافي ومواعيد متاحة => أطلب السبب وأكّد العملية
    bool isInvalid = false;
    TextEditingController reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 16.h,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height * 0.9,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        SizedBox(height: 10.h),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(
                              child: Text(
                                AppLocalizations.of(context)!.reschedule,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.getTitle1(context).copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.blackText,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 35.h),


                          Column(
                            children: [
                              if (isShortNotice)
                                Column(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Image.asset('assets/images/empty_calendar.png', height: 70, width: 70),
                                      Positioned(
                                        bottom: -10,
                                        right: -10,
                                        child: Icon(Icons.warning_rounded, color: AppColors.yellow.withOpacity(0.8), size: 35),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 25.h),
                                ],
                              ),

                              if (!isShortNotice)
                                Column(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Image.asset('assets/images/empty_calendar.png', height: 70, width: 70),
                                      Positioned(
                                        bottom: -10,
                                        right: -10,
                                        child: Icon(Icons.access_time, color: AppColors.orangeText.withOpacity(0.8), size: 35),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 25.h),
                                ],
                              ),

                              if (isShortNotice)
                                Column(
                                  children: [
                                    Text(
                                      AppLocalizations.of(context)!.rescheduleWarningTitle,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 25.h),
                                    Container(
                                      padding: EdgeInsets.all(16.w),
                                      decoration: BoxDecoration(
                                        color: AppColors.yellow.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8.r),
                                        border: Border.all(color: AppColors.yellow.withOpacity(0.8)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.warning, color: Colors.brown, size: 16.sp),
                                          SizedBox(width: 8.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  AppLocalizations.of(context)!.appointmentShortNoticeWarning,
                                                  style: TextStyle(color: Colors.brown, fontSize: 12.sp, fontWeight: FontWeight.bold),
                                                ),
                                                SizedBox(height: 4.h),
                                                Text(
                                                  AppLocalizations.of(context)!.rescheduleRespectNotice,
                                                  style: TextStyle(color: Colors.brown, fontSize: 11.sp, fontWeight: FontWeight.w500),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 25.h),
                                  ],
                                ),
                            ],
                          ),


                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            AppLocalizations.of(context)!.rescheduleReasonQuestion,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                          ),
                        ),
                        SizedBox(height: 10.h),
                        TextField(
                          controller: reasonController,
                          maxLines: 3,
                          textDirection: detectTextDirection(reasonController.text),
                          textAlign: getTextAlign(context),
                          style: AppTextStyles.getText2(context),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.typeReasonHere,
                            hintStyle: AppTextStyles.getText3(context).copyWith(fontSize: 11.sp, color: Colors.grey),
                            contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
                            filled: true,
                            fillColor: Colors.white,
                            errorText: isInvalid ? AppLocalizations.of(context)!.reasonRequired : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.r),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.r),
                              borderSide: BorderSide(color: AppColors.main, width: 2),
                            ),
                          ),
                          onChanged: (_) => setState(() => isInvalid = false),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.main,
                            minimumSize: const Size(double.infinity, 40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                          ),
                          onPressed: () async {
                            if (reasonController.text.trim().isEmpty) {
                              setState(() => isInvalid = true);
                              return;
                            }
                            // أغلق الشيت الحالي
                            Navigator.pop(context);
                            final screenHeight = MediaQuery.of(context).size.height;

                            final doctorScheduleCubit = context.read<DoctorScheduleCubit>()
                              ..fetchDoctorAppointments(appointment['doctorId'] ?? '', context);
// افتح الشيت يلي يعرض المواعيد المتاحة
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: AppColors.background2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                              ),
                              builder: (_) {
                                return SizedBox(
                                  height: screenHeight * 0.9,
                                  child: BlocProvider.value(
                                    value: doctorScheduleCubit,
                                    child: DoctorAppointmentsBottomSheet(
                                      patientProfile: PatientProfile(
                                        patientId: appointment['userId'] ?? '',
                                        doctorId: appointment['doctorId'] ?? '',
                                        patientName: appointment['patientName'] ?? '',
                                        patientGender: appointment['userGender'] ?? '',
                                        patientAge: appointment['userAge'] ?? 0,
                                        patientDOB: '',
                                        patientPhoneNumber: '',
                                        patientEmail: '',
                                        reason: appointment['reason'] ?? '',
                                      ),
                                      appointmentDetails: AppointmentDetails(
                                        doctorId: appointment['doctorId'] ?? '',
                                        doctorName: appointment['doctorName'] ?? '',
                                        doctorGender: appointment['doctorGender'] ?? '',
                                        doctorTitle: appointment['doctorTitle'] ?? '',
                                        specialty: appointment['specialty'] ?? '',
                                        image: appointment['doctorImage'] ?? '',
                                        patientName: appointment['patientName'] ?? '',
                                        patientGender: appointment['userGender'] ?? '',
                                        patientAge: appointment['userAge'] ?? 0,
                                        newPatient: appointment['newPatient'] ?? false,
                                        reason: appointment['reason'] ?? '',
                                        clinicName: appointment['clinicName'] ?? '',
                                        clinicAddress: appointment['clinicAddress'] ?? {},
                                      ),
                                      oldAppointmentId: appointment['appointmentId'] ?? '',
                                      oldTimestamp: appointment['timestamp'] is Timestamp
                                          ? appointment['timestamp']
                                          : Timestamp.fromDate(DateTime.parse(appointment['timestamp'])),
                                    ),

                                  ),
                                );
                              },
                            );



                            // Navigator.push(context, fadePageRoute(ReschedulePage(...)));
                          },
                          child: Text(
                            AppLocalizations.of(context)!.continuing.toUpperCase(),
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.sp),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            AppLocalizations.of(context)!.keepAppointment,
                            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 12.sp),
                          ),
                        ),
                        SizedBox(height: 10.h),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCancelAppointmentSheet(BuildContext context) {
    DateTime appointmentDate = DateTime.parse(appointment['timestamp']);
    DateTime now = DateTime.now();
    Duration difference = appointmentDate.difference(now);

    final bool isTooLate = difference < const Duration(hours: 24);
    final bool isShortNotice = difference >= const Duration(hours: 24) && difference <= const Duration(hours: 48);

    if (isTooLate) {
      // ⛔️ أقل من 24 ساعة – ممنوع الإلغاء
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(
                        AppLocalizations.of(context)!.cancelAppointment,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.getTitle1(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.blackText,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 25.h),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset('assets/images/empty_calendar.png', height: 70, width: 70),
                    Positioned(
                      bottom: -10,
                      right: -10,
                      child: Icon(Icons.cancel, color: AppColors.red.withOpacity(0.8), size: 35),
                    ),
                  ],
                ),
                SizedBox(height: 35.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE7E7),
                    borderRadius: BorderRadius.circular(30.r),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.tooLateToCancel,
                    style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 12.sp),
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  AppLocalizations.of(context)!.cancelTimeLimitNote,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.getText3(context).copyWith(fontSize: 11.sp),
                ),
                SizedBox(height: 25.h),
              ],
            ),
          );
        },
      );
      return;
    }

    bool isInvalid = false;
    TextEditingController reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 16.h,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height * 0.9,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        SizedBox(height: 10.h),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(
                              child: Text(
                                AppLocalizations.of(context)!.cancelAppointment,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.getTitle1(context).copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.blackText,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 35.h),

                          Column(
                            children: [
                              if (!isShortNotice)
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Image.asset('assets/images/empty_calendar.png', height: 70, width: 70),
                                    Positioned(
                                      bottom: -10,
                                      right: -10,
                                      child: Icon(Icons.cancel, color: AppColors.red.withOpacity(0.8), size: 35),
                                    ),
                                  ],
                                ),
                              if (isShortNotice)
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Image.asset('assets/images/empty_calendar.png', height: 70, width: 70),
                                    Positioned(
                                      bottom: -10,
                                      right: -10,
                                      child: Icon(Icons.warning_rounded, color: AppColors.yellow.withOpacity(0.8), size: 35),
                                    ),
                                  ],
                                ),


                                SizedBox(height: 25.h),

                              if (isShortNotice)
                                Text(
                                  AppLocalizations.of(context)!.cancelWarningTitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
                                ),
                              if (isShortNotice)
                                SizedBox(height: 25.h),
                              if (isShortNotice)
                                Container(
                                  padding: EdgeInsets.all(16.w),
                                  decoration: BoxDecoration(
                                    color: AppColors.yellow.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8.r),
                                    border: Border.all(color: AppColors.yellow.withOpacity(0.8)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.warning, color: Colors.brown, size: 16.sp),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              AppLocalizations.of(context)!.appointmentShortNoticeWarning,
                                              style: TextStyle(color: Colors.brown, fontSize: 12.sp, fontWeight: FontWeight.bold),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              AppLocalizations.of(context)!.cancelRespectNotice,
                                              style: TextStyle(color: Colors.brown, fontSize: 11.sp, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              SizedBox(height: 25.h),
                            ],
                          ),
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            AppLocalizations.of(context)!.cancelReasonQuestion,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                          ),
                        ),
                        SizedBox(height: 10.h),
                        TextField(
                          controller: reasonController,
                          maxLines: 3,
                          textDirection: detectTextDirection(reasonController.text),
                          textAlign: getTextAlign(context),
                          style: AppTextStyles.getText2(context),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.typeReasonHere,
                            hintStyle: AppTextStyles.getText3(context).copyWith(fontSize: 11.sp, color: Colors.grey),
                            contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
                            filled: true,
                            fillColor: Colors.white,
                            errorText: isInvalid ? AppLocalizations.of(context)!.reasonRequired : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.r),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.r),
                              borderSide: BorderSide(color: AppColors.main, width: 2),
                            ),
                          ),
                          onChanged: (_) => setState(() => isInvalid = false),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.red,
                            minimumSize: const Size(double.infinity, 40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                          ),
                          onPressed: () async {
                            if (reasonController.text.trim().isEmpty) {
                              setState(() => isInvalid = true);
                              return;
                            }

                            // احفظ نسخة من السياق الحالي
                            final currentContext = context;

                            try {
                              await _cancelAppointment(
                                context,
                                userId: appointment['userId'],
                                appointmentId: appointment['appointmentId'],
                                doctorId: appointment['doctorId'],
                              );

                              // ✅ التنقل لصفحة التأكيد بعد الإلغاء
                              Navigator.pushReplacement(
                                currentContext,
                                fadePageRoute(AppointmentCancelledPage(appointment: appointment)),
                              );
                            } catch (e) {
                              // ✅ عرض رسالة الخطأ بسياق صالح
                              ScaffoldMessenger.of(currentContext).showSnackBar(
                                SnackBar(
                                  content: Text(AppLocalizations.of(currentContext)!.somethingWentWrong),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },

                          child: Text(
                            AppLocalizations.of(context)!.cancelAppointmentAction.toUpperCase(),
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.sp),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            AppLocalizations.of(context)!.keepAppointment,
                            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 12.sp),
                          ),
                        ),
                        SizedBox(height: 10.h),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _cancelAppointment(
      BuildContext context, {
        required String userId,
        required String appointmentId,
        required String doctorId,
      }) async {
    try {
      // حذف الموعد من حساب المستخدم
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('appointments')
          .doc(appointmentId)
          .delete();

      // تحديث الموعد عند الطبيب ليصير غير محجوز
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(doctorId)
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'booked': false,
        'accountName': null,
        'patientName': null,
        'userGender': null,
        'userAge': null,
        'newPatient': null,
        'reason': null,
        'bookingTimestamp': null,
      });

      // رجوع وإظهار تأكيد
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.appointmentCancelled),
        backgroundColor: AppColors.red.withOpacity(0.8),
      ));
    } catch (e) {
      print("❌ Error cancelling appointment: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.somethingWentWrong),
        backgroundColor: Colors.red,
      ));
    }
  }



  @override
  Widget build(BuildContext context) {
    DateTime appointmentDate = DateTime.parse(appointment['timestamp']);
    String locale = Localizations.localeOf(context).languageCode; // ✅ Get the current locale

// ✅ Format date normally
    String formattedDate = DateFormat("EEEE, d MMMM yyyy", locale).format(appointmentDate);

// ✅ Ensure 12-hour format with AM/PM
    String formattedTime = DateFormat("h:mm a", locale).format(appointmentDate);


    Map<String, dynamic> clinicAddress = appointment['clinicAddress'] ?? {};

    String formattedAddress = "${clinicAddress['street'] ?? ''} ${clinicAddress['buildingNr'] ?? ''}\n"
        "${clinicAddress['city'] ?? ''}\n"
        "${clinicAddress['country'] ?? ''}\n"
        "${clinicAddress['details'] ?? ''}";

    // Create the doctorName variable (handles empty title)
    String doctorName = "${appointment['doctorTitle'] ?? ''} ${appointment['doctorName'] ?? ''}".trim();
    print("🚀🚀🚀🚀🚀🚀🚀 TEST TEST TEST: '$appointment['doctorId']'");




    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.appointmentDetails,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText, fontSize: 13.sp),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.share_outlined, color: Colors.white,size: 20.sp,),
          onPressed: () {
            _shareAppointmentDetails(); // ✅ Trigger the share
          },
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.background2, AppColors.mainDark, 0.06), // ✅ يزيد قتامة بنسبة 20%
        ),
        child: SafeArea(
          child: Stack(
            children:[
              Padding(
                padding: EdgeInsets.only(top: 40.h), // Add top padding for sticky header
                child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Doctor Information
                    Container(
                      decoration: const BoxDecoration(color: AppColors.background2),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w , vertical: 15.h),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque, // ✅ Makes blank space clickable
                              onTap: () {
                                final doctorId = appointment['doctorId']?.toString() ?? '';

                                print("🚀 Navigating to DoctorProfilePage with doctorId: '$doctorId'");
                                print("💡 Full appointment object: $appointment");

                                if (doctorId.isEmpty) {
                                  print("❌ ERROR: doctorId is missing or empty.");
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(AppLocalizations.of(context)!.doctorIdMissingError)),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    fadePageRoute(
                                      DoctorProfilePage(doctorId: doctorId),
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.main.withOpacity(0.3),
                                    radius: 20.sp,
                                    backgroundImage: AssetImage(appointment['doctorImage'] ?? 'assets/images/male-doc.png'),
                                  ),
                                  SizedBox(width: 20.w),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doctorName.isNotEmpty ? doctorName : '',
                                      style: AppTextStyles.getText2(context).copyWith(fontSize: 13.sp,fontWeight: FontWeight.bold),
                                      ),

                                      Text(
                                        appointment['specialty'] ?? AppLocalizations.of(context)!.unknownSpecialty,
                                          style: AppTextStyles.getText2(context).copyWith( color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 12.sp),
                                ],
                              ),
                            ),
                          ),

                          Divider(color: Colors.grey[200],height: 2.h), // 🔹 Set a fixed height for the divider,

                          // Reason for visit
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 15.h),
                            child: Row(
                              children:  [
                                Icon(Icons.local_hospital_outlined, color: AppColors.main, size: 16.sp),
                                SizedBox(width: 15.w),
                                Expanded(child: Text(appointment['reason'] ?? AppLocalizations.of(context)!.notSpecified,
                                     style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp))),
                              ],
                            ),
                          ),
                          Divider(color: Colors.grey[200],height: 2),

                          // 🔹 Reschedule & Cancel Buttons
                          if (isUpcoming) // Show only for upcoming appointments
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  // ✅ Reschedule Button
                                  TextButton.icon(
                                    onPressed: () => _showRescheduleAppointmentSheet(context),
                                    icon: Icon(Icons.edit_calendar_outlined, color: AppColors.main, size: 14.sp,),
                                    label: Text(
                                      AppLocalizations.of(context)!.reschedule,
                                      style: AppTextStyles.getText2(context).copyWith(color: AppColors.main, fontWeight: FontWeight.bold),
                                    ),
                                    style: ButtonStyle(
                                      overlayColor: MaterialStateProperty.resolveWith<Color?>(
                                            (Set<MaterialState> states) {
                                          return Colors.transparent; // ✅ No overlay color on press
                                        },
                                      ),
                                      splashFactory: NoSplash.splashFactory, // ✅ No ripple effect
                                    ),
                                  ),

                                  // ✅ Cancel Appointment Button
                                  TextButton.icon(
                                    onPressed: () => _showCancelAppointmentSheet(context),

                                    icon: Icon(Icons.cancel_outlined, color: AppColors.red, size: 14.sp,),
                                    label: Text(
                                      AppLocalizations.of(context)!.cancelAppointment,
                                      style: AppTextStyles.getText2(context).copyWith(color: AppColors.red, fontWeight: FontWeight.bold),
                                    ),
                                    style: ButtonStyle(
                                      overlayColor: MaterialStateProperty.resolveWith<Color?>(
                                            (Set<MaterialState> states) {
                                          return Colors.transparent; // ✅ No overlay color on press
                                        },
                                      ),
                                      splashFactory: NoSplash.splashFactory, // ✅ No ripple effect
                                    ),
                                  ),
                                ],
                              ),
                            ),

                        ],
                      ),
                    ),
                    SizedBox  (height: 8.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0.w),
                      child: Column(
                        children: [
                          if (isUpcoming)
                          Card(
                            color: AppColors.background2, // ✅ Light background like in the design
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0, // ✅ No shadow to match the UI
                            child: InkWell(
                              onTap: () {
                                // ✅ Navigate to booking screen
                              },
                              borderRadius: BorderRadius.circular(12.r),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 18.w),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.file_open_outlined, color: AppColors.main, size: 16.sp),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppLocalizations.of(context)!.sendDocuments,
                                            style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp, color: AppColors.main, fontWeight: FontWeight.bold),
                                          ),
                                          SizedBox(height: 4.h), // ✅ Adds slight spacing between lines
                                          Text(
                                            AppLocalizations.of(context)!.sendDocumentsSubtitle,
                                            style: AppTextStyles.getText3(context).copyWith(fontWeight: FontWeight.w400, color: Colors.black54),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: true,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          if (isUpcoming) SizedBox  (height: 8.h),

                          Card(
                            color: AppColors.background2, // ✅ Light background like in the design
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0, // ✅ No shadow to match the UI
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  fadePageRoute(
                                    SelectPatientPage(
                                      doctorId: appointment["doctorId"] ?? "",
                                      doctorName: appointment["doctorName"] ?? "Unknown",
                                      doctorTitle: appointment["doctorTitle"] ?? "",
                                      doctorGender: appointment["doctorGender"] ?? "",
                                      specialty: appointment["specialty"] ?? "General Practice",
                                      image: appointment["doctorImage"] ?? "assets/images/female-doc.png",
                                      clinicName: appointment['clinicName'] ?? "Unknown Clinic",
                                      clinicAddress: appointment['clinicAddress'] ?? {},
                                    ),
                                  ),
                                );                              },
                              borderRadius: BorderRadius.circular(12.r),
                              child: Padding(
                                padding:  EdgeInsets.symmetric(vertical: 14.h, horizontal: 18.w),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Icon(Icons.refresh, color: AppColors.main, size: 16.sp),
                                    SizedBox(width: 10.w),
                                    Text(
                                      AppLocalizations.of(context)!.bookAgain,
                                      style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp, color: AppColors.main, fontWeight: FontWeight.bold),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 12.sp),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox  (height: 8.h),

                          // Patient Information
                          Card(
                            color: AppColors.background2, // ✅ Light background
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0, // ✅ No shadow
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 🔹 Title "Patient"
                                Padding(
                                  padding: const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 5),
                                  child: Text(
                                    AppLocalizations.of(context)!.patient,
                                    style: AppTextStyles.getText2(context).copyWith(color: AppColors.blackText, fontWeight: FontWeight.bold),
                                  ),
                                ),

                                // 🔹 Patient Name
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
                                  child: Row(
                                    children: [
                                      Icon(Icons.person, color: AppColors.main, size: 18.sp),
                                      SizedBox(width: 12.w),
                                      Text(
                                        (appointment['patientName'] ?? "Unknown").toUpperCase(), // ✅ Convert to uppercase
                                          style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),

                                // 🔹 Full-width Divider
                                Divider(height: 1.h,  color: Colors.grey[300]),

                                // 🔹 Share Appointment Button
                                InkWell(
                                  onTap: () {
                                    _shareAppointmentDetails(); // ✅ Trigger the share
                                  },
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(12.r),
                                    bottomRight: Radius.circular(12.r),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                                    child: Row(
                                      children: [
                                        Icon(Icons.share, color: AppColors.main, size: 14),
                                        const SizedBox(width: 10),
                                        Text(
                                          AppLocalizations.of(context)!.shareAppointmentDetails,
                                          style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp,color: AppColors.main, fontWeight: FontWeight.w600),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 12.sp),                                ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),


                          // Clinic Details
                          SizedBox(height: 8.h),
                          Card(
                            color: AppColors.background2, // ✅ Light background
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0, // ✅ No shadow
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 🔹 Title "Details of the healthcare facility"
                                Padding(
                                  padding: const EdgeInsets.only(left: 16, top: 20, right: 16, bottom: 10),
                                  child: Text(
                                    AppLocalizations.of(context)!.clinicDetails,
                                    style: AppTextStyles.getText2(context).copyWith(color: AppColors.blackText, fontWeight: FontWeight.bold),
                                  ),
                                ),

                                // 🔹 Clinic Name & Address
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.location_on, color: AppColors.main, size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              appointment['clinicName'] ?? AppLocalizations.of(context)!.clinicNotAvailable,
                                              style: AppTextStyles.getText2(context).copyWith(color: AppColors.blackText, fontWeight: FontWeight.bold),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              formattedAddress.isNotEmpty ? formattedAddress : AppLocalizations.of(context)!.addressNotEntered,
                                              style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp, color: Colors.black54, fontWeight: FontWeight.w500),
                                            ),

                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // 🔹 Open Map Button
                                InkWell(
                                  onTap: () => _openMaps("${clinicAddress['street'] ?? ''}, ${clinicAddress['buildingNr'] ?? ''}, ${clinicAddress['city'] ?? ''}, ${clinicAddress['country'] ?? ''}"),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(12.r),
                                    bottomRight: Radius.circular(12.r),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.only(left: 40.w, right: 40.w, bottom: 20.h),
                                    child: Row(
                                      children: [
                                        Icon(Icons.location_on, color: AppColors.main, size: 14.sp),
                                        SizedBox(width: 5.w),
                                        Text(
                                            AppLocalizations.of(context)!.openMap,
                                          style: AppTextStyles.getText2(context).copyWith(color: AppColors.main, fontWeight: FontWeight.w600),

                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 8.h),

                          // Back to Doctor Profile
                          Card(
                            color: Colors.white, // ✅ Light background
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0, // ✅ No shadow
                            child: Column(
                              children: [
                                InkWell(
                                  onTap: () => _addToCalendar(context),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_month_outlined, color: AppColors.main, size: 16.sp),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Text(
                                            AppLocalizations.of(context)!.addToCalendar,
                                            style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp,color: AppColors.main, fontWeight: FontWeight.bold),

                                          ),
                                        ),

                                      ],
                                    ),
                                  ),
                                ),
                                Divider(color: Colors.grey[200],height: 2.h), // 🔹 Set a fixed height for the divider
                                InkWell(
                                  // In AppointmentDetailsPage (onTap for navigation)
                                  onTap: () {
                                    final doctorId = appointment['doctorId']?.toString() ?? '';

                                    print("🚀 Navigating to DoctorProfilePage with doctorId: '$doctorId'");

                                    if (doctorId.isEmpty) {
                                      print("❌ ERROR: doctorId is missing or empty.");
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(AppLocalizations.of(context)!.doctorIdMissingError)),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        fadePageRoute(
                                          DoctorProfilePage(doctorId: doctorId),
                                        ),
                                      );
                                    }
                                  },

                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                                    child: Row(
                                      children: [
                                        Icon(Icons.account_box_outlined, color: AppColors.main, size: 16.sp),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Text(
                                            AppLocalizations.of(context)!.backToDoctorProfile(doctorName),
                                            style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp,color: AppColors.main, fontWeight: FontWeight.bold),
                                          ),
                                        ),

                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20.h),



                        ],
                      ),
                    ),
                  ],
                ),
                            ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                color: Color.lerp(AppColors.mainDark, Colors.black, 0.3), // ✅ يزيد قتامة بنسبة 20%
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start, // ✅ Center content
                  children: [
                    Icon(Icons.calendar_today, color: Colors.white, size: 14.sp),
                    SizedBox(width: 12.w),
                    Text(
                      formattedDate,
                        style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    SizedBox(width: 25.w),
                    Icon(Icons.access_time, color: Colors.white, size: 14.sp),
                    SizedBox(width: 8.w),
                    Text(
                      formattedTime,
                      style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp, fontWeight: FontWeight.w600, color: Colors.white),
                    ),

                  ],
                ),
              ),]
          ),
        ),
      ),
    );
  }
}


class DoctorAppointmentsBottomSheet extends StatelessWidget {
  final PatientProfile patientProfile;
  final AppointmentDetails appointmentDetails;
  final String oldAppointmentId;
  final Timestamp oldTimestamp;

  const DoctorAppointmentsBottomSheet({
    Key? key,
    required this.patientProfile,
    required this.appointmentDetails,
    required this.oldAppointmentId,
    required this.oldTimestamp,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: BlocBuilder<DoctorScheduleCubit, DoctorScheduleState>(
        builder: (context, state) {
          if (state is DoctorScheduleLoading) {
            return Column(
              children: List.generate(7, (index) => Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: ShimmerWidget(
                  width: double.infinity,
                  height: 40.h,
                  radius: 12.r,
                ),
              )),
            );
          } else if (state is DoctorScheduleLoaded) {
            final appointments = state.appointments.entries.toList();
            final maxDates = state.maxDisplayedDates;
            final displayed = appointments.take(maxDates).toList();

            return Column(
              children: [
                Text(
                  AppLocalizations.of(context)!.availableAppointments,
                  style: AppTextStyles.getTitle1(context),
                ),
                SizedBox(height: 20.h),
                Expanded(
                  child: ListView.builder(
                    itemCount: displayed.length,
                    itemBuilder: (context, index) {
                      final date = displayed[index].key;
                      final times = displayed[index].value;
                      final isExpanded = state.expandedDates.contains(date);

                      return Column(
                        children: [
                          SizedBox(height: 12.h),
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(color: AppColors.main.withOpacity(0.10), blurRadius: 5, spreadRadius: 2),
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
                                      Text(date, style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp)),
                                      Icon(
                                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                        color: AppColors.main,
                                        size: 20.sp,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isExpanded) ...[
                                  Divider(color: Colors.grey.shade300),
                                  Wrap(
                                    spacing: 10.w,
                                    runSpacing: 10.h,
                                    children: times.map((slot) {
                                      return GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              fadePageRoute(RescheduleConfirmationPage(
                                                oldAppointment: appointmentDetails,
                                                newAppointment: AppointmentDetails(
                                                  doctorId: appointmentDetails.doctorId,
                                                  doctorName: appointmentDetails.doctorName,
                                                  doctorGender: appointmentDetails.doctorGender,
                                                  doctorTitle: appointmentDetails.doctorTitle,
                                                  specialty: appointmentDetails.specialty,
                                                  image: appointmentDetails.image,
                                                  patientName: appointmentDetails.patientName,
                                                  patientGender: appointmentDetails.patientGender,
                                                  patientAge: appointmentDetails.patientAge,
                                                  newPatient: appointmentDetails.newPatient,
                                                  reason: appointmentDetails.reason,
                                                  clinicName: appointmentDetails.clinicName,
                                                  clinicAddress: appointmentDetails.clinicAddress,
                                                ),
                                                oldAppointmentId: oldAppointmentId,
                                                oldTimestamp: oldTimestamp,
                                                newAppointmentId: slot['id'],
                                                newTimestamp: slot['timestamp'],
                                              )),
                                            );
                                          },


                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
                                          decoration: BoxDecoration(
                                            color: AppColors.main.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8.r),
                                          ),
                                          child: Text(
                                            slot['time'],
                                            style: AppTextStyles.getText2(context).copyWith(
                                              color: AppColors.main,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
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
    );
  }
}
