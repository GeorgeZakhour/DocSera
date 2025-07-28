import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/appointment_details.dart';
import 'package:docsera/screens/doctors/appointment/confirmation_page.dart';
import 'package:docsera/screens/doctors/appointment/waiting_for_confirmation_page.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../widgets/base_scaffold.dart';

class ConfirmationPage extends StatelessWidget {
  final AppointmentDetails appointmentDetails;
  final String appointmentId;
  final DateTime appointmentTimestamp;
  final String appointmentTime;

  const ConfirmationPage({
    Key? key,
    required this.appointmentDetails,
    required this.appointmentId,
    required this.appointmentTimestamp,
    required this.appointmentTime,
  }) : super(key: key);

  Future<void> _confirmBooking(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final userName = prefs.getString('userName') ?? "";

    if (userId == null) {
      print("❌ Error: User not logged in!");
      return;
    }

    try {
      final bookingTimestamp = DateTime.now();
      final supabase = Supabase.instance.client;

      final doctorInfo = await supabase
          .from('doctors')
          .select('require_confirmation')
          .eq('id', appointmentDetails.doctorId)
          .maybeSingle();

      final requiresConfirmation = doctorInfo?['require_confirmation'] ?? true;

      await supabase.from('appointments').update({
        'user_id': userId,
        if (appointmentDetails.isRelative) 'relative_id': appointmentDetails.patientId,
        'account_name': userName,
        'patient_name': appointmentDetails.patientName,
        'user_gender': appointmentDetails.patientGender,
        'user_age': appointmentDetails.patientAge,
        'new_patient': appointmentDetails.newPatient,
        'reason': appointmentDetails.reason,
        'booking_timestamp': bookingTimestamp.toIso8601String(),
        'booked': true,
        'is_docsera_user': true,
        'booked_via': 'DocSera',
        'attachments': null,
        'doctor_image': appointmentDetails.image,
        'is_confirmed': !requiresConfirmation, // ✅ حسب الإعداد
      }).eq('id', appointmentId);

      print("📸 doctor_image used during booking = ${appointmentDetails.image}");

      // ✅ أضف الطبيب إلى قائمة visited doctors عند الحجز
      final targetTable = appointmentDetails.isRelative ? 'relatives' : 'users';
      final targetId = appointmentDetails.patientId;

// ✅ احصل على قائمة الأطباء السابقة
      final existingDoctorsResponse = await supabase
          .from(targetTable)
          .select('doctors')
          .eq('id', targetId)
          .maybeSingle();

      List<String> existingDoctors = [];

      if (existingDoctorsResponse != null &&
          existingDoctorsResponse['doctors'] is List) {
        existingDoctors = List<String>.from(existingDoctorsResponse['doctors']);
      }

// ✅ أضف الطبيب فقط إن لم يكن موجودًا مسبقًا
      if (!existingDoctors.contains(appointmentDetails.doctorId)) {
        existingDoctors.add(appointmentDetails.doctorId);

        await supabase.from(targetTable).update({
          'doctors': existingDoctors,
        }).eq('id', targetId);
      }


      if (requiresConfirmation) {
        Navigator.pushReplacement(
          context,
          fadePageRoute(WaitingForConfirmationPage(
            appointment: {
              'doctorId': appointmentDetails.doctorId,
              'doctorName': appointmentDetails.doctorName,
              'doctorTitle': appointmentDetails.doctorTitle,
              'doctorGender': appointmentDetails.doctorGender,
              'doctor_image': appointmentDetails.image,
              'specialty': appointmentDetails.specialty,
              'clinicName': appointmentDetails.clinicName,
              'clinicAddress': appointmentDetails.clinicAddress,
              'patientName': appointmentDetails.patientName,
              'reason': appointmentDetails.reason,
              'timestamp': appointmentTimestamp.toIso8601String(),
              'bookingTimestamp': bookingTimestamp.toIso8601String(),
            },
          )),
        );
        } else {
      // ✅ الانتقال إلى صفحة التأكيد
      Navigator.pushReplacement(
        context,
        fadePageRoute(
          AppointmentConfirmedPage(
            appointment: {
              'doctorId': appointmentDetails.doctorId,
              'doctorName': appointmentDetails.doctorName,
              'doctorTitle': appointmentDetails.doctorTitle,
              'doctorGender': appointmentDetails.doctorGender,
              'doctor_image': appointmentDetails.image,
              'specialty': appointmentDetails.specialty,
              'clinicName': appointmentDetails.clinicName,
              'clinicAddress': appointmentDetails.clinicAddress,
              'patientName': appointmentDetails.patientName,
              'reason': appointmentDetails.reason,
              'timestamp': appointmentTimestamp.toIso8601String(),
              'bookingTimestamp': bookingTimestamp.toIso8601String(),
            },
          ),
        ),
      );
    }
    } catch (e) {
      print("❌ Error booking appointment: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // ✅ Format Date & Time
    String formattedDateTime = DateFormat('EEEE, d MMMM • HH:mm', Localizations.localeOf(context).toString())
        .format(appointmentTimestamp);

    final imageResult = resolveDoctorImagePathAndWidget(
      doctor: {
        "doctor_image": appointmentDetails.image,
        "gender": appointmentDetails.doctorGender,
        "title": appointmentDetails.doctorTitle,
      },
      width: 40,
      height: 40,
    );
    final imageProvider = imageResult.imageProvider;


    return BaseScaffold(
      titleAlignment: 2,
      height: 75.h,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.background2.withOpacity(0.3),
                radius: 18.r,
                backgroundImage: imageProvider,
              ),
              Positioned(
                bottom: 0,
                right: isArabic ? null : 0,
                left: isArabic ? 0 : null,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: AppColors.main, width: 1),
                  ),
                  child: Icon(Icons.lock, color: AppColors.main, size: 14.sp),
                ),
              ),
            ],
          ),
          SizedBox(width: 15.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formattedDateTime, // ✅ Now shows Date & Time
                style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w700, color: AppColors.whiteText),
              ),
              SizedBox(height: 3.h,),
              Text(
                AppLocalizations.of(context)!.slotReservedFor,
                style: AppTextStyles.getText3(context).copyWith(fontWeight: FontWeight.w300, color: AppColors.whiteText),
              ),
            ],
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // ✅ Main Information Container
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300, width: 0.5), // ✅ Light thin border
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                children: [
                  _buildDoctorInfo(context),
                  Divider(color: Colors.grey.shade300, thickness: 1, height: 20.h),
                  _buildAppointmentDetails(context, formattedDateTime),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // ✅ Confirm Button
            ElevatedButton(
              onPressed: () => _confirmBooking(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainDark,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 10.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                minimumSize: Size(double.infinity, 50.w),
              ),
              child: Text(
                AppLocalizations.of(context)!.confirmAppointment.toUpperCase(),
                style: AppTextStyles.getTitle1(context).copyWith(fontSize: 10.sp, color: Colors.white),
              ),
            ),
            SizedBox(height: 15.h),

            // ✅ Note
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppColors.main.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.mainDark, size: 18.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: AppLocalizations.of(context)!.byConfirming,
                        style: AppTextStyles.getText3(context).copyWith(color: Colors.black87),
                        children: [
                          TextSpan(
                            text: AppLocalizations.of(context)!.agreeToHonor,
                            style: AppTextStyles.getText3(context).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorInfo(BuildContext context) {
    String doctorFullName = appointmentDetails.doctorTitle.isNotEmpty
        ? "${appointmentDetails.doctorTitle} ${appointmentDetails.doctorName}"
        : appointmentDetails.doctorName;

    final imageResult = resolveDoctorImagePathAndWidget(
      doctor: {
        "doctor_image": appointmentDetails.image,
        "gender": appointmentDetails.doctorGender,
        "title": appointmentDetails.doctorTitle,
      },
      width: 50,
      height: 50,
    );
    final imageProvider = imageResult.imageProvider;


    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.orange.withOpacity(0.3),
          radius: 25.r,
          backgroundImage: imageProvider,
        ),
        SizedBox(width: 12.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doctorFullName,
              style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.blackText),
            ),
            Text(
              appointmentDetails.specialty,
              style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp, color: Colors.black54),
            ),
          ],
        ),
      ],
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

  Widget _buildAppointmentDetails(BuildContext context, String formattedDateTime) {
    return Column(
      children: [
        _buildDetailRow(Icons.person, appointmentDetails.patientName),
        _buildDetailRow(Icons.calendar_today, formattedDateTime), // ✅ Date & Time shown
        _buildDetailRow(Icons.location_on, "${appointmentDetails.clinicAddress['street']}, ${appointmentDetails.clinicAddress['city']}"),
        _buildDetailRow(Icons.local_hospital, appointmentDetails.reason),
      ],
    );
  }
}
