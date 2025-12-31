import 'dart:ui';

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/pdf/visit_report_pdf_generator.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'visit_report_model.dart';

class VisitReportDetailsPage extends StatelessWidget {
  final VisitReport report;
  final String heroTag;

  const VisitReportDetailsPage({
    super.key,
    required this.report,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final formattedDate =
        "${report.date.year}-${report.date.month.toString().padLeft(2, "0")}-${report.date.day.toString().padLeft(2, "0")}";

    return Scaffold(
      backgroundColor: AppColors.background3,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDoctorHeader(context, formattedDate),
                    SizedBox(height: 16.h),

                    if (_hasMainContent)
                      _glassSection(
                        context,
                        title: t.health_report_section_summary,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_valid(report.diagnosis))
                              _field(
                                context,
                                t.health_report_diagnosis,
                                report.diagnosis!,
                              ),
                            if (_valid(report.recommendation))
                              Padding(
                                padding: EdgeInsets.only(top: 12.h),
                                child: _field(
                                  context,
                                  t.health_report_recommendations,
                                  report.recommendation!,
                                ),
                              ),
                          ],
                        ),
                      ),

                    if (report.clinicName != null ||
                        report.clinicAddress != null)
                      Padding(
                        padding: EdgeInsets.only(top: 14.h),
                        child: _glassSection(
                          context,
                          title: t.health_report_section_clinic,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_valid(report.clinicName))
                                _field(
                                  context,
                                  t.health_report_clinicName,
                                  report.clinicName!,
                                ),
                              if (_valid(report.clinicAddress))
                                Padding(
                                  padding: EdgeInsets.only(top: 12.h),
                                  child: _field(
                                    context,
                                    t.health_report_clinicAddress,
                                    report.clinicAddress!,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // VALIDATION HELPERS
  // =====================================================

  bool _valid(String? v) => v != null && v.trim().isNotEmpty;

  bool get _hasMainContent =>
      _valid(report.diagnosis) || _valid(report.recommendation);

  // =====================================================
  // TOP BAR (Back + Title + Print + Share)
  // =====================================================

  Widget _buildTopBar(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
          // Back Button
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(30.r),
            child: Padding(
              padding: EdgeInsets.all(6.w),
              child: Icon(
                isRtl
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.arrow_back_ios_rounded,
                size: 16.sp,
                color: AppColors.mainDark,
              ),
            ),
          ),

          SizedBox(width: 8.w),

          // Title
          Text(
            t.health_reports_title,
            style: AppTextStyles.getText1(context).copyWith(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.mainDark,
            ),
          ),

          const Spacer(),

          // PRINT
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            tooltip: t.health_report_exportPdf,
            icon: Icon(
              Icons.print_rounded,
              size: 18.sp,
              color: AppColors.mainDark,
            ),
            onPressed: () async {
              final isArabic =
                  Directionality.of(context) == TextDirection.rtl;
              final bytes = await VisitReportPdfGenerator.generatePdf(
                report: report,
                t: t,
                isArabic: isRtl,
              );
              await Printing.layoutPdf(
                onLayout: (PdfPageFormat format) async => bytes,
              );
            },
          ),

          // SHARE
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            tooltip: t.health_report_sharePdf,
            icon: Icon(
              Icons.share_rounded,
              size: 18.sp,
              color: AppColors.mainDark,
            ),
            onPressed: () async {
              final isArabic =
                  Directionality.of(context) == TextDirection.rtl;
              final bytes = await VisitReportPdfGenerator.generatePdf(
                report: report,
                t: t,
                isArabic: isRtl,
              );
              await Printing.sharePdf(
                bytes: bytes,
                filename: "visit_report_${report.appointmentId}.pdf",
              );
            },
          ),
        ],
      ),
    );
  }

  // =====================================================
  // DOCTOR HEADER CARD
  // =====================================================

  Widget _buildDoctorHeader(BuildContext context, String dateText) {
    final imageResult = resolveDoctorImagePathAndWidget(
      doctor: {
        "doctor_image": report.doctorImagePath,
        "gender": report.doctorGender ?? "unknown",
        "title": report.doctorTitle ?? "",
      },
      width: 35,
      height: 35,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            border: Border.all(
              color: AppColors.main.withOpacity(0.22),
            ),
            borderRadius: BorderRadius.circular(22.r),
          ),
          child: Row(
            children: [
              Hero(
                tag: heroTag,
                child: CircleAvatar(
                  radius: 26,
                  backgroundImage: imageResult.imageProvider,
                  backgroundColor: AppColors.main.withOpacity(0.1),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.doctorName,
                      style: AppTextStyles.getText1(context).copyWith(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mainDark,
                      ),
                    ),
                    if (report.doctorSpecialty != null)
                      Text(
                        report.doctorSpecialty!,
                        style: AppTextStyles.getText3(context).copyWith(
                          fontSize: 11.sp,
                          color: AppColors.textSubColor,
                        ),
                      ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12.sp,
                          color: AppColors.mainDark.withOpacity(0.8),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          dateText,
                          style: AppTextStyles.getText3(context).copyWith(
                            fontSize: 11.sp,
                            color: AppColors.mainDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // GLASS SECTION CONTAINER
  // =====================================================

  Widget _glassSection(
      BuildContext context, {
        required String title,
        required Widget child,
      }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: AppColors.main.withOpacity(0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.getText2(context).copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 10.h),
              child,
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // FIELD LABEL + VALUE
  // =====================================================

  Widget _field(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.getText3(context).copyWith(
            fontSize: 11.sp,
            color: AppColors.grayMain,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: AppTextStyles.getText2(context).copyWith(
            fontSize: 12.sp,
            color: AppColors.mainDark,
          ),
        ),
      ],
    );
  }
}

/// =====================================================
/// PDF BUILDER FUNCTION – DOCSERA MEDICAL REPORT
/// =====================================================

