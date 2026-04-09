import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/modular_report_model.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/widgets/patient_section_renderers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ModularReportDetailPage extends StatelessWidget {
  final ModularReport report;

  const ModularReportDetailPage({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final formattedDate =
        "${report.createdAt.year}-${report.createdAt.month.toString().padLeft(2, '0')}-${report.createdAt.day.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: AppColors.background3,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, t),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDoctorHeader(context, formattedDate),
                    SizedBox(height: 16.h),
                    ...report.sections.map((section) =>
                        PatientSectionRenderers.render(section)),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, AppLocalizations t) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.background3,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              t.health_report_details_title,
              textAlign: TextAlign.center,
              style: AppTextStyles.getTitle3(),
            ),
          ),
          // PDF download button placeholder
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            color: AppColors.main,
            onPressed: () {
              // PDF download to be implemented when patient-side PDF service is added
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorHeader(BuildContext context, String date) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Doctor avatar
          CircleAvatar(
            radius: 24.r,
            backgroundColor: AppColors.main.withValues(alpha: 0.1),
            backgroundImage: report.doctorImage != null
                ? NetworkImage(report.doctorImage!)
                : null,
            child: report.doctorImage == null
                ? Icon(Icons.person, color: AppColors.main, size: 24.sp)
                : null,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.doctorName ?? '',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (report.doctorSpecialty != null)
                  Text(
                    report.doctorSpecialty!,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                SizedBox(height: 4.h),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade500,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
