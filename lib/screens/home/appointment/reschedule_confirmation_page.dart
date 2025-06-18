import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/appointment_details.dart';
import 'package:docsera/screens/doctors/appointment/confirmation_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class RescheduleConfirmationPage extends StatelessWidget {
  final AppointmentDetails oldAppointment;
  final AppointmentDetails newAppointment;
  final Timestamp oldTimestamp;
  final Timestamp newTimestamp;
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
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final userName = prefs.getString('userName') ?? "Unknown";
    if (userId == null) return;

    final bookingTimestamp = Timestamp.now();

    try {
      // ✅ إلغاء الموعد القديم
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(oldAppointment.doctorId)
          .collection('appointments')
          .doc(oldAppointmentId)
          .update({
        'booked': false,
        'accountName': null,
        'patientName': null,
        'userGender': null,
        'userAge': null,
        'newPatient': null,
        'reason': null,
        'userId': null,
        'bookingTimestamp': null,
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('appointments')
          .doc(oldAppointmentId)
          .delete();

      // ✅ حجز الموعد الجديد
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(newAppointment.doctorId)
          .collection('appointments')
          .doc(newAppointmentId)
          .update({
        'appointmentId': newAppointmentId,
        'userId': userId,
        'booked': true,
        'accountName': userName,
        'patientName': newAppointment.patientName,
        'userGender': newAppointment.patientGender,
        'userAge': newAppointment.patientAge,
        'newPatient': newAppointment.newPatient,
        'reason': newAppointment.reason,
        'bookingTimestamp': bookingTimestamp,
        'timestamp': newTimestamp,
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('appointments')
          .doc(newAppointmentId)
          .set({
        'appointmentId': newAppointmentId,
        'userId': userId,
        'booked': true,
        'doctorId': newAppointment.doctorId,
        'doctorName': newAppointment.doctorName,
        'doctorGender': newAppointment.doctorGender,
        'doctorTitle': newAppointment.doctorTitle,
        'doctorImage': newAppointment.image,
        'specialty': newAppointment.specialty,
        'clinicName': newAppointment.clinicName,
        'clinicAddress': newAppointment.clinicAddress,
        'patientName': newAppointment.patientName,
        'reason': newAppointment.reason,
        'timestamp': newTimestamp,
        'bookingTimestamp': bookingTimestamp,
      });

      Navigator.pushReplacement(
        context,
        fadePageRoute(
          AppointmentConfirmedPage(
            appointment: {
              'doctorId': newAppointment.doctorId,
              'doctorName': newAppointment.doctorName,
              'doctorTitle': newAppointment.doctorTitle,
              'doctorGender': newAppointment.doctorGender,
              'doctorImage': newAppointment.image,
              'specialty': newAppointment.specialty,
              'clinicName': newAppointment.clinicName,
              'clinicAddress': newAppointment.clinicAddress,
              'patientName': newAppointment.patientName,
              'reason': newAppointment.reason,
              'timestamp': newTimestamp.toDate().toIso8601String(),
              'bookingTimestamp': bookingTimestamp.toDate().toIso8601String(),
            },
          ),
        ),
      );
    } catch (e) {
      print('❌ Error during rescheduling: $e');
    }
  }

  Widget _buildDetail(String time, AppointmentDetails appointment, BuildContext context) {
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
                backgroundColor: Colors.grey.shade200,
                radius: 25.r,
                backgroundImage: AssetImage(appointment.image),
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
    final formattedNewTime = DateFormat('EEEE, d MMMM • HH:mm', Localizations.localeOf(context).toString()).format(newTimestamp.toDate());

    return BaseScaffold(
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
              DateFormat('EEEE, d MMMM • HH:mm', Localizations.localeOf(context).toString()).format(oldTimestamp.toDate()),
              oldAppointment,
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
            _buildDetail( formattedNewTime, newAppointment, context),
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
    );
  }
}
