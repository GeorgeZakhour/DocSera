import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/appointment_details.dart';
import 'package:docsera/models/patient_profile.dart';
import 'package:docsera/screens/doctors/appointment/select_reason_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class VisitedDoctorPage extends StatefulWidget {
  final PatientProfile patientProfile;
  final AppointmentDetails appointmentDetails;

  const VisitedDoctorPage({
    Key? key,
    required this.patientProfile,
    required this.appointmentDetails,
  }) : super(key: key);

  @override
  _VisitedDoctorPageState createState() => _VisitedDoctorPageState();
}

class _VisitedDoctorPageState extends State<VisitedDoctorPage> {
  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      titleAlignment: 2,
      height: 75.h,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.background2.withOpacity(0.3),
            radius: 18.r,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Image.asset(
                widget.appointmentDetails.image,
                width: 40.w,
                height: 40.h,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: 15.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.makeAppointment,
                  style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp,fontWeight: FontWeight.w300,color: AppColors.whiteText)
              ),
              Text(
                widget.appointmentDetails.doctorName,
                style: AppTextStyles.getTitle2(context).copyWith(fontSize: 14.sp,color: AppColors.whiteText
              ),
              ),
            ],
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 السؤال الرئيسي
            Text(
              AppLocalizations.of(context)!.haveYouVisitedBefore,
              style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
            ),
            SizedBox(height: 15.h),

            // 🔹 خيارات نعم / لا داخل نفس الكارد
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
                side: BorderSide(color: Colors.grey.shade200, width: 0.8), // ✅ حد خفيف
              ),
              elevation: 0,
              child: Column(
                children: [
                  _buildOptionButton(context, AppLocalizations.of(context)!.yes, false, true),
                  Divider(color: Colors.grey.shade200, thickness: 1, height: 1),
                  _buildOptionButton(context, AppLocalizations.of(context)!.no, true, false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 زر الاختيار (نعم / لا) مع توجيه المستخدم إلى صفحة السبب
  Widget _buildOptionButton(BuildContext context, String text, bool isNewPatient, bool isFirst) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          fadePageRoute(
            SelectReasonPage(
              patientProfile: widget.patientProfile,
              appointmentDetails: widget.appointmentDetails.copyWith(newPatient: isNewPatient),
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 20.w),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.only(
            topLeft: isFirst ? Radius.circular(12.r) : Radius.zero,
            topRight: isFirst ? Radius.circular(12.r) : Radius.zero,
          ),
        ),
        child: Text(
          text,
          style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp, fontWeight: FontWeight.w500, color: AppColors.blackText),
          textAlign: TextAlign.start, // ✅ يتبع اتجاه النص تلقائياً
        ),
      ),
    );
  }
}
