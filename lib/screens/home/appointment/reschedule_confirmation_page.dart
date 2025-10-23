import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/appointment_details.dart';
import 'package:docsera/screens/doctors/appointment/confirmation_page.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/utils/time_utils.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RescheduleConfirmationPage extends StatelessWidget {
  final AppointmentDetails oldAppointment;
  final AppointmentDetails newAppointment;
  final DateTime oldTimestamp;   // UTC
  final DateTime newTimestamp;   // UTC
  final String oldAppointmentId;
  final String newAppointmentId;

  const RescheduleConfirmationPage({
    super.key,
    required this.oldAppointment,
    required this.newAppointment,
    required this.oldTimestamp,
    required this.newTimestamp,
    required this.oldAppointmentId,
    required this.newAppointmentId,
  });

  /// 🕒 تنسيق الوقت حسب لغة التطبيق (12h)
  String _formatDamascus12hLocalized(BuildContext context, DateTime utc) {
    return TimezoneUtils.format12hLocalized(context, utc);
  }

  Future<void> _confirmReschedule(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final userName = prefs.getString('userName') ?? "Unknown";

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.somethingWentWrong)),
      );
      return;
    }

    final supabase = Supabase.instance.client;

    // 🕓 نحفظ دائماً كـ UTC
    final DateTime nowUtc = DateTime.now().toUtc();
    final DateTime newTsUtc = newTimestamp.toUtc();

    try {
      final docRow = await supabase
          .from('doctors')
          .select('require_confirmation')
          .eq('id', newAppointment.doctorId)
          .maybeSingle();

      final bool requiresConfirmation = (docRow?['require_confirmation'] as bool?) ?? true;
      final bool isConfirmed = !requiresConfirmation;

      // 🆕 إدراج الموعد الجديد
      final insertRes = await supabase
          .from('appointments')
          .insert({
        'user_id': userId,
        'doctor_id': newAppointment.doctorId,
        'timestamp': newTsUtc.toIso8601String(),
        'booked': true,
        'patient_name': newAppointment.patientName,
        'user_gender': newAppointment.patientGender,
        'user_age': newAppointment.patientAge,
        'new_patient': newAppointment.newPatient,
        'reason_id': newAppointment.reasonId,
        'reason': newAppointment.reason,
        'clinic_address': newAppointment.clinicAddress,
        'location': newAppointment.location,
        'doctor_title': newAppointment.doctorTitle,
        'doctor_image': newAppointment.image,
        'doctor_specialty': newAppointment.specialty,
        'doctor_name': newAppointment.doctorName,
        'doctor_gender': newAppointment.doctorGender,
        'clinic': newAppointment.clinicName,
        'account_name': userName,
        'booking_timestamp': nowUtc.toIso8601String(),
        'is_docsera_user': true,
        'booked_via': 'DocSera',
        'attachments': null,
        'is_confirmed': isConfirmed,
        if (newAppointment.isRelative) 'relative_id': newAppointment.patientId,
      })
          .select()
          .single();

      final newRow = Map<String, dynamic>.from(insertRes as Map);
      final insertedApptId = (newRow['id'] ?? '').toString();

      // 🗑️ حذف الموعد القديم
      await supabase.from('appointments').delete().eq('id', oldAppointmentId);

      // 📦 تحضير البيانات للتنقل
      final navPayload = {
        'doctorId': newAppointment.doctorId,
        'doctorName': newAppointment.doctorName,
        'doctorTitle': newAppointment.doctorTitle,
        'doctorGender': newAppointment.doctorGender,
        'doctor_image': newAppointment.image,
        'specialty': newAppointment.specialty,
        'clinicName': newAppointment.clinicName,
        'clinicAddress': newAppointment.clinicAddress,
        'location': newAppointment.location,
        'patientName': newAppointment.patientName,
        'reason': newAppointment.reason,
        'timestamp': newTsUtc.toIso8601String(),
        'bookingTimestamp': nowUtc.toIso8601String(),
        'appointmentId': insertedApptId,
        'account_name': userName,
        'is_confirmed': isConfirmed,
      };

      await Navigator.pushReplacement(
        context,
        fadePageRoute(AppointmentConfirmedPage(appointment: navPayload)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.somethingWentWrong)),
      );
    }
  }

  Widget _buildDetail(
      BuildContext context,
      DateTime utc,
      AppointmentDetails appointment,
      bool old,
      ) {
    final locale = Localizations.localeOf(context).toString();
    final localTime = TimezoneUtils.toDamascus(utc);

    final dateStr = DateFormat('EEEE, d MMMM', locale).format(localTime);
    final timeStr = _formatDamascus12hLocalized(context, utc);

    final imageResult = resolveDoctorImagePathAndWidget(
      doctor: {
        'doctor_image': appointment.image,
        'gender': appointment.doctorGender,
        'title': appointment.doctorTitle,
      },
      width: 50,
      height: 50,
    );

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: old
                    ? AppColors.yellow.withOpacity(0.2)
                    : AppColors.main.withOpacity(0.2),
                radius: 25.r,
                backgroundImage: imageResult.imageProvider,
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${appointment.doctorTitle} ${appointment.doctorName}',
                    style: AppTextStyles.getTitle1(context)
                        .copyWith(color: AppColors.blackText),
                  ),
                  Text(
                    appointment.specialty,
                    style: AppTextStyles.getText2(context)
                        .copyWith(fontSize: 12.sp, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          Divider(color: Colors.grey.shade300, thickness: 1, height: 20.h),
          _buildDetailRow(Icons.person, appointment.patientName),
          _buildDetailRow(Icons.calendar_today, '$dateStr • $timeStr'),
          _buildDetailRow(
            Icons.location_on,
            "${appointment.clinicAddress['street'] ?? ''}, "
                "${appointment.clinicAddress['city'] ?? ''}",
          ),
          _buildDetailRow(Icons.local_hospital, appointment.reason),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        children: [
          Icon(icon, color: AppColors.mainDark, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.sp, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushAndRemoveUntil(
          context,
          fadePageRoute(const CustomBottomNavigationBar()),
              (route) => false,
        );
        return false;
      },
      child: BaseScaffold(
        title: Text(
          AppLocalizations.of(context)!.confirmReschedule,
          style: AppTextStyles.getTitle1(context)
              .copyWith(color: AppColors.whiteText),
        ),
        titleAlignment: 1,
        height: 75.h,
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context)!.currentAppointment,
                style: AppTextStyles.getText2(context).copyWith(
                  fontSize: 11.sp,
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6.h),
              _buildDetail(context, oldTimestamp, oldAppointment, true),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Center(
                  child: Icon(
                    isArabic ? Icons.arrow_downward : Icons.arrow_downward,
                    color: AppColors.main,
                    size: 28.sp,
                  ),
                ),
              ),
              Text(
                AppLocalizations.of(context)!.newAppointment,
                style: AppTextStyles.getText2(context).copyWith(
                  fontSize: 11.sp,
                  color: AppColors.main,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6.h),
              _buildDetail(context, newTimestamp, newAppointment, false),
              SizedBox(height: 20.h),
              ElevatedButton(
                onPressed: () => _confirmReschedule(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mainDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  minimumSize: Size(double.infinity, 50.h),
                ),
                child: Text(
                  AppLocalizations.of(context)!.confirm.toUpperCase(),
                  style: AppTextStyles.getTitle1(context)
                      .copyWith(fontSize: 10.sp, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
