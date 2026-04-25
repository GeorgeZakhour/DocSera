import 'dart:ui';

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/modular_report_model.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/pdf/modular_report_pdf_generator.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/visit_reports_service.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/widgets/patient_section_renderers.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class ModularReportDetailPage extends StatefulWidget {
  final ModularReport report;

  const ModularReportDetailPage({
    super.key,
    required this.report,
  });

  @override
  State<ModularReportDetailPage> createState() =>
      _ModularReportDetailPageState();
}

class _ModularReportDetailPageState extends State<ModularReportDetailPage> {
  late ModularReport _report;
  bool _loadingSections = false;

  @override
  void initState() {
    super.initState();
    _report = widget.report;

    if (_report.sections.isEmpty) {
      // No sections at all — fetch the full report
      _loadFullReport();
    } else if (_report.hasHeavySections) {
      // Has sections but some are stripped placeholders — lazy-load only those
      _loadHeavySections();
    }
  }

  /// Fetch the entire report (used when list query returned no sections).
  Future<void> _loadFullReport() async {
    setState(() => _loadingSections = true);
    try {
      final full = await VisitReportsService().fetchFullReport(_report.id);
      if (full != null && mounted) {
        setState(() {
          _report = full;
          _loadingSections = false;
        });
      } else if (mounted) {
        setState(() => _loadingSections = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSections = false);
    }
  }

  /// Fetch only the heavy sections (body_map, image_comparison) and merge them
  /// into the existing lightweight sections. Non-heavy sections remain visible
  /// the entire time — only the heavy placeholders show a spinner.
  Future<void> _loadHeavySections() async {
    setState(() => _loadingSections = true);
    try {
      final heavySections =
          await VisitReportsService().fetchHeavySections(_report.id);
      if (heavySections.isEmpty || !mounted) {
        if (mounted) setState(() => _loadingSections = false);
        return;
      }

      // Build a lookup: type → full section from RPC
      final heavyByType = <String, ModularReportSection>{};
      for (final s in heavySections) {
        heavyByType[s.type] = s;
      }

      // Replace placeholders with real data
      final merged = _report.sections.map((s) {
        if (s.isHeavyPlaceholder && heavyByType.containsKey(s.type)) {
          return heavyByType[s.type]!;
        }
        return s;
      }).toList();

      setState(() {
        _report = _report.copyWithSections(merged);
        _loadingSections = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSections = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final formattedDate =
        "${_report.createdAt.year}-${_report.createdAt.month.toString().padLeft(2, '0')}-${_report.createdAt.day.toString().padLeft(2, '0')}";

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
                    if (_report.patientName != null &&
                        _report.patientName!.trim().isNotEmpty) ...[
                      SizedBox(height: 10.h),
                      _buildReportMeta(context),
                    ],
                    SizedBox(height: 14.h),
                    if (_report.sections.isEmpty && _loadingSections)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.h),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.main,
                          ),
                        ),
                      )
                    else
                      ..._report.sections.map((section) {
                        if (section.isHeavyPlaceholder && _loadingSections) {
                          return PatientSectionRenderers.renderLoading(section);
                        }
                        return PatientSectionRenderers.render(section, context);
                      }),
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
  // TOP BAR (Back + Title + Print + Share)
  // =====================================================

  Widget _buildTopBar(BuildContext context, AppLocalizations t) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
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
          Text(
            t.health_report_details_title,
            style: AppTextStyles.getText1(context).copyWith(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.mainDark,
            ),
          ),
          const Spacer(),

          // Print
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            tooltip: t.health_report_exportPdf,
            icon: Icon(
              Icons.print_rounded,
              size: 18.sp,
              color: AppColors.mainDark,
            ),
            onPressed: _loadingSections ? null : () => _printPdf(context),
          ),

          // Share
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            tooltip: t.health_report_sharePdf,
            icon: Icon(
              Icons.share_rounded,
              size: 18.sp,
              color: AppColors.mainDark,
            ),
            onPressed: _loadingSections ? null : () => _sharePdf(context),
          ),
        ],
      ),
    );
  }

  // Always use A4 for patient app — iOS/Android don't offer A5 as a print option,
  // and prescription reports already contain only the prescription section.
  PdfPageFormat get _pageFormat => PdfPageFormat.a4;

  Future<void> _printPdf(BuildContext context) async {
    final bytes = await ModularReportPdfGenerator.generatePdf(
      report: _report,
      pageFormat: _pageFormat,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    final bytes = await ModularReportPdfGenerator.generatePdf(
      report: _report,
      pageFormat: _pageFormat,
    );
    final patientName = _report.patientName ?? 'report';
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'DocSera_Report_$patientName.pdf',
    );
  }

  // =====================================================
  // DOCTOR HEADER (glassmorphism card)
  // =====================================================

  Widget _buildDoctorHeader(BuildContext context, String dateText) {
    final imageResult = resolveDoctorImagePathAndWidget(
      doctor: {
        'doctor_image': _report.doctorImage,
        'gender': _report.doctorGender ?? 'unknown',
        'title': _report.doctorTitle ?? '',
      },
      width: 35,
      height: 35,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            border: Border.all(color: AppColors.main.withOpacity(0.22)),
            borderRadius: BorderRadius.circular(22.r),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24.r,
                backgroundImage: imageResult.imageProvider,
                backgroundColor: AppColors.main.withOpacity(0.1),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _report.doctorName ?? '',
                      style: AppTextStyles.getText1(context).copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mainDark,
                      ),
                    ),
                    if (_report.doctorSpecialty != null)
                      Text(
                        _report.doctorSpecialty!,
                        style: AppTextStyles.getText3(context).copyWith(
                          fontSize: 11.sp,
                          color: AppColors.textSubColor,
                        ),
                      ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 11.sp,
                          color: AppColors.mainDark.withOpacity(0.7),
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          dateText,
                          style: AppTextStyles.getText3(context).copyWith(
                            fontSize: 10.5.sp,
                            color: AppColors.mainDark,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],
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

  // =====================================================
  // REPORT META (patient name + report ID)
  // =====================================================

  Widget _buildReportMeta(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Row(
        children: [
          Icon(Icons.person_outline_rounded,
              size: 13.sp, color: Colors.grey.shade500),
          SizedBox(width: 4.w),
          Text(
            _report.patientName!,
            style: AppTextStyles.getText3(context).copyWith(
              fontSize: 11.sp,
              color: Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          Text(
            '#${_report.id.length >= 8 ? _report.id.substring(0, 8) : _report.id}',
            style: TextStyle(
              fontSize: 9.sp,
              color: Colors.grey.shade400,
              fontFamily: 'Montserrat',
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
