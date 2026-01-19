import 'dart:convert';

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:docsera/Business_Logic/Available_appointments_page/doctor_schedule_cubit.dart';
import 'package:docsera/models/appointment_details.dart';
import 'package:docsera/models/patient_profile.dart';
import 'package:docsera/screens/doctors/appointment/select_patient_page.dart';
import 'package:docsera/screens/home/appointment/reschedule_confirmation_page.dart';
import 'package:docsera/screens/home/appointment/send_document.dart';
import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/utils/time_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/document.dart'; // 👈
import 'package:docsera/screens/home/Document/document_preview_page.dart'; // 👈

import '../../../app/text_styles.dart';
import 'appointment_cancel_confirmation.dart' show AppointmentCancelledPage;
import 'package:docsera/screens/home/health/pages/visit_reports/visit_report_model.dart'; // 👈
import 'package:docsera/screens/home/health/pages/visit_reports/VisitReportDetailsPage.dart'; // 👈


class AppointmentDetailsPage extends StatefulWidget {

  final Map<String, dynamic> appointment;
  final bool isUpcoming; // 🔹 New flag to differentiate


  const AppointmentDetailsPage({
    super.key,
    required this.appointment,
    required this.isUpcoming, // Defaults to false (for past appointments)
  });

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

  Future<void> _openMaps(BuildContext context, Map<String, dynamic> appt) async {
    try {
      debugPrint("🌍 [OpenMaps] Full appointment object: $appt");

      // جرّب قراءة location (ممكن تكون String أو Map)
      dynamic rawLoc = appt['location'] ?? appt['clinicLocation'];
      debugPrint("🌍 [OpenMaps] rawLoc = $rawLoc (${rawLoc?.runtimeType})");

      Map<String, dynamic>? loc;
      if (rawLoc is String) {
        try {
          loc = Map<String, dynamic>.from(jsonDecode(rawLoc));
          debugPrint("✅ [OpenMaps] Decoded location from String → $loc");
        } catch (e) {
          debugPrint("❌ [OpenMaps] Failed to decode location JSON: $e");
        }
      } else if (rawLoc is Map) {
        loc = Map<String, dynamic>.from(rawLoc);
        debugPrint("✅ [OpenMaps] Location is already a Map → $loc");
      }

      // إذا عندنا lat/lng → افتح مباشرة
      if (loc != null && loc['lat'] != null && loc['lng'] != null) {
        final lat = loc['lat'];
        final lng = loc['lng'];
        debugPrint("📍 [OpenMaps] Using coordinates → lat=$lat, lng=$lng");

        final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
        debugPrint("🌐 [OpenMaps] Launching URI = $uri");

        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && context.mounted) {
          debugPrint("❌ [OpenMaps] Could not open Google Maps with coords");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تعذر فتح الخرائط")),
          );
        }
      } else {
        debugPrint("⚠️ [OpenMaps] No valid coordinates found, fallback to address");

        // fallback على العنوان النصي إذا ما في إحداثيات
        final addr = (appt['clinic_address'] ?? appt['clinicAddress'] ?? '').toString();
        debugPrint("🏠 [OpenMaps] Raw address = $addr");

        if (addr.trim().isEmpty) {
          debugPrint("❌ [OpenMaps] No address available to open");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("لا يوجد عنوان متاح")),
          );
          return;
        }

        final uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}',
        );
        debugPrint("🌐 [OpenMaps] Launching fallback URI = $uri");

        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && context.mounted) {
          debugPrint("❌ [OpenMaps] Could not open Google Maps with address");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("تعذر فتح الخرائط: $addr")),
          );
        }
      }
    } catch (e, st) {
      debugPrint("❌ [OpenMaps] Exception: $e\n$st");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("خطأ أثناء فتح الخرائط")),
        );
      }
    }
  }


  void _addToCalendar(BuildContext context, {int clinicOffsetMinutes = 180}) {
    final appt = widget.appointment;

    // 1) نقرأ الـ timestamp كـ UTC
    final tsUtc = DateTime.parse(appt['timestamp'].toString()).toUtc();

    // 2) نحسب "الوقت الجداري" للعيادة (UTC + offset)، ثم نبني DateTime محلي (بدون تحويل منطقة الجهاز)
    final clinicWall = tsUtc.add(Duration(minutes: clinicOffsetMinutes));
    final startLocal = TimezoneUtils.toDamascus(tsUtc);


    // 3) مدة الجلسة (افتراضي 30 دقيقة)
    final duration = (appt['durationMinutes'] is int)
        ? appt['durationMinutes'] as int
        : 30;
    final endLocal = startLocal.add(Duration(minutes: duration));

    // 4) العنوان (يدعم clinicAddress و clinic_address)
    final addr = (appt['clinicAddress'] ?? appt['clinic_address'] ?? const {}) as Map<String, dynamic>;
    final location = [
      addr['street']?.toString(),
      addr['buildingNr']?.toString(),
      addr['city']?.toString(),
      addr['country']?.toString(),
    ].where((s) => (s ?? '').toString().trim().isNotEmpty).join(', ');

    // 5) اسم الطبيب (camel/snake)
    final doctorName = [
      (appt['doctorTitle'] ?? appt['doctor_title'] ?? '').toString().trim(),
      (appt['doctorName']  ?? appt['doctor_name']  ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    // 6) نصوص إضافية
    final clinicName = ((appt['clinicName'] ?? appt['clinic']) ?? '').toString().trim();
    final reasonText = (appt['reason'] ?? AppLocalizations.of(context)!.notSpecified).toString();

    // 7) بناء الحدث (عنوان بالعربية عبر appointmentWithLabel)
    final event = Event(
      title: AppLocalizations.of(context)!.appointmentWithLabel(doctorName).trim(),
      description:
      "${AppLocalizations.of(context)!.clinicDetails}: "
          "${clinicName.isNotEmpty ? clinicName : AppLocalizations.of(context)!.clinicNotAvailable}\n"
          "${AppLocalizations.of(context)!.reasonForAppointment}: $reasonText",
      location: location,
      startDate: startLocal,
      endDate: endLocal,
      allDay: false,
    );

    // 8) الإضافة + إشعار
    Add2Calendar.addEvent2Cal(event).then((success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? AppLocalizations.of(context)!.appointmentAddedToCalendar
                : AppLocalizations.of(context)!.appointmentFailedToAdd,
          ),
        ),
      );
    });
  }

  void _shareAppointmentDetails({Rect? sharePositionOrigin}) {
    final appt = widget.appointment;
    final locale = Localizations.localeOf(context).toString();

    final tsUtc = DateTime.parse(appt['timestamp'].toString()).toUtc();
    final tsClinic = TimezoneUtils.toDamascus(tsUtc);

    final formattedDate =
    DateFormat('EEEE, d MMMM yyyy', locale).format(tsClinic);
    final formattedTime = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: tsClinic.hour, minute: tsClinic.minute),
      alwaysUse24HourFormat: false,
    );


    final doctorName = [
      (appt['doctorTitle'] ?? appt['doctor_title'] ?? '').toString().trim(),
      (appt['doctorName']  ?? appt['doctor_name']  ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final addr = (appt['clinicAddress'] ?? appt['clinic_address'] ?? const {}) as Map<String, dynamic>;
    final formattedAddress = [
      addr['street']?.toString(),
      addr['buildingNr']?.toString(),
      addr['city']?.toString(),
      addr['country']?.toString(),
    ].where((s) => (s ?? '').toString().trim().isNotEmpty).join(', ');

    final clinicName = ((appt['clinicName'] ?? appt['clinic']) ?? '').toString().trim();
    final reasonText = (appt['reason'] ?? AppLocalizations.of(context)!.notSpecified).toString();

    final shareText = """
📅 ${AppLocalizations.of(context)!.appointmentDetails}:

👨‍⚕️ ${AppLocalizations.of(context)!.appointmentWithLabel(doctorName)} 
📍 ${AppLocalizations.of(context)!.clinicDetails}: ${clinicName.isNotEmpty ? clinicName : AppLocalizations.of(context)!.clinicNotAvailable}
🏡 ${AppLocalizations.of(context)!.address}: ${formattedAddress.isNotEmpty ? formattedAddress : AppLocalizations.of(context)!.addressNotEntered}
📅 ${AppLocalizations.of(context)!.date}: $formattedDate
🕑 ${AppLocalizations.of(context)!.appointmentTime}: $formattedTime
📝 ${AppLocalizations.of(context)!.reasonForAppointment}: $reasonText

— DocSera
""";

    Share.share(
      shareText,
      subject: "${AppLocalizations.of(context)!.appointmentWithLabel(doctorName)} ",
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Map<String, dynamic> get _appt => widget.appointment;

  String _doctorId() =>
      (_appt['doctorId'] ?? _appt['doctor_id'] ?? '').toString();

  String _appointmentId() =>
      (_appt['id'] ?? _appt['appointmentId'] ?? _appt['appointment_id'] ?? '')
          .toString();


  DateTime _tsUtc() =>
      DateTime.parse(_appt['timestamp'].toString()).toUtc();

  Future<int> _fetchCancellationDeadlineHours(String doctorId) async {
    final row = await Supabase.instance.client
        .from('doctors')
        .select('cancellation_deadline_hours')
        .eq('id', doctorId)
        .maybeSingle();
    return (row?['cancellation_deadline_hours'] as int?) ?? 24;
  }

  Future<(bool tooLate, bool shortNotice)> _computeRescheduleWindow() async {
    final tsUtc = DateTime.parse(widget.appointment['timestamp'].toString()).toUtc();
    final nowUtc = DocSeraTime.nowUtc();
    final hours = await _fetchCancellationDeadlineHours(widget.appointment['doctor_id']);
    final tooLate = nowUtc.isAfter(tsUtc.subtract(Duration(hours: hours)));
    // تعبير “إشعار قصير” اختياري (ضعف المهلة كمثال)
    final shortNotice = !tooLate && nowUtc.isAfter(tsUtc.subtract(Duration(hours: hours * 2)));
    return (tooLate, shortNotice);
  }



  bool _isTooLateToCancel({
    required DateTime tsUtc,
    required int deadlineHours,
  }) {
    final nowUtc = DocSeraTime.nowUtc();
    final lastAllowed = tsUtc.subtract(Duration(hours: deadlineHours));
    return nowUtc.isAfter(lastAllowed);
  }

// (اختياري) تنبيه "إشعار قصير"؛ هنا عرّفناه بأنه داخل ضعفي المهلة
  bool _isShortNotice({
    required DateTime tsUtc,
    required int deadlineHours,
  }) {
    final nowUtc = DocSeraTime.nowUtc();
    final borderline = tsUtc.subtract(Duration(hours: deadlineHours * 2));
    return nowUtc.isAfter(borderline) && !_isTooLateToCancel(tsUtc: tsUtc, deadlineHours: deadlineHours);
  }


  void _showRescheduleAppointmentSheet(BuildContext context) async {
    // --------- Helpers ---------
    Future<int> fetchCancellationDeadlineHours(String doctorId) async {
      final row = await Supabase.instance.client
          .from('doctors')
          .select('cancellation_deadline_hours')
          .eq('id', doctorId)
          .maybeSingle();
      return (row?['cancellation_deadline_hours'] as int?) ?? 24;
    }

    (bool, bool) computeFlags({
      required DateTime apptUtc,
      required int deadlineHours,
    }) {
      final nowUtc = DocSeraTime.nowUtc();
      final tooLate = nowUtc.isAfter(apptUtc.subtract(Duration(hours: deadlineHours)));
      final shortNotice = !tooLate &&
          nowUtc.isAfter(apptUtc.subtract(Duration(hours: deadlineHours * 2)));
      return (tooLate, shortNotice);
    }

    // --------- بيانات ---------
    final appt = widget.appointment;
    final doctorId = (appt['doctor_id'] ?? appt['doctorId'] ?? '').toString().trim();
    if (doctorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.doctorIdMissingError)),
      );
      return;
    }

    final tsUtc = DateTime.parse(appt['timestamp'].toString()).toUtc();
    final deadlineHours = await fetchCancellationDeadlineHours(doctorId);
    final (isTooLate, isShortNotice) =
    computeFlags(apptUtc: tsUtc, deadlineHours: deadlineHours);

    // --------- Too late ---------
    if (isTooLate) {
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
                    style: TextStyle(
                        color: AppColors.orangeText,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp),
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

    // --------- سبب إعادة الجدولة ---------
    bool isInvalid = false;
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setBSState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                top: 16.h,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(ctx).size.height * 0.9,
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
                                AppLocalizations.of(ctx)!.reschedule,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.getTitle1(ctx).copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.blackText,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 35.h),

                        // تحذير عند shortNotice
                        Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Image.asset('assets/images/empty_calendar.png',
                                    height: 70, width: 70),
                                Positioned(
                                  bottom: -10,
                                  right: -10,
                                  child: Icon(
                                    isShortNotice
                                        ? Icons.warning_rounded
                                        : Icons.access_time,
                                    color: isShortNotice
                                        ? AppColors.yellow.withOpacity(0.8)
                                        : AppColors.orangeText.withOpacity(0.8),
                                    size: 35,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 25.h),
                            if (isShortNotice) ...[
                              Text(
                                AppLocalizations.of(ctx)!.rescheduleWarningTitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13.sp, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 25.h),
                              Container(
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  color: AppColors.yellow.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                      color: AppColors.yellow.withOpacity(0.8)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.warning,
                                        color: Colors.brown, size: 16.sp),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppLocalizations.of(ctx)!
                                                .appointmentShortNoticeWarning,
                                            style: TextStyle(
                                                color: Colors.brown,
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            AppLocalizations.of(ctx)!
                                                .rescheduleRespectNotice,
                                            style: TextStyle(
                                                color: Colors.brown,
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 25.h),
                            ],
                          ],
                        ),

                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            AppLocalizations.of(ctx)!.rescheduleReasonQuestion,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13.sp),
                          ),
                        ),
                        SizedBox(height: 10.h),

                        TextField(
                          controller: reasonController,
                          maxLines: 3,
                          textDirection:
                          detectTextDirection(reasonController.text),
                          textAlign: getTextAlign(ctx),
                          style: AppTextStyles.getText2(ctx),
                          decoration: InputDecoration(
                            hintText:
                            AppLocalizations.of(ctx)!.typeReasonHere,
                            hintStyle: AppTextStyles.getText3(ctx).copyWith(
                                fontSize: 11.sp, color: Colors.grey),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 12.h, horizontal: 14.w),
                            filled: true,
                            fillColor: Colors.white,
                            errorText: isInvalid
                                ? AppLocalizations.of(ctx)!.reasonRequired
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.r),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.r),
                              borderSide:
                              const BorderSide(color: AppColors.main, width: 2),
                            ),
                          ),
                          onChanged: (_) => setBSState(() => isInvalid = false),
                        ),

                        const Spacer(),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.main,
                            minimumSize: const Size(double.infinity, 40),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r)),
                          ),
                          onPressed: () async {
                            if (reasonController.text.trim().isEmpty) {
                              setBSState(() => isInvalid = true);
                              return;
                            }

                            Navigator.pop(ctx);

                            final screenHeight =
                                MediaQuery.of(context).size.height;
                            final doctorScheduleCubit =
                            context.read<DoctorScheduleCubit>()
                              ..fetchDoctorAppointments(
                                doctorId,
                                context,
                                reasonId: appt['reason_id'] ?? appt['reasonId'], // ✅ تمرير السبب
                              );

                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: AppColors.background2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20.r)),
                              ),
                              builder: (_) {
                                return SizedBox(
                                  height: screenHeight * 0.9,
                                  child: BlocProvider.value(
                                    value: doctorScheduleCubit,
                                    child: DoctorAppointmentsBottomSheet(
                                      patientProfile: PatientProfile(
                                        patientId: appt['user_id'] ?? appt['userId'] ?? '',
                                        doctorId: doctorId,
                                        patientName: appt['patient_name'] ?? appt['patientName'] ?? AppLocalizations.of(context)!.unknown,
                                        patientGender: appt['user_gender'] ?? appt['userGender'] ?? '',
                                        patientAge: appt['user_age'] ?? appt['userAge'] ?? 0,
                                        patientDOB: appt['patient_dob'] ?? appt['patientDOB'] ?? '',
                                        patientPhoneNumber: appt['patient_phone'] ?? appt['patientPhoneNumber'] ?? '',
                                        patientEmail: appt['patient_email'] ?? appt['patientEmail'] ?? '',
                                        reason: appt['reason'] ?? appt['reason_text'] ?? AppLocalizations.of(context)!.notSpecified,
                                      ),
                                      appointmentDetails: AppointmentDetails(
                                        doctorId: doctorId,
                                        doctorName: appt['doctor_name'] ?? appt['doctorName'] ?? '',
                                        doctorGender: appt['doctor_gender'] ?? appt['doctorGender'] ?? '',
                                        doctorTitle: appt['doctor_title'] ?? appt['doctorTitle'] ?? '',
                                        specialty: appt['doctor_specialty'] ?? appt['specialty'] ?? '',
                                        image: appt['doctor_image'] ?? appt['doctorImage'] ?? '',
                                        patientId: appt['relative_id'] ?? appt['relativeId'] ?? appt['user_id'] ?? appt['userId'] ?? '',
                                        isRelative: (appt['relative_id'] ?? appt['relativeId']) != null,
                                        patientName: appt['patient_name'] ?? appt['patientName'] ?? AppLocalizations.of(context)!.unknown,
                                        patientGender: appt['user_gender'] ?? appt['userGender'] ?? '',
                                        patientAge: appt['user_age'] ?? appt['userAge'] ?? 0,
                                        newPatient: appt['new_patient'] ?? appt['newPatient'] ?? false,
                                        reason: appt['reason'] ?? appt['reason_text'] ?? AppLocalizations.of(context)!.notSpecified,
                                        reasonId: appt['reason_id'] ?? appt['reasonId'], // ✅ تمرير الـ id
                                        clinicName: appt['clinic'] ?? appt['clinicName'] ?? '',
                                        clinicAddress: appt['clinic_address'] ?? appt['clinicAddress'] ?? const {},
                                        location: appt['location'] ?? appt['clinicLocation'],
                                      ),
                                      oldAppointmentId: _appointmentId(),
                                      oldTimestamp: DateTime.tryParse(appt['timestamp']?.toString() ?? '') ?? DateTime.now(),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          child: Text(
                            AppLocalizations.of(ctx)!.continuing.toUpperCase(),
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.sp),
                          ),
                        ),

                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            AppLocalizations.of(ctx)!.keepAppointment,
                            style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.sp),
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

  void _showCancelAppointmentSheet(BuildContext context) async {
    final doctorId = _doctorId();
    final apptId = _appointmentId();
    debugPrint("🧨 [Cancel] apptId=$_appointmentId  raw(id)=${_appt['id']}  raw(appointmentId)=${_appt['appointmentId']}");

    if (doctorId.isEmpty || apptId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.somethingWentWrong)),
      );
      return;
    }

    // 1) اجلب مهلة الإلغاء من جدول الأطباء
    final deadlineHours = await _fetchCancellationDeadlineHours(doctorId);

    // 2) احسب على UTC
    final tsUtc = _tsUtc();
    final tooLate = _isTooLateToCancel(tsUtc: tsUtc, deadlineHours: deadlineHours);
    final shortNotice = _isShortNotice(tsUtc: tsUtc, deadlineHours: deadlineHours);

    if (tooLate) {
      // ⛔️ تجاوز مهلة الإلغاء
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
                    // يمكنك تخصيص نص الترجمة لإظهار الساعات (deadlineHours)
                    // أو اكتب نصًا مباشرًا:
                    // "انتهت مهلة الإلغاء (${deadlineHours} ساعة قبل الموعد)."
                    AppLocalizations.of(context)!.tooLateToCancel,
                    style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 12.sp),
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  // مثال نص إيضاحي:
                  // "يمكن الإلغاء حتى ${deadlineHours} ساعة قبل موعدك."
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

    // 💬 تجميع السبب ثم الحذف
    bool isInvalid = false;
    final reasonController = TextEditingController();

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

                        // تحذير إشعار قصير اختياري
                        if (shortNotice) ...[
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
                                  child: Text(
                                    AppLocalizations.of(context)!.cancelRespectNotice,
                                    style: TextStyle(color: Colors.brown, fontSize: 11.sp, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 25.h),
                        ],

                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            AppLocalizations.of(context)!.cancelReasonQuestion,
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
                              borderSide: const BorderSide(color: AppColors.main, width: 2),
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

                            final currentContext = context;
                            try {
                              await _cancelAppointment(
                                currentContext,
                                appointmentId: apptId,
                                doctorId: doctorId,
                                cancelReason: reasonController.text.trim(),
                              );
                              Navigator.pop(currentContext);

                              // ✅ الذهاب لصفحة تأكيد الإلغاء
                              Navigator.pushReplacement(
                                currentContext,
                                fadePageRoute(AppointmentCancelledPage(appointment: _appt)),
                              );
                            } catch (e) {
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
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            AppLocalizations.of(context)!.keepAppointment,
                            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
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
        required String appointmentId,
        required String doctorId,
        String? cancelReason, // إن أردت تسجيل السبب في جدول آخر
      }) async {
    if (appointmentId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing appointment id')),
      );
      return;
    }

    try {
      await Supabase.instance.client.rpc(
        'cancel_appointment_by_patient',
        params: {
          'p_appointment_id': appointmentId,
        },
      );


      //
      // await Supabase.instance.client
      //     .from('appointments')
      //     .delete()
      //     .eq('id', appointmentId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.appointmentCancelled),
            backgroundColor: AppColors.red.withOpacity(0.8),
          ),
        );
      }

      // ملاحظة:
      // - إن أردت حفظ log للإلغاء (userId, doctorId, reason, timestamp...)،
      //   أنشئ جدولًا مثل appointment_cancellations وأضف له صفًا هنا.
    } catch (e) {
      debugPrint("❌ Error cancelling appointment: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.somethingWentWrong),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _appointmentAttachments() {
    final raw = widget.appointment['attachments'];

    if (raw == null) return [];

    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return [];
  }

  Widget _attachmentTile(Map<String, dynamic> att) {
    final name = att['name'] ?? 'Document';
    final type = att['file_type'] ?? '';
    final uploadDate = att['uploaded_at']?.toString().substring(0, 10) ?? '';
    final pages = att['page_count'] ?? 1;

    const icon = Icons.attach_file;

    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          const Icon(icon, color: AppColors.main, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    )),
                Text(
                  type == 'pdf' ? "$pages pages" : "Image",
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
                Text(
                  uploadDate,
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
          
          // 👁️ زر العرض (Icon)
          IconButton(
            onPressed: () => _openAttachment(att),
            icon: const Icon(Icons.visibility_outlined, 
              color: AppColors.main, 
              size: 20
            ),
            tooltip: AppLocalizations.of(context)!.view,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),

          SizedBox(width: 12.w),

          // 🗑️ زر الحذف (Icon)
          IconButton(
            onPressed: () => _deleteAttachment(att),
            icon: const Icon(Icons.delete_outline,
               color: AppColors.red,
               size: 20
            ),
            tooltip: AppLocalizations.of(context)!.delete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Future<void> _openAttachment(Map<String, dynamic> att) async {
    try {
      final bucket = att['bucket'] ?? 'appointments-attachments';
      final paths = List<String>.from(att['paths'] ?? []);

      if (paths.isEmpty) return;

      // 1. تحويل الـ storage paths إلى Public URLs
      final List<String> publicUrls = paths.map((p) {
        return Supabase.instance.client.storage.from(bucket).getPublicUrl(p);
      }).toList();

      // 2. تحويل الـ map إلى UserDocument (عبر المحاكاة)
      final dummyDoc = UserDocument(
        id: att['id'] ?? '',
        userId: widget.appointment['user_id'] ?? widget.appointment['userId'] ?? '',
        name: att['name'] ?? 'Attachment',
        type: 'attachment',
        fileType: att['file_type'] == 'pdf' ? 'pdf' : 'image',
        patientId: att['patient_id'] ?? '',
        previewUrl: publicUrls.first,
        pages: publicUrls,
        uploadedAt: DateTime.tryParse(att['uploaded_at'] ?? '') ?? DateTime.now(),
        uploadedById: att['uploaded_by_id'] ?? '',
        cameFromConversation: false,
      );

      // 3. فتح صفحة العرض الموحدة
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentPreviewPage(
            document: dummyDoc,
            showActions: false, // ✅ Hide menu button
          ),
        ),
      );
    } catch (e) {
      debugPrint("❌ Error opening attachment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(AppLocalizations.of(context)!.somethingWentWrong)),
      );
    }
  }

  Future<void> _deleteAttachment(Map<String, dynamic> att) async {
    final local = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        contentPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              local.deleteTheDocument,
              style: AppTextStyles.getTitle2(context),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              local.areYouSureToDelete(att['name'] ?? ''),
              style: AppTextStyles.getText2(context),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: Center(
                child: Text(
                  local.delete,
                  style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                local.cancel,
                style: AppTextStyles.getText2(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.blackText,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final supabase = Supabase.instance.client;
      final bucket = att['bucket'] ?? 'appointments-attachments';
      final paths = List<String>.from(att['paths'] ?? []);

      // 1. حذف الملفات من التخزين (اختياري، يفضل للحفاظ على النظافة)
      if (paths.isNotEmpty) {
        await supabase.storage.from(bucket).remove(paths);
      }

      // 2. حذف المرفق من عمود الـ JSONB في قاعدة البيانات عبر RPC
      await supabase.rpc('remove_appointment_attachment', params: {
        'appointment_id': _appointmentId(),
        'attachment_id_to_remove': att['id'],
      });

      // 3. تحديث الواجهة
      if (!mounted) return;
      
      final updated = await supabase
          .from("appointments")
          .select()
          .eq("id", _appointmentId())
          .single();

      setState(() {
        widget.appointment.clear();
        widget.appointment.addAll(updated);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(local.documentDeleted),
          backgroundColor: AppColors.red.withOpacity(0.9), // ✅ Red with opacity
          behavior: SnackBarBehavior.floating, // Optional: makes it look better
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

    } catch (e) {
      debugPrint("❌ Remove attachment error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Short alias
    final appt = widget.appointment;

    debugPrint(
        'clinicName=${appt['clinicName']} (${appt['clinicName']?.runtimeType}) | '
            'clinic=${appt['clinic']} (${appt['clinic']?.runtimeType}) | '
            'clinic_name=${appt['clinic_name']} (${appt['clinic_name']?.runtimeType})'
    );

    // --- Locale ---
    final String locale = Localizations.localeOf(context).toString();

    final DateTime tsUtc = DateTime.parse(appt['timestamp'].toString()).toUtc();
    final DateTime tsClinic = TimezoneUtils.toDamascus(tsUtc);

    final String formattedDate =
    DateFormat('EEEE, d MMMM yyyy', locale).format(tsClinic);

    final String formattedTime = TimezoneUtils.format12hLocalized(context, tsUtc);



    // --- Clinic name ---
    final String clinicName =
    (appt['clinicName'] ?? appt['clinic'] ?? appt['clinic_name'] ?? '').toString().trim();

    // --- Clinic address: handle Map or JSON string ---
    dynamic rawAddress = appt['clinic_address'] ?? appt['clinicAddress'] ?? {};
    Map<String, dynamic> clinicAddress;
    if (rawAddress is String) {
      try {
        clinicAddress = Map<String, dynamic>.from(jsonDecode(rawAddress));
      } catch (_) {
        clinicAddress = {};
      }
    } else {
      clinicAddress = Map<String, dynamic>.from(rawAddress);
    }

    String joinNonEmpty(List<String?> parts, {String sep = ' '}) =>
        parts.where((s) => (s ?? '').trim().isNotEmpty).map((s) => s!.trim()).join(sep);

    final String line1 = joinNonEmpty([clinicAddress['street']?.toString(), clinicAddress['buildingNr']?.toString()]);
    final String line2 = joinNonEmpty([clinicAddress['city']?.toString()]);
    final String line3 = joinNonEmpty([clinicAddress['country']?.toString()]);
    final String line4 = joinNonEmpty([clinicAddress['details']?.toString()]);
    final String formattedAddress = joinNonEmpty([line1, line2, line3, line4], sep: '\n');

    // --- Doctor info ---
    final String doctorName = joinNonEmpty([
      (appt['doctorTitle'] ?? appt['doctor_title'])?.toString(),
      (appt['doctorName'] ?? appt['doctor_name'])?.toString(),
    ]);
    final specialty = (appt['specialty'] ?? appt['doctor_specialty'] ?? AppLocalizations.of(context)!.unknownSpecialty).toString();
    final patientName = (appt['patientName'] ?? appt['patient_name'] ?? AppLocalizations.of(context)!.unknown).toString();

    final String gender = (appt['doctor_gender'] ?? appt['doctorGender'] ?? '').toString().toLowerCase();
    final String titleForImage = (appt['doctor_title'] ?? appt['doctorTitle'] ?? '').toString().toLowerCase();
    final String? doctorImage = (appt['doctor_image'] ?? appt['doctorImage']) as String?;

    final imageResult = resolveDoctorImagePathAndWidget(
      doctor: {
        'doctor_image': doctorImage,
        'doctorGender': gender,
        'doctorTitle': titleForImage,
      },
      width: 40,
      height: 40,
    );
    final imageProvider = imageResult.imageProvider;
    final attachments = _appointmentAttachments();

    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.appointmentDetails,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText, fontSize: 13.sp),
      ),
      actions: [
        Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.share_outlined, color: Colors.white, size: 20.sp),
            onPressed: () {
              final box = ctx.findRenderObject() as RenderBox?;
              final rect = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
              _shareAppointmentDetails(sharePositionOrigin: rect);
            },
          ),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.background2, AppColors.mainDark, 0.06), // ✅ يزيد قتامة بنسبة 20%
        ),
        child: SafeArea(
          bottom: false, // ✅ Disable bottom safe area as requested
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
                                final doctorId = (appt['doctorId'] ?? appt['doctor_id'] ?? '').toString();

                                debugPrint("🚀 Navigating to DoctorProfilePage with doctorId: '$doctorId'");
                                debugPrint("💡 Full appointment object: $appt");

                                if (doctorId.isEmpty) {
                                  debugPrint("❌ ERROR: doctorId is missing or empty.");
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(AppLocalizations.of(context)!.doctorIdMissingError)),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    fadePageRoute(DoctorProfilePage(doctorId: doctorId)),
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
                                        specialty,
                                        style: AppTextStyles.getText2(context).copyWith(color: Colors.black54),
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

                          // 🔹 Medical Report (If Exists)
                          Builder(
                            builder: (context) {
                              final reportMap = (widget.appointment['report'] is Map) 
                                  ? widget.appointment['report'] as Map 
                                  : null;
                                  
                              final hasReport = reportMap != null && 
                                  ((reportMap['diagnosis'] != null && reportMap['diagnosis'].toString().isNotEmpty) || 
                                   (reportMap['recommendation'] != null && reportMap['recommendation'].toString().isNotEmpty));

                              if (!hasReport) return const SizedBox.shrink();

                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () {
                                       // Construct VisitReport
                                       final report = VisitReport(
                                          appointmentId: widget.appointment['id'].toString(),
                                          date: tsUtc, // using tsUtc calculated above
                                          doctorName: doctorName,
                                          doctorSpecialty: specialty,
                                          clinicName: clinicName,
                                          clinicAddress: formattedAddress,
                                          diagnosis: reportMap?['diagnosis'],
                                          recommendation: reportMap?['recommendation'],
                                          doctorGender: gender,
                                          doctorTitle: titleForImage,
                                          doctorImagePath: doctorImage,
                                       );
                                       
                                       Navigator.push(
                                         context,
                                         fadePageRoute(VisitReportDetailsPage(
                                           report: report,
                                           heroTag: 'report_${widget.appointment['id']}',
                                         )),
                                       );
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 15.h),
                                      child: Row(
                                        children: [
                                          Icon(Icons.assignment_outlined, color: AppColors.main, size: 16.sp),
                                          SizedBox(width: 15.w),
                                          Expanded(
                                            child: Text(
                                              AppLocalizations.of(context)!.health_reports_title, // "Medical Reports"
                                              style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp),
                                            ),
                                          ),
                                          Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 12.sp),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Divider(color: Colors.grey[200], height: 2),
                                ],
                              );
                            }
                          ),

                          // 🔹 Reschedule & Cancel Buttons
                          // Show only if:
                          // 1. It is in the "Upcoming" list (widget.isUpcoming)
                          // 2. Status is NOT 'done'
                          // 3. Timestamp is NOT in the past
                          if (widget.isUpcoming && 
                              (widget.appointment['status'] != 'done') && 
                              DocSeraTime.toSyria(DateTime.parse(widget.appointment['timestamp'].toString()))
                                  .isAfter(DocSeraTime.nowSyria()))
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
                                      overlayColor: WidgetStateProperty.resolveWith<Color?>(
                                            (Set<WidgetState> states) {
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
                                      overlayColor: WidgetStateProperty.resolveWith<Color?>(
                                            (Set<WidgetState> states) {
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

                          Builder(
                            builder: (context) {
                              // Logic using Syria Time
                              final tsStr = appt['timestamp']?.toString();
                              final status = appt['status']?.toString();
                              final isDone = (status == 'done');

                              bool isFuture = false;
                              if (tsStr != null) {
                                 // Timestamp is usually UTC in DB, parse safely
                                 final tsSyria = DocSeraTime.toSyria(DateTime.parse(tsStr));
                                 isFuture = tsSyria.isAfter(DocSeraTime.nowSyria());
                              }

                              // Combine conditions
                              final showSendDoc = widget.isUpcoming && !isDone && isFuture;

                              if (!showSendDoc) return const SizedBox.shrink();

                              final count = attachments.length;
                              final isLimitReached = count >= 3;
                              final color = isLimitReached ? Colors.grey : AppColors.main;
                              final textColor = isLimitReached ? Colors.grey : AppColors.main;

                              return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  elevation: 0,
                                  child: InkWell(
                                    onTap: isLimitReached ? null : () async {
                                      final result = await Navigator.push(
                                        context,
                                        fadePageRoute(
                                          SendDocumentToDoctorPage(
                                            doctorName: doctorName,
                                            appointmentId: _appointmentId(),
                                          ),
                                        ),
                                      );

                                      if (result == true) {
                                        final updated = await Supabase.instance.client
                                            .from("appointments")
                                            .select()
                                            .eq("id", _appointmentId())
                                            .single();

                                        setState(() {
                                          widget.appointment.clear();
                                          widget.appointment.addAll(updated);
                                        });
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12.r),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 18.w),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.file_open_outlined, color: color, size: 16.sp),
                                          SizedBox(width: 10.w),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      AppLocalizations.of(context)!.sendDocuments,
                                                      style: AppTextStyles.getText2(context).copyWith(
                                                        fontSize: 11.sp, 
                                                        color: textColor, 
                                                        fontWeight: FontWeight.bold
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    // 🔢 Counter
                                                    Text(
                                                      "$count/3",
                                                      style: AppTextStyles.getText3(context).copyWith(
                                                        color: isLimitReached ? AppColors.red : Colors.grey,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 4.h),
                                                Text(
                                                  isLimitReached 
                                                      ? AppLocalizations.of(context)!.maxAttachmentsReached
                                                      : AppLocalizations.of(context)!.sendDocumentsSubtitle,
                                                  style: AppTextStyles.getText3(context).copyWith(
                                                    fontWeight: FontWeight.w400, 
                                                    color: Colors.black54
                                                  ),
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
                                );
                              }
                            ),

                          // if (_selectedImageFiles.isNotEmpty) _buildPreviewAttachment(),


                          if (widget.isUpcoming) SizedBox  (height: 5.h),

                          if (attachments.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                Text(
                                  AppLocalizations.of(context)!.sentDocuments,
                                  style: AppTextStyles.getTitle1(context).copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                ...attachments.map((att) => _attachmentTile(att)),
                              ],
                            ),

                          if (attachments.isNotEmpty) SizedBox  (height: 12.h),

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
                                      doctorId: widget.appointment["doctorId"] ?? widget.appointment["doctor_id"] ?? "",
                                      doctorName: widget.appointment["doctorName"] ?? widget.appointment["doctor_name"] ?? "",
                                      doctorTitle: widget.appointment["doctorTitle"] ?? widget.appointment["doctor_title"] ?? "",
                                      doctorGender: widget.appointment["doctorGender"] ?? widget.appointment["doctor_gender"] ?? "",
                                      specialty: widget.appointment["specialty"] ?? widget.appointment["doctor_specialty"] ?? "",
                                      image: widget.appointment["doctorImage"] ?? widget.appointment["doctor_image"] ?? "",
                                      clinicName: widget.appointment['clinicName'] ?? widget.appointment['clinic'] ?? "",
                                      clinicAddress: widget.appointment['clinicAddress'] ?? widget.appointment['clinic_address'] ?? {},
                                      clinicLocation: widget.appointment['clinicLocation'] ?? widget.appointment['location'] ?? {},
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
                                        patientName.toUpperCase(),
                                        style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),

                                // 🔹 Full-width Divider
                                Divider(height: 1.h,  color: Colors.grey[300]),

                                // 🔹 Share Appointment Button
                                Builder(
                                  builder: (ctx) => InkWell(
                                    onTap: () {
                                      final box = ctx.findRenderObject() as RenderBox?;
                                      final rect = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
                                      _shareAppointmentDetails(sharePositionOrigin: rect);
                                    },
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(12.r),
                                      bottomRight: Radius.circular(12.r),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.share, color: AppColors.main, size: 14),
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
                                      const Icon(Icons.location_on, color: AppColors.main, size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              clinicName.isNotEmpty
                                                  ? clinicName
                                                  : AppLocalizations.of(context)!.clinicNotAvailable,
                                              style: AppTextStyles.getText2(context)
                                                  .copyWith(color: AppColors.blackText, fontWeight: FontWeight.bold),
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
                                  onTap: () => _openMaps(context, widget.appointment),
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
                                    final doctorId = (appt['doctorId'] ?? appt['doctor_id'] ?? '').toString();

                                    debugPrint("🚀 Navigating to DoctorProfilePage with doctorId: '$doctorId'");
                                    debugPrint("💡 Full appointment object: $appt");

                                    if (doctorId.isEmpty) {
                                      debugPrint("❌ ERROR: doctorId is missing or empty.");
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(AppLocalizations.of(context)!.doctorIdMissingError)),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        fadePageRoute(DoctorProfilePage(doctorId: doctorId)),
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
    super.key,
    required this.patientProfile,
    required this.appointmentDetails,
    required this.oldAppointmentId,
    required this.oldTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: BlocBuilder<DoctorScheduleCubit, DoctorScheduleState>(
        builder: (context, state) {
          if (state is DoctorScheduleLoading) {
            return Column(
              children: List.generate(
                7,
                    (index) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: ShimmerWidget(
                    width: double.infinity,
                    height: 40.h,
                    radius: 12.r,
                  ),
                ),
              ),
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
                            padding: EdgeInsets.symmetric(
                                vertical: 12.h, horizontal: 16.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.main.withOpacity(0.1),
                                  blurRadius: 5,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    context
                                        .read<DoctorScheduleCubit>()
                                        .toggleExpand(date);
                                  },
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        date,
                                        style: AppTextStyles.getTitle1(context)
                                            .copyWith(fontSize: 12.sp),
                                      ),
                                      Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
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
                                    children: times.map<Widget>((slot) {
                                      // ✅ نستخدم time_utils لتنسيق الوقت
                                      final tsUtc = DateTime.parse(slot['timestamp'].toString()).toUtc();
                                      final formattedTime = TimezoneUtils.format12hLocalized(context, tsUtc);


                                      return GestureDetector(
                                        onTap: () {
                                          debugPrint(
                                              "📦 clinicAddress = ${appointmentDetails.clinicAddress} (type: ${appointmentDetails.clinicAddress.runtimeType})");

                                          Navigator.push(
                                            context,
                                            fadePageRoute(
                                              RescheduleConfirmationPage(
                                                oldAppointment:
                                                appointmentDetails,
                                                newAppointment:
                                                appointmentDetails.copyWith(
                                                  doctorId: appointmentDetails
                                                      .doctorId,
                                                  doctorName: appointmentDetails
                                                      .doctorName,
                                                  doctorGender:
                                                  appointmentDetails
                                                      .doctorGender,
                                                  doctorTitle: appointmentDetails
                                                      .doctorTitle,
                                                  specialty: appointmentDetails
                                                      .specialty,
                                                  image:
                                                  appointmentDetails.image,
                                                  patientId:
                                                  appointmentDetails
                                                      .patientId,
                                                  isRelative:
                                                  appointmentDetails
                                                      .isRelative,
                                                  patientName:
                                                  appointmentDetails
                                                      .patientName,
                                                  patientGender:
                                                  appointmentDetails
                                                      .patientGender,
                                                  patientAge: appointmentDetails
                                                      .patientAge,
                                                  newPatient: appointmentDetails
                                                      .newPatient,
                                                  reason: appointmentDetails
                                                      .reason,
                                                  clinicName:
                                                  appointmentDetails
                                                      .clinicName,
                                                  clinicAddress:
                                                  appointmentDetails
                                                      .clinicAddress,
                                                ),
                                                oldAppointmentId:
                                                oldAppointmentId,
                                                oldTimestamp: oldTimestamp,
                                                newAppointmentId:
                                                slot['id'].toString(),
                                                newTimestamp: DateTime.parse(
                                                    slot['timestamp']
                                                        .toString()),
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 10.h,
                                              horizontal: 16.w),
                                          decoration: BoxDecoration(
                                            color:
                                            AppColors.main.withOpacity(0.1),
                                            borderRadius:
                                            BorderRadius.circular(8.r),
                                          ),
                                          child: Text(
                                            formattedTime,
                                            style: AppTextStyles.getText2(
                                                context)
                                                .copyWith(
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
                style: AppTextStyles.getText2(context)
                    .copyWith(color: Colors.red),
              ),
            );
          }
        },
      ),
    );
  }
}