import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:docsera/Business_Logic/Available_appointments_page/doctor_schedule_cubit.dart';
import 'package:docsera/models/appointment_details.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/models/patient_profile.dart';
import 'package:docsera/screens/doctors/appointment/select_patient_page.dart';
import 'package:docsera/screens/home/appointment/reschedule_confirmation_page.dart';
import 'package:docsera/screens/home/appointment/send_document.dart';
import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

import '../../../app/text_styles.dart';
import 'appointment_cancel_confirmation.dart' show AppointmentCancelledPage;


class AppointmentDetailsPage extends StatefulWidget {

  final Map<String, dynamic> appointment;
  final bool isUpcoming; // 🔹 New flag to differentiate


  const AppointmentDetailsPage({
    Key? key,
    required this.appointment,
    required this.isUpcoming, // Defaults to false (for past appointments)
  }) : super(key: key);

  @override
  State<AppointmentDetailsPage> createState() => _AppointmentDetailsPageState();
}

class _AppointmentDetailsPageState extends State<AppointmentDetailsPage> {
  // List<File> _selectedImageFiles = [];
  // String? _pendingFileType;
  // bool _showAllAttachments = false;
  // UserDocument? _attachedDocument;
  // bool _expandedImageOverlay = false;
  // List<String> _expandedImageUrls = [];
  // int _initialImageIndex = 0;
  // bool _shouldAutoScroll = true;
  // bool _isSending = false;


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
    DateTime startTime = DateTime.parse(widget.appointment['timestamp']);
    DateTime endTime = startTime.add(Duration(minutes: 30)); // Assuming a 30 min appointment

    final Event event = Event(
      title: 'Appointment with ${widget.appointment['doctor_title'] ?? ''}${widget.appointment['doctor_name'] ?? 'Doctor'}',
      description: 'Reason: ${widget.appointment['reason'] ?? 'No reason provided'}',
      location: "${widget.appointment['clinic_address']['street'] ?? ''}, ${widget.appointment['clinic_address']['city'] ?? ''}",
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
    DateTime appointmentDate = DateTime.parse(widget.appointment['timestamp']);
    String formattedDate = DateFormat("EEEE, d MMMM yyyy").format(appointmentDate);
    String formattedTime = DateFormat("HH:mm").format(appointmentDate);

    String doctorName = "${widget.appointment['doctor_title'] ?? ''} ${widget.appointment['doctor_name'] ?? 'Doctor'}".trim();
    Map<String, dynamic> clinicAddress = widget.appointment['clinicAddress'] ?? {};

    String formattedAddress = "${clinicAddress['street'] ?? ''} ${clinicAddress['buildingNr'] ?? ''}, "
        "${clinicAddress['city'] ?? ''}, ${clinicAddress['country'] ?? ''}";

    String shareText = """
📅 **Appointment Details**:

👨‍⚕️ Doctor: $doctorName
📍 Location: ${widget.appointment['clinic'] ?? 'Clinic not specified'}
🏡 Address: $formattedAddress
📅 Date: $formattedDate
🕑 Time: $formattedTime
📝 Reason: ${widget.appointment['reason'] ?? 'No reason provided'}

Shared from DocSera App
""";

    Share.share(shareText, subject: "Appointment with $doctorName");
  }

  void _showRescheduleAppointmentSheet(BuildContext context) async {
    DateTime appointmentDate = DateTime.parse(widget.appointment['timestamp']);
    DateTime now = DateTime.now();
    Duration difference = appointmentDate.difference(now);

    final bool isTooLate = difference < const Duration(hours: 24);
    final bool isShortNotice = difference >= const Duration(hours: 24) && difference <= const Duration(hours: 48);

    // 🔍 تحقق من وجود مواعيد متاحة
    final availableSlots = await Supabase.instance.client
        .from('appointments')
        .select()
        .eq('doctor_id', widget.appointment['doctor_id'])
        .eq('booked', false)
        .gt('timestamp', DateTime.now());

    final hasAvailable = availableSlots.isNotEmpty;


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
                    const Positioned(
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
                              ..fetchDoctorAppointments(widget.appointment['doctor_id'] ?? '', context);
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
                                        patientId: widget.appointment['user_id'] ?? '',
                                        doctorId: widget.appointment['doctor_id'] ?? '',
                                        patientName: widget.appointment['patient_name'] ?? '',
                                        patientGender: widget.appointment['user_gender'] ?? '',
                                        patientAge: widget.appointment['user_age'] ?? 0,
                                        patientDOB: '',
                                        patientPhoneNumber: '',
                                        patientEmail: '',
                                        reason: widget.appointment['reason'] ?? '',
                                      ),
                                      appointmentDetails: AppointmentDetails(
                                        doctorId: widget.appointment['doctor_id'] ?? '',
                                        doctorName: widget.appointment['doctor_name'] ?? '',
                                        doctorGender: widget.appointment['doctor_gender'] ?? '',
                                        doctorTitle: widget.appointment['doctor_title'] ?? '',
                                        specialty: widget.appointment['doctor_specialty'] ?? '',
                                        image: widget.appointment['doctor_image'] ?? '',
                                        patientId: widget.appointment['relative_id'] ?? widget.appointment['user_id'] ?? '',
                                        isRelative: widget.appointment['relative_id'] != null,
                                        patientName: widget.appointment['patient_name'] ?? '',
                                        patientGender: widget.appointment['user_gender'] ?? '',
                                        patientAge: widget.appointment['user_age'] ?? 0,
                                        newPatient: widget.appointment['new_patient'] ?? false,
                                        reason: widget.appointment['reason'] ?? '',
                                        clinicName: widget.appointment['clinic'] ?? '',
                                        clinicAddress: widget.appointment['clinic_address'] ?? {},
                                      ),
                                      oldAppointmentId: widget.appointment['id'] ?? '',
                                      oldTimestamp: DateTime.parse(widget.appointment['timestamp']),
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
    DateTime appointmentDate = DateTime.parse(widget.appointment['timestamp']);
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
                                userId: widget.appointment['user_id'],
                                appointmentId: widget.appointment['id'],
                                doctorId: widget.appointment['doctor_id'],
                              );
                              Navigator.pop(currentContext);

                              // ✅ التنقل لصفحة التأكيد بعد الإلغاء
                              Navigator.pushReplacement(
                                currentContext,
                                fadePageRoute(AppointmentCancelledPage(appointment: widget.appointment)),
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
      // تحديث الموعد عند الطبيب ليصير غير محجوز
      await Supabase.instance.client
          .from('appointments')
          .update({
        'booked': false,
        'account_name': null,
        'patient_name': null,
        'user_gender': null,
        'user_age': null,
        'new_patient': null,
        'reason': null,
        'user_id': null,
        'booking_timestamp': null,
      })
          .eq('id', appointmentId);

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

  // void _showAttachmentOptions() {
  //   final local = AppLocalizations.of(context)!;
  //   final imagesCount = _selectedImageFiles .length;
  //   final isImageMode = _pendingFileType == 'image';
  //
  //   final isPdfOptionDisabled = isImageMode && imagesCount > 0;
  //   final isCameraDisabled = isImageMode && imagesCount >= 8;
  //   final isGalleryDisabled = isImageMode && imagesCount >= 8;
  //
  //   showModalBottomSheet(
  //     context: context,
  //     backgroundColor: Colors.white,
  //     shape: RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
  //     ),
  //     builder: (_) {
  //       return Padding(
  //         padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Text(
  //               local.chooseAttachmentType,
  //               style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp, color: AppColors.grayMain),
  //             ),
  //             SizedBox(height: 10.h),
  //             Divider(height: 1.h, color: Colors.grey[200]),
  //             SizedBox(height: 20.h),
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //               children: [
  //                 _buildIconAction(
  //                   iconPath: 'assets/icons/camera.svg',
  //                   label: local.takePhoto,
  //                   onTap: isCameraDisabled
  //                       ? null
  //                       : () async {
  //                     Navigator.pop(context);
  //                     final picked = await ImagePicker().pickImage(source: ImageSource.camera);
  //                     if (picked != null) {
  //                       setState(() {
  //                         _selectedImageFiles.add(File(picked.path));
  //                         _pendingFileType = 'image';
  //                         _attachedDocument = null;
  //                       });
  //                     }
  //                   },
  //                 ),
  //                 _buildIconAction(
  //                   iconPath: 'assets/icons/gallery.svg',
  //                   label: local.chooseFromLibrary2,
  //                   onTap: isGalleryDisabled
  //                       ? null
  //                       : () async {
  //                     Navigator.pop(context);
  //                     final result = await FilePicker.platform.pickFiles(
  //                       type: FileType.image,
  //                       allowMultiple: true,
  //                     );
  //                     if (result != null && result.files.isNotEmpty) {
  //                       final pickedFiles = result.files
  //                           .where((file) => file.path != null)
  //                           .map((file) => File(file.path!))
  //                           .toList();
  //
  //                       final totalFiles = _selectedImageFiles.length + pickedFiles.length;
  //                       final available = 8 - _selectedImageFiles.length;
  //                       final filesToAdd = pickedFiles.take(available).toList();
  //
  //                       setState(() {
  //                         _selectedImageFiles.addAll(filesToAdd);
  //                         _pendingFileType = 'image';
  //                         _attachedDocument = null;
  //                       });
  //                     }
  //                   },
  //                 ),
  //                 _buildIconAction(
  //                   iconPath: 'assets/icons/file.svg',
  //                   label: local.chooseFile,
  //                   onTap: isPdfOptionDisabled
  //                       ? null
  //                       : () async {
  //                     Navigator.pop(context);
  //                     final result = await FilePicker.platform.pickFiles(
  //                       type: FileType.custom,
  //                       allowedExtensions: ['pdf'],
  //                     );
  //                     if (result != null && result.files.isNotEmpty) {
  //                       final pickedFile = File(result.files.first.path!);
  //                       setState(() {
  //                         _selectedImageFiles = [pickedFile];
  //                         _pendingFileType = 'pdf';
  //                         _attachedDocument = null;
  //                       });
  //                     }
  //                   },
  //                 ),
  //               ],
  //             ),
  //             SizedBox(height: 12.h),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }
  //
  // Widget _buildIconAction({
  //   required String iconPath,
  //   required String label,
  //   required VoidCallback? onTap,
  // }) {
  //   return GestureDetector(
  //     onTap: onTap,
  //     child: Column(
  //       children: [
  //         Container(
  //           padding: EdgeInsets.all(12.r),
  //           decoration: BoxDecoration(
  //             color: onTap == null ? Colors.grey.shade200 : AppColors.main.withOpacity(0.1),
  //             shape: BoxShape.circle,
  //           ),
  //           child: SvgPicture.asset(
  //             iconPath,
  //             width: 24.sp,
  //             height: 24.sp,
  //             color: onTap == null ? Colors.grey : AppColors.main,
  //           ),
  //         ),
  //         SizedBox(height: 6.h),
  //         Text(
  //           label,
  //           style: AppTextStyles.getText3(context).copyWith(
  //             fontSize: 10.sp,
  //             color: onTap == null ? Colors.grey : Colors.black,
  //           ),
  //           textAlign: TextAlign.center,
  //         ),
  //       ],
  //     ),
  //   );
  // }
  //
  // Widget _buildPreviewAttachment() {
  //   final local = AppLocalizations.of(context)!;
  //
  //   if (_selectedImageFiles.isEmpty) return const SizedBox();
  //   final isPdf = _pendingFileType == 'pdf';
  //
  //   Widget buildBlurredContainer(Widget child) {
  //     return ClipRRect(
  //       borderRadius: BorderRadius.circular(12.r),
  //       child: BackdropFilter(
  //         filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
  //         child: Container(
  //           width: double.infinity,
  //           padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
  //           decoration: BoxDecoration(
  //             color: Colors.white.withOpacity(0.3),
  //             border: Border.all(color: AppColors.main.withOpacity(0.4)),
  //             borderRadius: BorderRadius.circular(12.r),
  //           ),
  //           child: child,
  //         ),
  //       ),
  //     );
  //   }
  //
  //   if (isPdf) {
  //     final fileName = _selectedImageFiles.first.path.split('/').last;
  //     final shortName = fileName.length > 30 ? fileName.substring(0, 27) + '...' : fileName;
  //
  //     return Padding(
  //       padding: EdgeInsets.symmetric(horizontal: 0, vertical: 6.h),
  //       child: buildBlurredContainer(
  //         Row(
  //           children: [
  //             SvgPicture.asset('assets/icons/pdf-file.svg', width: 24.sp, height: 24.sp),
  //             SizedBox(width: 10.w),
  //             Expanded(
  //               child: Text(
  //                 shortName,
  //                 style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp, color: Colors.black87),
  //                 overflow: TextOverflow.ellipsis,
  //               ),
  //             ),
  //             IconButton(
  //               icon: Icon(Icons.close, size: 18.sp, color: AppColors.main),
  //               onPressed: () {
  //                 setState(() {
  //                   _selectedImageFiles.clear();
  //                   _pendingFileType = null;
  //                 });
  //               },
  //             ),
  //           ],
  //         ),
  //       ),
  //     );
  //   }
  //
  //   final count = _selectedImageFiles.length;
  //   final imageSize = 36.w;
  //   final spacing = 6.w;
  //   final label = count == 1 ? local.attachedImage : '$count ${local.attachedImages}';
  //
  //   return Padding(
  //     padding: EdgeInsets.symmetric(horizontal: 0, vertical: 6.h),
  //     child: buildBlurredContainer(
  //       Row(
  //         crossAxisAlignment: CrossAxisAlignment.center,
  //         children: [
  //           Wrap(
  //             spacing: spacing,
  //             children: List.generate(
  //               count > 3 ? 4 : count,
  //                   (i) {
  //                 if (i == 3 && count > 4) {
  //                   return Container(
  //                     width: imageSize,
  //                     height: imageSize,
  //                     decoration: BoxDecoration(
  //                       border: Border.all(color: Colors.grey.shade300, width: 0.5),
  //                       borderRadius: BorderRadius.circular(6.r),
  //                       color: AppColors.main.withOpacity(0.15),
  //                     ),
  //                     alignment: Alignment.center,
  //                     child: Text(
  //                       '+${count - 3}',
  //                       style: AppTextStyles.getText2(context).copyWith(
  //                         fontSize: 11.sp,
  //                         color: AppColors.main,
  //                       ),
  //                     ),
  //                   );
  //                 } else {
  //                   return Container(
  //                     width: imageSize,
  //                     height: imageSize,
  //                     decoration: BoxDecoration(
  //                       border: Border.all(color: Colors.grey.shade300, width: 0.5),
  //                       borderRadius: BorderRadius.circular(6.r),
  //                     ),
  //                     child: ClipRRect(
  //                       borderRadius: BorderRadius.circular(6.r),
  //                       child: GestureDetector(
  //                         onTap: () {
  //                           print('tapped');
  //                           final filePaths = _selectedImageFiles.map((f) => f.path).toList();
  //                           _showLocalImageOverlayWithIndex(filePaths, i);
  //                         },
  //                         child: Image.file(
  //                           _selectedImageFiles[i],
  //                           fit: BoxFit.cover,
  //                         ),
  //                       ),
  //
  //                     ),
  //                   );
  //                 }
  //               },
  //             ),
  //           ),
  //           const Spacer(),
  //           Row(
  //             children: [
  //               Text(
  //                 label,
  //                 style: AppTextStyles.getText2(context).copyWith(fontSize: 10.sp, color: Colors.black87),
  //               ),
  //               SizedBox(width: 4.w),
  //               IconButton(
  //                 icon: Icon(Icons.close, size: 18.sp, color: AppColors.main),
  //                 onPressed: () {
  //                   setState(() {
  //                     _selectedImageFiles.clear();
  //                     _pendingFileType = null;
  //                   });
  //                 },
  //               ),
  //             ],
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
  //
  // void _showLocalImageOverlayWithIndex(List<String> paths, int index) {
  //   setState(() {
  //     _expandedImageUrls = paths;
  //     _initialImageIndex = index;
  //     _expandedImageOverlay = true;
  //   });
  // }
  //
  //
  // void _hideImageOverlay() {
  //   setState(() {
  //     _expandedImageOverlay = false;
  //   });
  // }


  @override
  Widget build(BuildContext context) {
    DateTime appointmentDate = DateTime.parse(widget.appointment['timestamp']);
    String locale = Localizations.localeOf(context).languageCode; // ✅ Get the current locale

// ✅ Format date normally
    String formattedDate = DateFormat("EEEE, d MMMM yyyy", locale).format(appointmentDate);

// ✅ Ensure 12-hour format with AM/PM
    String formattedTime = DateFormat("h:mm a", locale).format(appointmentDate);


    final Map<String, dynamic> clinicAddress = widget.appointment['clinic_address'] ?? {};


    String formattedAddress = "${clinicAddress['street'] ?? ''} ${clinicAddress['buildingNr'] ?? ''}\n"
        "${clinicAddress['city'] ?? ''}\n"
        "${clinicAddress['country'] ?? ''}\n"
        "${clinicAddress['details'] ?? ''}";

    // Create the doctorName variable (handles empty title)
    String doctorName = "${widget.appointment['doctor_title'] ?? ''} ${widget.appointment['doctor_name'] ?? ''}".trim();
    print("🚀🚀🚀🚀🚀🚀🚀 TEST TEST TEST: '${widget.appointment}'");

    String gender = (widget.appointment['doctor_gender'] ?? '').toLowerCase();
    String title = (widget.appointment['doctor_title'] ?? '').toLowerCase();
    String? doctorImage = widget.appointment['doctor_image'];

    final imageResult = resolveDoctorImagePathAndWidget(
      doctor: {
        'doctor_image': doctorImage,
        'gender': gender,
        'title': title,
      },
      width: 40,
      height: 40,
    );
    final imageProvider = imageResult.imageProvider;



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
                                final doctorId = widget.appointment['doctor_id']?.toString() ?? '';

                                print("🚀 Navigating to DoctorProfilePage with doctorId: '$doctorId'");
                                print("💡 Full appointment object: ${widget.appointment}");

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
                                    backgroundImage: imageProvider,
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
                                        widget.appointment['doctor_specialty'] ?? AppLocalizations.of(context)!.unknownSpecialty,
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
                                Expanded(child: Text(widget.appointment['reason'] ?? AppLocalizations.of(context)!.notSpecified,
                                     style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp))),
                              ],
                            ),
                          ),
                          Divider(color: Colors.grey[200],height: 2),

                          // 🔹 Reschedule & Cancel Buttons
                          if (widget.isUpcoming) // Show only for upcoming appointments
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
                          if (widget.isUpcoming)
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
                                    SendDocumentToDoctorPage(
                                      doctorName: doctorName, // متوفر في المتغيرات
                                    ),
                                  ),
                                );
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

                          // if (_selectedImageFiles.isNotEmpty) _buildPreviewAttachment(),


                          if (widget.isUpcoming) SizedBox  (height: 8.h),

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
                                      doctorId: widget.appointment["doctor_id"] ?? "",
                                      doctorName: widget.appointment["doctor_name"] ?? "",
                                      doctorTitle: widget.appointment["doctor_title"] ?? "",
                                      doctorGender: widget.appointment["doctor_gender"] ?? "",
                                      specialty: widget.appointment["doctor_specialty"] ?? "",
                                      image: widget.appointment["doctor_image"] ?? "",
                                      clinicName: widget.appointment['clinic'] ?? "",
                                      clinicAddress: widget.appointment['clinic_address'] ?? {},
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
                                        (widget.appointment['patient_name'] ?? "").toUpperCase(), // ✅ Convert to uppercase
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
                                              widget.appointment['clinic'] ?? AppLocalizations.of(context)!.clinicNotAvailable,
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
                                    final doctorId = widget.appointment['doctor_id']?.toString() ?? '';

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
  final DateTime oldTimestamp;

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
                                BoxShadow(color: AppColors.main.withOpacity(0.1), blurRadius: 5, spreadRadius: 2),
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
                                            print("📦 clinicAddress = ${appointmentDetails.clinicAddress} (type: ${appointmentDetails.clinicAddress.runtimeType})");

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
                                                  patientId: appointmentDetails.patientId,
                                                  isRelative: appointmentDetails.isRelative,
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
