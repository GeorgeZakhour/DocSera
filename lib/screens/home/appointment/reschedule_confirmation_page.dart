import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/appointment_details.dart';
import 'package:docsera/screens/doctors/appointment/confirmation_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RescheduleConfirmationPage extends StatelessWidget {
  final AppointmentDetails oldAppointment;
  final AppointmentDetails newAppointment;
  final DateTime oldTimestamp;
  final DateTime newTimestamp;
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


  Future<void> _confirmReschedule(BuildContext context) async {
    print("🔁 Starting reschedule..."); // ✅ تأكيد البدء

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final userName = prefs.getString('userName') ?? "Unknown";
    if (userId == null) return;

    final bookingTimestamp = DateTime.now();

    try {
      final supabase = Supabase.instance.client;

      // ✅ إلغاء الموعد القديم
      final updateOld =await supabase
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
          .eq('id', oldAppointmentId);

      print("📝 Old update result: $updateOld");
      print("🔁 Old ID: $oldAppointmentId");

      // ✅ حجز الموعد الجديد
      final updateNew = await supabase
          .from('appointments')
          .update({
        'id': newAppointmentId,
        'user_id': userId,
        'booked': true,
        'account_name': userName,
        'patient_name': newAppointment.patientName,
        'user_gender': newAppointment.patientGender,
        'user_age': newAppointment.patientAge,
        'new_patient': newAppointment.newPatient,
        'reason': newAppointment.reason,
        'booking_timestamp': bookingTimestamp.toIso8601String(),
        'timestamp': newTimestamp.toIso8601String(),
      })
          .eq('id', newAppointmentId);

      print("📝 New update result: $updateNew");
      print("🔁 New ID: $newAppointmentId");

      await Navigator.pushReplacement(
        context,
        fadePageRoute(
          AppointmentConfirmedPage(
            appointment: {
              'doctorId': newAppointment.doctorId,
              'doctorName': newAppointment.doctorName,
              'doctorTitle': newAppointment.doctorTitle,
              'doctorGender': newAppointment.doctorGender,
              'doctor_image': newAppointment.image,
              'specialty': newAppointment.specialty,
              'clinicName': newAppointment.clinicName,
              'clinicAddress': newAppointment.clinicAddress,
              'patientName': newAppointment.patientName,
              'reason': newAppointment.reason,
              'timestamp': newTimestamp.toIso8601String(),
              'bookingTimestamp': bookingTimestamp.toIso8601String(),
            },
          ),
        ),
      );
      print("✅ Navigation triggered");

    } catch (e) {
      print('❌ Error during rescheduling: $e');
    }
  }

  Widget _buildDetail(String time, AppointmentDetails appointment, bool old, BuildContext context) {

    String gender = appointment.doctorGender.toLowerCase();
    String title = appointment.doctorTitle.toLowerCase();

    String avatarPath = (appointment.image.isNotEmpty)
        ? appointment.image
        : (title == "dr.")
        ? (gender == "female" ? 'assets/images/female-doc.png' : 'assets/images/male-doc.png')
        : (gender == "male" ? 'assets/images/male-phys.png' : 'assets/images/female-phys.png');


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
                backgroundColor: old? AppColors.yellow.withOpacity(0.2) : AppColors.main.withOpacity(0.2),
                radius: 25.r,
                backgroundImage: AssetImage(avatarPath),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${appointment.doctorTitle} ${appointment.doctorName}',
                    style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.blackText),
                  ),
                  Text(
                    appointment.specialty,
                    style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          Divider(color: Colors.grey.shade300, thickness: 1, height: 20.h),
          _buildDetailRow(Icons.person, appointment.patientName),
          _buildDetailRow(Icons.calendar_today, time),
          _buildDetailRow(Icons.location_on,
              "${appointment.clinicAddress['street']}, ${appointment.clinicAddress['city']}"),
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
    final formattedNewTime = DateFormat('EEEE, d MMMM • HH:mm', Localizations.localeOf(context).toString()).format(newTimestamp);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushAndRemoveUntil(
          context,
          fadePageRoute(const CustomBottomNavigationBar()),
              (route) => false,
        );
        return false; // يمنع الرجوع العادي
      },
      child: BaseScaffold(
        title: Text(
          AppLocalizations.of(context)!.confirmReschedule,
          style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
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
                style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp, color: Colors.black54, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6.h),
              _buildDetail(
                DateFormat('EEEE, d MMMM • HH:mm', Localizations.localeOf(context).toString()).format(oldTimestamp),
                oldAppointment,
                true,
                context,
              ),
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
                style: AppTextStyles.getText2(context).copyWith(fontSize: 11.sp, color: AppColors.main, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6.h),
              _buildDetail( formattedNewTime, newAppointment, false, context),
              SizedBox(height: 20.h),
              ElevatedButton(
                onPressed: () => _confirmReschedule(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mainDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  minimumSize: Size(double.infinity, 50.h),
                ),
                child: Text(
                  AppLocalizations.of(context)!.confirm.toUpperCase(),
                  style: AppTextStyles.getTitle1(context).copyWith(fontSize: 10.sp, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
