import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/appointment_details.dart';
import 'package:docsera/models/patient_profile.dart';
import 'package:docsera/screens/doctors/appointment/doctor_appointments_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class SelectReasonPage extends StatefulWidget {
  final PatientProfile patientProfile;
  final AppointmentDetails appointmentDetails;

  const SelectReasonPage({Key? key, required this.patientProfile, required this.appointmentDetails}) : super(key: key);

  @override
  _SelectReasonPageState createState() => _SelectReasonPageState();
}

class _SelectReasonPageState extends State<SelectReasonPage> {
  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      titleAlignment: 2,
      height: 75.h,
      title: Text(
        AppLocalizations.of(context)!.selectReasonTitle, // ✅ نص ديناميكي متعدد اللغات
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 عنوان "اختر سبب الزيارة"
            Text(
              AppLocalizations.of(context)!.selectReason,
              style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
            ),
            SizedBox(height: 15.h),

            // 🔹 خيارات الأسباب (بطاقة تحتوي على 3 خيارات مع فواصل)
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
                side: BorderSide(color: Colors.grey.shade200, width: 0.8),
              ),
              elevation: 0,
              child: Column(
                children: [
                  _buildOptionButton(context, AppLocalizations.of(context)!.initialExamination),
                  Divider(color: Colors.grey.shade300, thickness: 1, height: 1), // ✅ تقليل المسافة الفاصلة
                  _buildOptionButton(context, AppLocalizations.of(context)!.checkupFollowup),
                  Divider(color: Colors.grey.shade300, thickness: 1, height: 1), // ✅ تقليل المسافة الفاصلة
                  _buildOptionButton(context, AppLocalizations.of(context)!.acuteSymptoms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 زر لكل خيار مع حركة انتقال سلسة
  Widget _buildOptionButton(BuildContext context, String reason) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          fadePageRoute(
            DoctorAppointmentsPage(
              patientProfile: widget.patientProfile.copyWith(reason: reason),
              appointmentDetails: widget.appointmentDetails.copyWith(reason: reason),
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 20.w),
        width: double.infinity,
        child: Text(
          reason,
          style: AppTextStyles.getText2(context).copyWith(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.blackText,
          ),
          textAlign: TextAlign.start, // ✅ يجعل النص يبدأ حسب اتجاه اللغة
        ),
      ),
    );
  }
}
