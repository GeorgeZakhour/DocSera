import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/models/patient_profile.dart';
import 'package:docsera/screens/home/messages/write_message_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class SelectMessageReasonPage extends StatelessWidget {
  final String doctorName;
  final ImageProvider doctorImage;
  final String doctorImageUrl;
  final String doctorSpecialty;
  final PatientProfile patientProfile;
  final UserDocument? attachedDocument;

  const SelectMessageReasonPage({
    Key? key,
    required this.doctorName,
    required this.doctorImage,
    required this.doctorImageUrl,
    required this.doctorSpecialty,
    required this.patientProfile,
    this.attachedDocument,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final reasons = [
      AppLocalizations.of(context)!.reasonTestResults,
      AppLocalizations.of(context)!.reasonBill,
      AppLocalizations.of(context)!.reasonAppointment,
      AppLocalizations.of(context)!.reasonTreatmentUpdate,
      AppLocalizations.of(context)!.reasonOpeningHours,
      AppLocalizations.of(context)!.reasonContract,
      AppLocalizations.of(context)!.reasonOther,
    ];

    return BaseScaffold(
      titleAlignment: 2,
      height: 75.h,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.background2.withOpacity(0.3),
            radius: 18.r,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Image(
                image: doctorImage,
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
                AppLocalizations.of(context)!.sendMessage,
                style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp, color: AppColors.whiteText),
              ),
              Text(
                doctorName,
                style: AppTextStyles.getTitle2(context).copyWith(fontSize: 14.sp, color: AppColors.whiteText),
              ),
            ],
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.selectMessageReason,
                style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
              ),
              SizedBox(height: 10.h),
              Text(
                AppLocalizations.of(context)!.noEmergencySupport,
                style: AppTextStyles.getText2(context).copyWith(fontSize: 10.sp),
              ),
              SizedBox(height: 20.h),
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                elevation: 0,
                child: Column(
                  children: List.generate(reasons.length, (index) {
                    final reason = reasons[index];
                    return Column(
                      children: [
                        if (index > 0)
                          Divider(color: Colors.grey.shade300, thickness: 1, height: 1),
                        _buildReasonTile(context, reason),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasonTile(BuildContext context, String reason) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          fadePageRoute(
            WriteMessagePage(
              doctorName: doctorName,
              doctorImage: doctorImage,
              doctorImageUrl: doctorImageUrl,
              doctorSpecialty: doctorSpecialty,
              selectedReason: reason,
              patientProfile: patientProfile.copyWith(reason: reason),
              attachedDocument: attachedDocument,
            ),
          ),
        );
        print("Selected reason: $reason");
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 20.w),
        width: double.infinity,
        child: Text(
          reason,
          style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

}
