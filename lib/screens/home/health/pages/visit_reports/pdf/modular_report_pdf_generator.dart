import 'dart:convert';
import 'dart:typed_data';

import 'package:docsera/screens/home/health/pages/visit_reports/modular_report_model.dart';
import 'package:docsera/utils/arabic_reshaper/arabic_reshaper.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates a patient-facing PDF for modular reports.
/// Mirrors the DocSera-Pro PDF design exactly:
/// Cairo (Arabic) + Montserrat (medical values), full RTL,
/// double teal rule, teal pip section headers, gray patient box.
class ModularReportPdfGenerator {
  static const _primary = PdfColor.fromInt(0xFF009092);
  static const _lightTeal = PdfColor.fromInt(0xFFE0F2F1);
  static const _text = PdfColor.fromInt(0xFF263238);
  static const _subText = PdfColor.fromInt(0xFF78909C);

  /// Reshape Arabic text for correct PDF rendering
  static String _t(String text) => reshapeArabic(text);

  static Future<Uint8List> generatePdf({
    required ModularReport report,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    // ── Fonts ──
    final cairoRegData =
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final cairoBoldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final montRegData =
        await rootBundle.load('assets/fonts/Montserrat-Regular.ttf');
    final montBoldData =
        await rootBundle.load('assets/fonts/Montserrat-Bold.ttf');
    final cairoRegular = pw.Font.ttf(cairoRegData);
    final cairoBold = pw.Font.ttf(cairoBoldData);
    final montserratRegular = pw.Font.ttf(montRegData);
    final montserratBold = pw.Font.ttf(montBoldData);

    // ── Logo ──
    pw.SvgImage? logoSvg;
    try {
      final svgString =
          await rootBundle.loadString('assets/images/docsera_main.svg');
      logoSvg = pw.SvgImage(svg: svgString);
    } catch (_) {}

    // ── Body map SVGs ──
    final bodyMapSvgs = <String, String>{};
    const bodyMapAssets = [
      'assets/images/body_map/body_front.svg',
      'assets/images/body_map/body_back.svg',
      'assets/images/body_map/full_body_anterior_female.svg',
      'assets/images/body_map/full_body_posterior_female.svg',
      'assets/images/body_map/head_face.svg',
      'assets/images/body_map/head_lateral.svg',
      'assets/images/body_map/head_posterior.svg',
      'assets/images/body_map/neck_anterior.svg',
      'assets/images/body_map/hand_palmar.svg',
      'assets/images/body_map/hand_dorsal.svg',
      'assets/images/body_map/foot_plantar.svg',
      'assets/images/body_map/foot_dorsal.svg',
      'assets/images/body_map/torso_anterior_male.svg',
      'assets/images/body_map/torso_anterior_female.svg',
      'assets/images/body_map/torso_posterior.svg',
      'assets/images/body_map/torso_lateral.svg',
      'assets/images/body_map/shoulder_anterior.svg',
      'assets/images/body_map/shoulder_posterior.svg',
      'assets/images/body_map/arm_anterior.svg',
      'assets/images/body_map/arm_posterior.svg',
      'assets/images/body_map/wrist_dorsal.svg',
      'assets/images/body_map/wrist_palmar.svg',
      'assets/images/body_map/hip_anterior.svg',
      'assets/images/body_map/hip_posterior.svg',
      'assets/images/body_map/knee_anterior.svg',
      'assets/images/body_map/knee_posterior.svg',
      'assets/images/body_map/leg_lateral.svg',
      'assets/images/body_map/leg_medial.svg',
    ];
    for (final asset in bodyMapAssets) {
      try {
        bodyMapSvgs[asset] = await rootBundle.loadString(asset);
      } catch (_) {}
    }

    // ── Doctor info ──
    var doctorName = report.doctorName ?? '';
    if (doctorName.isNotEmpty &&
        !doctorName.startsWith('د.') &&
        !doctorName.toLowerCase().startsWith('dr')) {
      doctorName = 'د. $doctorName';
    }
    final specialty = report.doctorSpecialty ?? '';
    final clinic = report.doctorClinic ?? '';
    final city = report.doctorCity ?? '';
    final doctorPhone = _extractClinicPhone(report);
    final doctorMobile = _formatMobile((report.doctorMobile ?? '').trim());
    final doctorEmail = (report.doctorEmail ?? '').trim();
    final doctorWebsite = (report.doctorWebsite ?? '').trim();
    final date =
        '${report.createdAt.year}/${report.createdAt.month.toString().padLeft(2, '0')}/${report.createdAt.day.toString().padLeft(2, '0')}';
    final patientName = report.patientName ?? 'زائر';
    final patientGender = _formatGender(report.patientGender);
    final patientAge = _calculateAge(report.patientDob);

    final isCompact = pageFormat == PdfPageFormat.a5;
    final margin = isCompact ? 15.0 : 20.0;

    final pdfTheme = pw.ThemeData.withFont(
      base: cairoRegular,
      bold: cairoBold,
      fontFallback: [cairoRegular],
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        theme: pdfTheme,
        textDirection: pw.TextDirection.rtl,
        margin: pw.EdgeInsets.all(margin),
        header: (ctx) => _buildHeader(
          logoSvg: logoSvg,
          doctorName: doctorName,
          specialty: specialty,
          clinic: clinic,
          city: city,
          phone: doctorPhone,
          mobile: doctorMobile,
          email: doctorEmail,
          website: doctorWebsite,
          cairoBold: cairoBold,
          cairoRegular: cairoRegular,
          montserratRegular: montserratRegular,
          compact: isCompact,
        ),
        footer: (ctx) => _buildFooter(
          doctorName: doctorName,
          pageNumber: ctx.pageNumber,
          totalPages: ctx.pagesCount,
          cairoBold: cairoBold,
          cairoRegular: cairoRegular,
        ),
        build: (ctx) => [
          // Meta row
          _buildMetaRow(
            reportId: report.id,
            date: date,
            cairoRegular: cairoRegular,
            montserratRegular: montserratRegular,
          ),
          // Patient info
          _buildPatientInfo(
            name: patientName,
            gender: patientGender,
            age: patientAge,
            cairoBold: cairoBold,
            cairoRegular: cairoRegular,
          ),
          pw.SizedBox(height: 10),
          // Sections
          ...report.sections.map((s) {
            final content = _renderSection(
              s,
              cairoRegular: cairoRegular,
              cairoBold: cairoBold,
              montserratRegular: montserratRegular,
              montserratBold: montserratBold,
              bodyMapSvgs: bodyMapSvgs,
            );
            if (content == null) return pw.SizedBox();
            return _wrapSection(
              s,
              content,
              cairoBold: cairoBold,
              cairoRegular: cairoRegular,
            );
          }),
        ],
      ),
    );

    return pdf.save();
  }

  // ══════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════

  static pw.Widget _buildHeader({
    pw.SvgImage? logoSvg,
    required String doctorName,
    required String specialty,
    required String clinic,
    String city = '',
    String phone = '',
    String mobile = '',
    String email = '',
    String website = '',
    required pw.Font cairoBold,
    required pw.Font cairoRegular,
    required pw.Font montserratRegular,
    bool compact = false,
  }) {
    // Build contact lines: line 1 = phone + mobile, line 2 = email + website
    final line1Parts = <String>[
      if (phone.isNotEmpty) phone,
      if (mobile.isNotEmpty && mobile != phone) mobile,
    ];
    final line2Parts = <String>[
      if (email.isNotEmpty) email,
      if (website.isNotEmpty) website,
    ];
    final contactLine1 = line1Parts.join('  |  ');
    final contactLine2 = line2Parts.join('  |  ');

    final ltrStyle = pw.TextStyle(
        font: montserratRegular, fontSize: 7, color: _subText);

    return pw.Column(children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.SizedBox(width: 1),
          if (logoSvg != null)
            pw.SizedBox(height: compact ? 8 : 10, child: logoSvg),
        ],
      ),
      pw.SizedBox(height: compact ? 4 : 6),
      pw.Center(
        child: pw.Column(children: [
          pw.Text(_t(doctorName),
              style: pw.TextStyle(
                  font: cairoBold, fontFallback: [cairoRegular],
                  fontSize: compact ? 13 : 15, color: _text)),
          if (specialty.isNotEmpty)
            pw.Text(_t(specialty),
                style: pw.TextStyle(
                    font: cairoRegular, fontSize: compact ? 8 : 9, color: _subText)),
          if (clinic.isNotEmpty || city.isNotEmpty)
            pw.Text(
                _t([clinic, city].where((e) => e.isNotEmpty).join(' · ')),
                style: pw.TextStyle(
                    font: cairoRegular, fontSize: compact ? 7.5 : 8.5, color: _subText)),
          if (contactLine1.isNotEmpty)
            pw.Text(contactLine1,
                textDirection: pw.TextDirection.ltr, style: ltrStyle),
          if (contactLine2.isNotEmpty)
            pw.Text(contactLine2,
                textDirection: pw.TextDirection.ltr, style: ltrStyle),
        ]),
      ),
      pw.SizedBox(height: compact ? 4 : 6),
      pw.Container(height: 2, color: _primary),
      pw.SizedBox(height: 2),
      pw.Container(height: 0.5, color: _primary),
    ]);
  }

  // ══════════════════════════════════════════════════════
  // META ROW
  // ══════════════════════════════════════════════════════

  static pw.Widget _buildMetaRow({
    required String reportId,
    required String date,
    required pw.Font cairoRegular,
    required pw.Font montserratRegular,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            _t('رقم التقرير: ${reportId.length >= 8 ? reportId.substring(0, 8).toUpperCase() : reportId}'),
            style: pw.TextStyle(
                font: cairoRegular, fontSize: 8, color: _subText),
          ),
          pw.Text(date,
              style: pw.TextStyle(
                  font: montserratRegular, fontSize: 8, color: _subText)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // PATIENT INFO
  // ══════════════════════════════════════════════════════

  static pw.Widget _buildPatientInfo({
    required String name,
    required String gender,
    required String age,
    required pw.Font cairoBold,
    required pw.Font cairoRegular,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF9FAFA),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE8EDED)),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _infoField('المريض', name, cairoBold, cairoRegular),
          _infoField('الجنس', gender, cairoBold, cairoRegular),
          _infoField('العمر', age, cairoBold, cairoRegular),
        ],
      ),
    );
  }

  static pw.Widget _infoField(
      String label, String value, pw.Font cairoBold, pw.Font cairoRegular) {
    return pw.Column(children: [
      pw.Text(_t(label),
          style: pw.TextStyle(
              font: cairoRegular, fontSize: 7.5, color: _subText)),
      pw.Text(_t(value),
          style:
              pw.TextStyle(font: cairoBold, fontFallback: [cairoRegular], fontSize: 9, color: _text)),
    ]);
  }

  // ══════════════════════════════════════════════════════
  // FOOTER
  // ══════════════════════════════════════════════════════

  static pw.Widget _buildFooter({
    required String doctorName,
    required int pageNumber,
    required int totalPages,
    required pw.Font cairoBold,
    required pw.Font cairoRegular,
  }) {
    final pageStr = _toArabicNumerals('$pageNumber');
    final totalStr = _toArabicNumerals('$totalPages');
    return pw.Column(children: [
      pw.Container(height: 2, color: _primary),
      pw.SizedBox(height: 8),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 20),
              pw.Container(width: 100, height: 0.5, color: _subText),
              pw.SizedBox(height: 3),
              pw.Text(_t(doctorName),
                  style: pw.TextStyle(
                      font: cairoBold, fontFallback: [cairoRegular],
                      fontSize: 9,
                      color: _text,
                      fontStyle: pw.FontStyle.italic)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(_t('تم إنشاؤه عبر دوكسيرا'),
                  style: pw.TextStyle(
                      font: cairoRegular, fontSize: 7, color: _subText)),
              pw.Text(_t('صفحة $pageStr من $totalStr'),
                  style: pw.TextStyle(
                      font: cairoRegular, fontSize: 7, color: _subText)),
            ],
          ),
        ],
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════
  // SECTION WRAPPER
  // ══════════════════════════════════════════════════════

  static const _knownLabels = <String, String>{
    'chief_complaint': 'الشكوى الرئيسية',
    'clinical_examination': 'الفحص السريري',
    'diagnosis': 'التشخيص',
    'prescriptions': 'الوصفات الطبية',
    'treatment_instructions': 'تعليمات العلاج',
    'treatment_procedures': 'الإجراءات العلاجية',
    'in_clinic_treatments': 'العلاجات في العيادة',
    'requested_exams': 'الفحوصات المطلوبة',
    'follow_up': 'المتابعة',
    'referral': 'الإحالة',
    'additional_notes': 'ملاحظات إضافية',
    'custom_text': 'قسم مخصص',
    'vitals': 'العلامات الحيوية',
    'measurements': 'القياسات',
    'scoring': 'المقياس السريري',
    'checklist': 'قائمة الفحص',
    'body_map': 'خريطة الجسم',
    'image_comparison': 'مقارنة الصور',
    'custom_table': 'جدول مخصص',
    'attachments': 'المرفقات',
  };

  static pw.Widget _wrapSection(
    ModularReportSection section,
    pw.Widget content, {
    required pw.Font cairoBold,
    required pw.Font cairoRegular,
  }) {
    final knownLabel = _knownLabels[section.type];
    final label = knownLabel ?? (section.label?.isNotEmpty == true ? section.label! : section.type);
    final header = pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(children: [
        pw.Container(width: 3, height: 12, color: _primary),
        pw.SizedBox(width: 6),
        pw.Text(_t(label),
            style: pw.TextStyle(
                font: cairoBold, fontFallback: [cairoRegular], fontSize: 13, color: _text)),
      ]),
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Keep header + content together on same page
          pw.Wrap(
            children: [
              header,
              content,
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION RENDERERS
  // ══════════════════════════════════════════════════════

  static pw.Widget? _renderSection(
    ModularReportSection section, {
    required pw.Font cairoRegular,
    required pw.Font cairoBold,
    required pw.Font montserratRegular,
    required pw.Font montserratBold,
    required Map<String, String> bodyMapSvgs,
  }) {
    if (!section.hasContent) return null;
    switch (section.type) {
      case 'chief_complaint':
      case 'additional_notes':
      case 'custom_text':
        return _plainText(section.value.toString(), cairoRegular);

      case 'clinical_examination':
      case 'treatment_instructions':
        return _bulletList(section.value, cairoRegular);

      case 'treatment_procedures':
        return _numberedList(section.value, cairoRegular, cairoBold);

      case 'diagnosis':
        return _diagnosis(section.value, cairoRegular, montserratRegular);

      case 'prescriptions':
      case 'in_clinic_treatments':
        return _prescriptions(section.value, cairoBold, cairoRegular);

      case 'requested_exams':
        return _requestedExams(section.value, cairoRegular);

      case 'follow_up':
        return _followUp(section.value, cairoBold, cairoRegular);

      case 'referral':
        return _referral(section.value, cairoBold, cairoRegular);

      case 'vitals':
        return _vitals(section, cairoBold, cairoRegular);

      case 'measurements':
        return _measurements(section, cairoBold, cairoRegular);

      case 'scoring':
        return _scoring(section.value, section.config, cairoBold, cairoRegular);

      case 'checklist':
        return _checklist(section, cairoRegular, cairoBold);

      case 'custom_table':
        return _customTable(section.value, cairoBold, cairoRegular);

      case 'body_map':
        return _renderBodyMap(section, cairoRegular, cairoBold, montserratBold, bodyMapSvgs);

      case 'image_comparison':
        return _renderImageComparison(section, cairoRegular, cairoBold);

      case 'attachments':
        return _attachments(section.value, cairoRegular);

      default:
        if (section.value is String) {
          return _plainText(section.value.toString(), cairoRegular);
        }
        return null;
    }
  }

  // ── Plain text ──

  static pw.Widget _plainText(String text, pw.Font cairoRegular) {
    return pw.Text(_t(text),
        style: pw.TextStyle(font: cairoRegular, fontSize: 10, color: _text));
  }

  // ── Bullet list ──

  static pw.Widget _bulletList(dynamic value, pw.Font cairoRegular) {
    final items = (value is List)
        ? value.map((e) => e.toString()).toList()
        : [value.toString()];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items.map((item) => _bulletItem(item, cairoRegular)).toList(),
    );
  }

  // ── Numbered list (treatment procedures) ──

  static pw.Widget _numberedList(
      dynamic value, pw.Font cairoRegular, pw.Font cairoBold) {
    // New structured format: { "items": [...] }
    if (value is Map && value['items'] is List) {
      return _structuredProcedures(value['items'] as List, cairoBold, cairoRegular);
    }
    // Legacy format: List<String>
    final items = (value is List)
        ? value.map((e) => e.toString()).toList()
        : [value.toString()];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items.asMap().entries.map((entry) {
        final num = _toArabicNumerals('${entry.key + 1}');
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 16,
                child: pw.Text('.${_t(num)}', textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    font: cairoBold, fontFallback: [cairoRegular],
                    fontSize: 10, color: _primary)),
              ),
              pw.SizedBox(width: 2),
              pw.Expanded(child: pw.Text(_t(entry.value), style: pw.TextStyle(
                font: cairoRegular, fontSize: 10, color: _text))),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Structured procedures (dental + manual) ──

  static pw.Widget _structuredProcedures(
      List items, pw.Font cairoBold, pw.Font cairoRegular) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items.asMap().entries.map((entry) {
        final item = entry.value;
        if (item is! Map) return pw.SizedBox();
        final map = Map<String, dynamic>.from(item);
        final isDental = map['source'] == 'dental';
        final num = _toArabicNumerals('${entry.key + 1}');
        final title = isDental
            ? '${map['procedure_type'] ?? ''} - ${_t('سن')} ${map['tooth_id'] ?? ''}'
            : _t((map['text'] ?? '').toString());
        final notes = (map['notes'] ?? '').toString();

        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 16,
                    child: pw.Text('.${_t(num)}', textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(
                        font: cairoBold, fontFallback: [cairoRegular],
                        fontSize: 10, color: _primary)),
                  ),
                  pw.SizedBox(width: 2),
                  pw.Expanded(child: pw.Text(_t(title), style: pw.TextStyle(
                    font: cairoBold, fontFallback: [cairoRegular], fontSize: 10, color: _text))),
                ],
              ),
              if (notes.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 20, top: 1),
                  child: pw.Text(_t(notes), style: pw.TextStyle(
                    font: cairoRegular, fontSize: 9, color: PdfColors.grey600,
                    fontStyle: pw.FontStyle.italic)),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Diagnosis ──

  static pw.Widget _diagnosis(
      dynamic value, pw.Font cairoRegular, pw.Font montserratRegular) {
    if (value is Map) {
      final text = value['text']?.toString() ?? '';
      final icd = value['icd_code']?.toString() ?? '';
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(_t(text),
                style: pw.TextStyle(
                    font: cairoRegular, fontSize: 10, color: _text)),
          ),
          if (icd.isNotEmpty) ...[
            pw.SizedBox(width: 8),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const pw.BoxDecoration(
                color: _lightTeal,
                borderRadius:
                    pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Text(icd,
                  style: pw.TextStyle(
                      font: montserratRegular,
                      fontSize: 8,
                      color: _primary)),
            ),
          ],
        ],
      );
    }
    return _plainText(value.toString(), cairoRegular);
  }

  // ── Prescriptions ──

  static pw.Widget _prescriptions(
      dynamic value, pw.Font cairoBold, pw.Font cairoRegular) {
    final items = (value is List) ? value : [];
    return pw.Column(
      children: items.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        if (item is Map) {
          final name = item['name']?.toString() ?? '';
          final dosage = item['dosage']?.toString() ?? '';
          final frequency = item['frequency']?.toString() ?? '';
          final duration = item['duration']?.toString() ?? '';
          final notes = item['notes']?.toString() ?? '';
          final num = _toArabicNumerals('${idx + 1}');

          // Detail chips: dosage, frequency, duration
          final details = <String>[
            if (dosage.isNotEmpty) dosage,
            if (frequency.isNotEmpty) frequency,
            if (duration.isNotEmpty) duration,
          ];

          return pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const pw.BoxDecoration(
              color: _lightTeal,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Medication name with number
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 16,
                      child: pw.Text('.${_t(num)}', textDirection: pw.TextDirection.rtl,
                          style: pw.TextStyle(
                              font: cairoBold, fontFallback: [cairoRegular], fontSize: 10, color: _primary)),
                    ),
                    pw.SizedBox(width: 2),
                    pw.Expanded(
                      child: pw.Text(_t(name),
                          style: pw.TextStyle(
                              font: cairoBold, fontFallback: [cairoRegular], fontSize: 10, color: _text)),
                    ),
                  ],
                ),
                if (details.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Row(
                    children: details.asMap().entries.map((d) {
                      return pw.Row(children: [
                        if (d.key > 0)
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                            child: pw.Text('·',
                                style: const pw.TextStyle(fontSize: 10, color: _subText)),
                          ),
                        pw.Text(_t(d.value),
                            style: pw.TextStyle(
                                font: cairoRegular,
                                fontSize: 8.5,
                                color: _subText)),
                      ]);
                    }).toList(),
                  ),
                ],
                if (notes.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(_t(notes),
                      style: pw.TextStyle(
                          font: cairoRegular,
                          fontSize: 8,
                          color: _subText,
                          fontStyle: pw.FontStyle.italic)),
                ],
              ],
            ),
          );
        }
        return pw.Text(_t(item.toString()),
            style: pw.TextStyle(font: cairoRegular, fontSize: 10));
      }).toList(),
    );
  }

  // ── Requested exams ──

  static pw.Widget _requestedExams(dynamic value, pw.Font cairoRegular) {
    final items = (value is List) ? value : [];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items.map((item) {
        if (item is Map) {
          final name = item['exam_name']?.toString() ??
              item['name']?.toString() ??
              '';
          final notes = item['notes']?.toString() ?? '';
          return _bulletItem(
              notes.isNotEmpty ? '$name ($notes)' : name, cairoRegular);
        }
        return _bulletItem(item.toString(), cairoRegular);
      }).toList(),
    );
  }

  // ── Follow-up ──

  static pw.Widget _followUp(
      dynamic value, pw.Font cairoBold, pw.Font cairoRegular) {
    if (value is Map) {
      final date = value['date']?.toString() ?? '';
      final time = value['time']?.toString() ?? '';
      final period = value['period']?.toString() ?? '';
      final notes = value['notes']?.toString() ?? '';
      final isBooked = value['booked'] == true;

      if (isBooked && date.isNotEmpty) {
        // Format time from 24h to 12h Arabic
        String timeDisplay = time;
        if (time.isNotEmpty) {
          final parts = time.split(':');
          if (parts.length >= 2) {
            var h = int.tryParse(parts[0]) ?? 0;
            final m = parts[1];
            final amPm = h >= 12 ? 'م' : 'ص';
            if (h == 0) {
              h = 12;
            } else if (h > 12) {
              h -= 12;
            }
            timeDisplay = '$h:$m $amPm';
          }
        }

        final bookedText = timeDisplay.isNotEmpty
            ? 'تم حجز موعد مراجعة بتاريخ $date الساعة $timeDisplay'
            : 'تم حجز موعد مراجعة بتاريخ $date';

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Container(
                  width: 14, height: 14,
                  decoration: const pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    color: _primary,
                  ),
                  child: pw.CustomPaint(
                    size: const PdfPoint(14, 14),
                    painter: (PdfGraphics canvas, PdfPoint size) {
                      canvas
                        ..setStrokeColor(PdfColors.white)
                        ..setLineWidth(1.5)
                        ..moveTo(3.5, 7)
                        ..lineTo(5.8, 4.5)
                        ..lineTo(10.5, 9.5)
                        ..strokePath();
                    },
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Text(_t(bookedText), style: pw.TextStyle(
                    font: cairoBold, fontFallback: [cairoRegular],
                    fontSize: 10, color: _text)),
                ),
              ],
            ),
            if (notes.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2, right: 20),
                child: pw.Text(_t(notes), style: pw.TextStyle(
                  font: cairoRegular, fontSize: 9, color: _subText)),
              ),
          ],
        );
      }

      // Non-booked: show date/period + notes
      final dateDisplay = date.isNotEmpty ? date : period;
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (dateDisplay.isNotEmpty)
            pw.Text(_t('الموعد: $dateDisplay'),
                style: pw.TextStyle(
                    font: cairoBold, fontFallback: [cairoRegular], fontSize: 10, color: _text)),
          if (notes.isNotEmpty)
            pw.Text(_t(notes),
                style: pw.TextStyle(
                    font: cairoRegular, fontSize: 9, color: _subText)),
        ],
      );
    }
    return _plainText(value.toString(), cairoRegular);
  }

  // ── Referral ──

  static pw.Widget _referral(
      dynamic value, pw.Font cairoBold, pw.Font cairoRegular) {
    if (value is! Map) {
      return _plainText(value?.toString() ?? '', cairoRegular);
    }
    final map = Map<String, dynamic>.from(value);
    final specialty = map['specialty_label']?.toString() ?? '';
    final doctor = map['doctor_name']?.toString() ?? '';
    final reason = map['reason']?.toString() ?? '';
    final urgency = map['urgency']?.toString() ?? 'routine';

    final urgencyLabelAr = switch (urgency) {
      'urgent' => 'عاجل',
      'emergency' => 'طارئ',
      _ => 'اعتيادي',
    };
    final urgencyColor = switch (urgency) {
      'urgent' => const PdfColor.fromInt(0xFFFB8C00),
      'emergency' => const PdfColor.fromInt(0xFFE53935),
      _ => const PdfColor.fromInt(0xFF5C6BC0),
    };

    pw.Widget row(String label, String val) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(
              text: _t('$label: '),
              style: pw.TextStyle(
                font: cairoBold,
                fontFallback: [cairoRegular],
                fontSize: 10,
                color: _text,
              ),
            ),
            pw.TextSpan(
              text: _t(val),
              style: pw.TextStyle(
                font: cairoRegular,
                fontSize: 10,
                color: _text,
              ),
            ),
          ]),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (specialty.isNotEmpty) row('الإحالة إلى', specialty),
        if (doctor.isNotEmpty) row('اسم الطبيب', doctor),
        if (reason.isNotEmpty) row('السبب', reason),
        pw.SizedBox(height: 4),
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: pw.BoxDecoration(
            color: PdfColor(
              urgencyColor.red,
              urgencyColor.green,
              urgencyColor.blue,
              0.1,
            ),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(10)),
            border: pw.Border.all(color: urgencyColor, width: 0.7),
          ),
          child: pw.Text(
            _t('درجة الاستعجال: $urgencyLabelAr'),
            style: pw.TextStyle(
              font: cairoBold,
              fontFallback: [cairoRegular],
              fontSize: 9,
              color: urgencyColor,
            ),
          ),
        ),
      ],
    );
  }

  // ── Vitals & Measurements shared infrastructure ──

  static const _fieldNamesAr = <String, String>{
    // Vitals
    'blood pressure': 'ضغط الدم',
    'bp systolic': 'الضغط الانقباضي',
    'bp diastolic': 'الضغط الانبساطي',
    'systolic': 'الانقباضي',
    'diastolic': 'الانبساطي',
    'systolic bp': 'الضغط الانقباضي',
    'diastolic bp': 'الضغط الانبساطي',
    'heart rate': 'معدل ضربات القلب',
    'pulse': 'النبض',
    'temperature': 'درجة الحرارة',
    'respiratory rate': 'معدل التنفس',
    'resp. rate': 'معدل التنفس',
    'oxygen saturation': 'تشبع الأكسجين',
    'spo2': 'تشبع الأكسجين',
    'blood sugar': 'سكر الدم',
    'glucose': 'الغلوكوز',
    // Measurements
    'weight': 'الوزن',
    'height': 'الطول',
    'bmi': 'مؤشر كتلة الجسم',
    'waist': 'محيط الخصر',
    'head circumference': 'محيط الرأس',
    'abdominal circumference': 'محيط البطن',
    'hip circumference': 'محيط الحوض',
    'mid-arm circumference': 'محيط منتصف الذراع',
    'chest circumference': 'محيط الصدر',
  };

  static const _defaultUnits = <String, String>{
    'bp systolic': 'mmHg',
    'bp diastolic': 'mmHg',
    'blood pressure': 'mmHg',
    'systolic': 'mmHg',
    'diastolic': 'mmHg',
    'systolic bp': 'mmHg',
    'diastolic bp': 'mmHg',
    'heart rate': 'bpm',
    'pulse': 'bpm',
    'temperature': '°C',
    'respiratory rate': '/min',
    'resp. rate': '/min',
    'oxygen saturation': '%',
    'spo2': '%',
    'weight': 'kg',
    'height': 'cm',
    'bmi': 'kg/m²',
    'blood sugar': 'mg/dL',
    'glucose': 'mg/dL',
  };

  static String _translateField(String name) {
    return _fieldNamesAr[name.toLowerCase()] ?? name;
  }

  static String _fieldUnit(String name, String existingUnit) {
    if (existingUnit.isNotEmpty) return existingUnit;
    return _defaultUnits[name.toLowerCase()] ?? '';
  }

  /// Builds entries from the new config-based format:
  ///   config.fields = [ {'name': ..., 'unit': ...}, ... ]
  ///   value = { fieldName: fieldValue, ... }
  static List<Map<String, String>>? _configBasedEntries(ModularReportSection s) {
    final fields = s.config?['fields'];
    if (fields is! List || s.value is! Map) return null;
    final values = s.value as Map;
    final entries = <Map<String, String>>[];
    for (final field in fields) {
      if (field is! Map) continue;
      final name = field['name']?.toString() ?? '';
      final unit = field['unit']?.toString() ?? '';
      final val = values[name]?.toString().trim() ?? '';
      if (val.isEmpty || val == '0') continue;
      entries.add({'name': name, 'unit': unit, 'value': val});
    }
    return entries.isEmpty ? null : entries;
  }

  /// Renders a table of name–value entries (shared by vitals & measurements).
  static pw.Widget _renderFieldTable(
      List<Map<String, String>> entries, pw.Font cairoBold, pw.Font cairoRegular) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
      },
      children: entries.asMap().entries.map((entry) {
        final i = entry.key;
        final e = entry.value;
        final arName = _translateField(e['name']!);
        final unit = _fieldUnit(e['name']!, e['unit'] ?? '');
        final displayValue =
            unit.isNotEmpty ? '${e['value']!} $unit' : e['value']!;
        final bg = i.isEven
            ? _lightTeal
            : const PdfColor.fromInt(0xFFFFFFFF);

        return pw.TableRow(
          decoration: pw.BoxDecoration(color: bg),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              child: pw.Text(_t(arName),
                  style: pw.TextStyle(
                      font: cairoRegular,
                      fontSize: 9,
                      color: _text)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              child: pw.Text(displayValue,
                  textDirection: pw.TextDirection.ltr,
                  style: pw.TextStyle(
                      font: cairoBold,
                      fontFallback: [cairoRegular],
                      fontSize: 10,
                      color: _primary)),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ── Vitals ──

  static pw.Widget _vitals(
      ModularReportSection s, pw.Font cairoBold, pw.Font cairoRegular) {
    // New config-based format
    final configEntries = _configBasedEntries(s);
    if (configEntries != null) return _renderFieldTable(configEntries, cairoBold, cairoRegular);

    // Legacy: value is a flat Map {name: value} or List
    final entries = <Map<String, String>>[];
    final value = s.value;

    if (value is Map) {
      for (final e in value.entries) {
        final v = e.value?.toString().trim() ?? '';
        if (v.isNotEmpty && v != '0' && v != 'null') {
          entries.add({'name': e.key.toString(), 'value': v, 'unit': ''});
        }
      }
    } else if (value is List) {
      for (final item in value) {
        if (item is Map) {
          final name = item['name']?.toString() ?? '';
          final val = item['value']?.toString() ?? '';
          final unit = item['unit']?.toString() ?? '';
          if (val.isNotEmpty) {
            entries.add({'name': name, 'value': val, 'unit': unit});
          }
        }
      }
    }

    if (entries.isEmpty) return pw.SizedBox();
    return _renderFieldTable(entries, cairoBold, cairoRegular);
  }

  // ── Measurements ──

  static pw.Widget _measurements(
      ModularReportSection s, pw.Font cairoBold, pw.Font cairoRegular) {
    // New config-based format
    final configEntries = _configBasedEntries(s);
    if (configEntries != null) return _renderFieldTable(configEntries, cairoBold, cairoRegular);

    // Legacy: value is a flat Map {name: value}
    if (s.value is Map) {
      final entries = <Map<String, String>>[];
      for (final e in (s.value as Map).entries) {
        final v = e.value?.toString().trim() ?? '';
        if (v.isNotEmpty && v != '0' && v != 'null') {
          entries.add({'name': e.key.toString(), 'value': v, 'unit': ''});
        }
      }
      if (entries.isNotEmpty) return _renderFieldTable(entries, cairoBold, cairoRegular);
    }

    return _vitals(s, cairoBold, cairoRegular);
  }

  // ── Scoring ──

  static pw.Widget _scoring(
      dynamic value, Map<String, dynamic>? config, pw.Font cairoBold, pw.Font cairoRegular) {
    if (value is Map) {
      final totalScore = (value['total_score'] as num?)?.toInt();
      final toolKey = config?['tool']?.toString() ?? '';

      // New format with total_score
      if (totalScore != null) {
        if (toolKey == 'custom') {
          final customName = value['custom_name']?.toString() ?? '';
          final maxScore = (value['max_score'] as num?)?.toInt() ?? 0;
          final label = customName.isNotEmpty ? customName : '—';
          final scoreText = maxScore > 0 ? '$totalScore / $maxScore' : '$totalScore';
          return pw.Text(_t('$label: $scoreText'), style: pw.TextStyle(
            font: cairoBold, fontFallback: [cairoRegular], fontSize: 11, color: _text));
        }

        // Preset tool
        final toolName = value['name']?.toString() ?? toolKey;
        final maxScore = (value['max_score'] as num?)?.toInt() ?? 0;
        final scoreText = maxScore > 0 ? '$totalScore / $maxScore' : '$totalScore';
        return pw.Text(_t('$toolName: $scoreText'), style: pw.TextStyle(
          font: cairoBold, fontFallback: [cairoRegular], fontSize: 11, color: _text));
      }

      // Legacy format
      final name = value['name']?.toString() ?? '';
      final score = value['score']?.toString() ?? '';
      final interpretation = value['interpretation']?.toString() ?? '';
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(_t('$name: $score'),
              style: pw.TextStyle(
                  font: cairoBold, fontFallback: [cairoRegular], fontSize: 11, color: _text)),
          if (interpretation.isNotEmpty)
            pw.Text(_t(interpretation),
                style: pw.TextStyle(
                    font: cairoRegular, fontSize: 9, color: _subText)),
        ],
      );
    }
    return _plainText(value.toString(), cairoRegular);
  }

  // ── Checklist ──

  static pw.Widget _checklist(
      ModularReportSection s, pw.Font cairoRegular, pw.Font cairoBold) {
    // Arabic lookup for known checklist item names
    const nameAr = <String, String>{
      'Reflexes': 'المنعكسات',
      'Pupils': 'الحدقتان',
      'Heart Sounds': 'أصوات القلب',
      'Lung Sounds': 'أصوات الرئة',
      'Abdomen': 'البطن',
      'Skin': 'الجلد',
      'Throat': 'الحلق',
      'Ears': 'الأذنان',
      'Lymph Nodes': 'العقد اللمفاوية',
      'Gait': 'المشية',
      'Coordination': 'التنسيق الحركي',
      'Cranial Nerves': 'الأعصاب القحفية',
    };
    const statusAr = <String, String>{
      'Normal': 'طبيعي',
      'Abnormal': 'غير طبيعي',
    };

    // New format: config.items + value map
    final configItems = s.config?['items'];
    if (configItems is List && s.value is Map) {
      final values = s.value as Map;
      final rows = <pw.Widget>[];
      for (final item in configItems) {
        if (item is! Map) continue;
        final nameEn = item['name']?.toString() ?? '';
        final status = values[nameEn]?.toString() ?? '';
        if (status.isEmpty) continue;
        final displayName = nameAr[nameEn] ?? nameEn;
        final displayStatus = statusAr[status] ?? status;
        final isAbnormal = status == 'Abnormal';
        rows.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(
            children: [
              pw.Text(_t('$displayName: '), style: pw.TextStyle(
                font: cairoBold, fontFallback: [cairoRegular],
                fontSize: 9, color: _text)),
              pw.Text(_t(displayStatus), style: pw.TextStyle(
                font: cairoRegular, fontSize: 9,
                color: isAbnormal ? PdfColors.red : _primary)),
            ],
          ),
        ));
      }
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows,
      );
    }

    // Legacy format: value is List
    final items = (s.value is List) ? (s.value as List) : [];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items.map((item) {
        if (item is Map) {
          final label = item['label']?.toString() ?? '';
          final checked =
              item['checked'] == true || item['status'] == 'checked';
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(children: [
              pw.Container(
                width: 10,
                height: 10,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _primary, width: 0.5),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(2)),
                  color: checked ? _primary : PdfColors.white,
                ),
                child: checked
                    ? pw.Center(
                        child: pw.Text('✓',
                            style: pw.TextStyle(
                                fontSize: 7,
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold)))
                    : null,
              ),
              pw.SizedBox(width: 5),
              pw.Text(_t(label),
                  style: pw.TextStyle(
                      font: cairoRegular, fontSize: 9, color: _text)),
            ]),
          );
        }
        return _bulletItem(item.toString(), cairoRegular);
      }).toList(),
    );
  }

  // ── Custom table ──

  static pw.Widget _customTable(
      dynamic value, pw.Font cairoBold, pw.Font cairoRegular) {
    if (value is Map) {
      final headers =
          ((value['columns'] ?? value['headers']) as List?)
                  ?.map((e) => _t(e.toString()))
                  .toList() ??
              [];
      final rows = (value['rows'] as List?)?.map((row) {
            if (row is List) {
              final cells = row.map((e) => _t(e?.toString() ?? '')).toList();
              if (headers.isNotEmpty && cells.length < headers.length) {
                cells.addAll(
                    List<String>.filled(headers.length - cells.length, ''));
              } else if (headers.isNotEmpty && cells.length > headers.length) {
                return cells.sublist(0, headers.length);
              }
              return cells;
            }
            return <String>[_t(row?.toString() ?? '')];
          }).toList() ??
          [];
      if (headers.isNotEmpty) {
        return pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(font: cairoBold, fontFallback: [cairoRegular], fontSize: 9),
          cellStyle: pw.TextStyle(font: cairoRegular, fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: _lightTeal),
          headers: headers,
          data: rows,
        );
      }
    }
    return _plainText(value.toString(), cairoRegular);
  }

  // ── Attachments ──

  static pw.Widget _attachments(dynamic value, pw.Font cairoRegular) {
    final items = (value is List) ? value : [];
    if (items.isEmpty) return pw.SizedBox.shrink();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items.map((item) {
        final name = (item is Map)
            ? (item['name']?.toString() ?? 'مرفق')
            : item.toString();
        final type = (item is Map) ? (item['type']?.toString() ?? '').toLowerCase() : '';
        final isPdf = type == 'pdf';
        final dotColor = isPdf ? const PdfColor.fromInt(0xFFEF5350) : _primary;

        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 5, height: 5,
                margin: const pw.EdgeInsets.only(top: 4),
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: dotColor,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Text(_t(name), style: pw.TextStyle(
                  font: cairoRegular, fontSize: 9, color: _subText,
                )),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Body Map ──

  static const _diagramTypeToAsset = <String, String>{
    'full_body_anterior': 'assets/images/body_map/body_front.svg',
    'full_body_posterior': 'assets/images/body_map/body_back.svg',
    'full_body_anterior_female': 'assets/images/body_map/full_body_anterior_female.svg',
    'full_body_posterior_female': 'assets/images/body_map/full_body_posterior_female.svg',
    'head_face': 'assets/images/body_map/head_face.svg',
    'head_lateral': 'assets/images/body_map/head_lateral.svg',
    'head_posterior': 'assets/images/body_map/head_posterior.svg',
    'neck_anterior': 'assets/images/body_map/neck_anterior.svg',
    'hand_palmar': 'assets/images/body_map/hand_palmar.svg',
    'hand_dorsal': 'assets/images/body_map/hand_dorsal.svg',
    'foot_plantar': 'assets/images/body_map/foot_plantar.svg',
    'foot_dorsal': 'assets/images/body_map/foot_dorsal.svg',
    'torso_anterior_male': 'assets/images/body_map/torso_anterior_male.svg',
    'torso_anterior_female': 'assets/images/body_map/torso_anterior_female.svg',
    'torso_posterior': 'assets/images/body_map/torso_posterior.svg',
    'torso_lateral': 'assets/images/body_map/torso_lateral.svg',
    'shoulder_anterior': 'assets/images/body_map/shoulder_anterior.svg',
    'shoulder_posterior': 'assets/images/body_map/shoulder_posterior.svg',
    'arm_anterior': 'assets/images/body_map/arm_anterior.svg',
    'arm_posterior': 'assets/images/body_map/arm_posterior.svg',
    'wrist_dorsal': 'assets/images/body_map/wrist_dorsal.svg',
    'wrist_palmar': 'assets/images/body_map/wrist_palmar.svg',
    'hip_anterior': 'assets/images/body_map/hip_anterior.svg',
    'hip_posterior': 'assets/images/body_map/hip_posterior.svg',
    'knee_anterior': 'assets/images/body_map/knee_anterior.svg',
    'knee_posterior': 'assets/images/body_map/knee_posterior.svg',
    'leg_lateral': 'assets/images/body_map/leg_lateral.svg',
    'leg_medial': 'assets/images/body_map/leg_medial.svg',
  };

  static const _categoryColors = <String, PdfColor>{
    'pain': PdfColor.fromInt(0xFFE53935),
    'lesion': PdfColor.fromInt(0xFFFB8C00),
    'swelling': PdfColor.fromInt(0xFF1E88E5),
    'surgical': PdfColor.fromInt(0xFF8E24AA),
    'other': PdfColor.fromInt(0xFF757575),
  };

  static pw.Widget _renderBodyMap(
    ModularReportSection s,
    pw.Font cairoRegular,
    pw.Font cairoBold,
    pw.Font montserratBold,
    Map<String, String> bodyMapSvgs,
  ) {
    if (s.value is! Map) return pw.SizedBox.shrink();
    final map = s.value as Map;
    final pins = (map['pins'] as List?)?.whereType<Map>().toList() ?? [];
    if (pins.isEmpty) return pw.SizedBox.shrink();

    const categoryLabels = <String, String>{
      'pain': 'ألم',
      'lesion': 'آفة',
      'swelling': 'تورم',
      'surgical': 'جراحي',
      'other': 'أخرى',
    };

    // Resolve SVG asset
    final diagramType = map['diagram_type']?.toString() ?? '';
    final assetPath = _diagramTypeToAsset[diagramType] ??
        _diagramTypeToAsset['full_body_anterior']!;
    final svgString = bodyMapSvgs[assetPath];

    // Render SVG diagram with pin markers
    pw.Widget? diagramWidget;
    if (svgString != null) {
      const svgAspects = <String, double>{
        'assets/images/body_map/body_front.svg': 2328.0 / 1052.0,
        'assets/images/body_map/body_back.svg': 2328.0 / 1052.0,
        'assets/images/body_map/full_body_anterior_female.svg': 2400.0 / 1792.0,
        'assets/images/body_map/full_body_posterior_female.svg': 2400.0 / 1792.0,
        'assets/images/body_map/head_face.svg': 1858.0 / 1331.0,
        'assets/images/body_map/head_lateral.svg': 2210.0 / 1650.0,
        'assets/images/body_map/head_posterior.svg': 2210.0 / 1650.0,
        'assets/images/body_map/neck_anterior.svg': 2210.0 / 1650.0,
        'assets/images/body_map/hand_palmar.svg': 1858.0 / 1331.0,
        'assets/images/body_map/hand_dorsal.svg': 1858.0 / 1331.0,
        'assets/images/body_map/foot_plantar.svg': 1858.0 / 1331.0,
        'assets/images/body_map/foot_dorsal.svg': 1858.0 / 1331.0,
        'assets/images/body_map/torso_anterior_male.svg': 2210.0 / 1650.0,
        'assets/images/body_map/torso_anterior_female.svg': 2210.0 / 1650.0,
        'assets/images/body_map/torso_posterior.svg': 2210.0 / 1650.0,
        'assets/images/body_map/torso_lateral.svg': 2210.0 / 1650.0,
        'assets/images/body_map/shoulder_anterior.svg': 2210.0 / 1650.0,
        'assets/images/body_map/shoulder_posterior.svg': 2210.0 / 1650.0,
        'assets/images/body_map/arm_anterior.svg': 2210.0 / 1650.0,
        'assets/images/body_map/arm_posterior.svg': 2210.0 / 1650.0,
        'assets/images/body_map/wrist_dorsal.svg': 2210.0 / 1650.0,
        'assets/images/body_map/wrist_palmar.svg': 2210.0 / 1650.0,
        'assets/images/body_map/hip_anterior.svg': 2400.0 / 1792.0,
        'assets/images/body_map/hip_posterior.svg': 2400.0 / 1792.0,
        'assets/images/body_map/knee_anterior.svg': 2400.0 / 1792.0,
        'assets/images/body_map/knee_posterior.svg': 2400.0 / 1792.0,
        'assets/images/body_map/leg_lateral.svg': 2400.0 / 1792.0,
        'assets/images/body_map/leg_medial.svg': 2400.0 / 1792.0,
      };

      final aspect = svgAspects[assetPath] ?? (2328.0 / 1052.0);
      const diagramHeight = 280.0;
      final diagramWidth = diagramHeight / aspect;
      const pinSize = 12.0;
      const pinHalf = pinSize / 2;

      final pinMarkers = <pw.Widget>[];
      for (int i = 0; i < pins.length; i++) {
        final pin = pins[i];
        final px = (pin['x'] as num?)?.toDouble() ?? 0.0;
        final py = (pin['y'] as num?)?.toDouble() ?? 0.0;
        final cat = pin['category']?.toString() ?? 'other';
        final color = _categoryColors[cat] ?? _categoryColors['other']!;

        pinMarkers.add(pw.Positioned(
          left: px * diagramWidth - pinHalf,
          top: py * diagramHeight - pinHalf,
          child: pw.Container(
            width: pinSize,
            height: pinSize,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              color: color,
              border: pw.Border.all(
                  color: const PdfColor.fromInt(0xFFFFFFFF), width: 1),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              '${i + 1}',
              style: pw.TextStyle(
                font: montserratBold,
                fontSize: 6,
                color: const PdfColor.fromInt(0xFFFFFFFF),
              ),
            ),
          ),
        ));
      }

      diagramWidget = pw.Center(
        child: pw.SizedBox(
          width: diagramWidth,
          height: diagramHeight,
          child: pw.Stack(
            overflow: pw.Overflow.visible,
            children: [
              pw.Positioned.fill(
                child: pw.SvgImage(
                  svg: svgString,
                  fit: pw.BoxFit.contain,
                  colorFilter: const PdfColor.fromInt(0xFF424242),
                ),
              ),
              ...pinMarkers,
            ],
          ),
        ),
      );
    }

    // Pin legend table
    final headers = ['#', 'الفئة', 'التسمية', 'ملاحظة'].reversed.toList();
    final data = pins.asMap().entries.map((entry) {
      final pin = entry.value;
      final cat = pin['category']?.toString() ?? 'other';
      return [
        _t(pin['note']?.toString() ?? ''),
        _t(pin['label']?.toString() ?? ''),
        _t(categoryLabels[cat] ?? 'أخرى'),
        _t('${entry.key + 1}'),
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (diagramWidget != null) ...[
          diagramWidget,
          pw.SizedBox(height: 8),
        ],
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
              font: cairoBold, fontFallback: [cairoRegular], fontSize: 8),
          cellStyle: pw.TextStyle(font: cairoRegular, fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: _lightTeal),
          headerAlignment: pw.Alignment.center,
          cellAlignment: pw.Alignment.center,
          border: pw.TableBorder.all(
              color: const PdfColor.fromInt(0xFF9E9E9E), width: 0.5),
          headers: headers,
          data: data,
        ),
      ],
    );
  }

  // ── Image Comparison ──

  static pw.Widget? _pdfImageFromPath(String? url, {double? height}) {
    if (url == null || url.isEmpty) return null;
    try {
      Uint8List bytes;
      if (url.startsWith('data:')) {
        final dataStr = url.split(',').last;
        bytes = base64Decode(dataStr);
      } else {
        // Patient app doesn't have local file access like doctor app,
        // so only data URIs are supported
        return null;
      }
      final pdfImage = pw.MemoryImage(bytes);
      return pw.Image(pdfImage, height: height ?? 150, fit: pw.BoxFit.contain);
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _renderImageComparison(
    ModularReportSection s,
    pw.Font cairoRegular,
    pw.Font cairoBold,
  ) {
    if (s.value is! Map) return pw.SizedBox.shrink();
    final map = s.value as Map;
    final mode = map['mode']?.toString() ?? '';
    final images =
        (map['images'] as List?)?.whereType<Map>().toList() ?? [];
    if (images.isEmpty) return pw.SizedBox.shrink();

    if (mode == 'before_after') {
      final before =
          images.where((i) => i['role'] == 'before').firstOrNull;
      final after =
          images.where((i) => i['role'] == 'after').firstOrNull;

      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (before != null)
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(_t('قبل'),
                      style: pw.TextStyle(font: cairoBold, fontSize: 9)),
                  pw.SizedBox(height: 4),
                  _pdfImageFromPath(before['url']?.toString(),
                          height: 150) ??
                      pw.Container(
                        height: 150,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Center(
                          child: pw.Text('—',
                              style: pw.TextStyle(
                                  font: cairoRegular,
                                  fontSize: 12,
                                  color: _subText)),
                        ),
                      ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _t(before['date']?.toString() ?? ''),
                    style: pw.TextStyle(
                        font: cairoRegular, fontSize: 8, color: _subText),
                  ),
                  if ((before['note']?.toString() ?? '').isNotEmpty)
                    pw.Text(
                      _t(before['note'].toString()),
                      style: pw.TextStyle(
                          font: cairoRegular,
                          fontSize: 7,
                          color: _subText,
                          fontStyle: pw.FontStyle.italic),
                    ),
                ],
              ),
            ),
          pw.SizedBox(width: 8),
          if (after != null)
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(_t('بعد'),
                      style: pw.TextStyle(font: cairoBold, fontSize: 9)),
                  pw.SizedBox(height: 4),
                  _pdfImageFromPath(after['url']?.toString(),
                          height: 150) ??
                      pw.Container(
                        height: 150,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Center(
                          child: pw.Text('—',
                              style: pw.TextStyle(
                                  font: cairoRegular,
                                  fontSize: 12,
                                  color: _subText)),
                        ),
                      ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _t(after['date']?.toString() ?? ''),
                    style: pw.TextStyle(
                        font: cairoRegular, fontSize: 8, color: _subText),
                  ),
                  if ((after['note']?.toString() ?? '').isNotEmpty)
                    pw.Text(
                      _t(after['note'].toString()),
                      style: pw.TextStyle(
                          font: cairoRegular,
                          fontSize: 7,
                          color: _subText,
                          fontStyle: pw.FontStyle.italic),
                    ),
                ],
              ),
            ),
        ],
      );
    }

    // Progress timeline
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: images.asMap().entries.map((entry) {
        final img = entry.value;
        final date = img['date']?.toString() ?? '';
        final note = img['note']?.toString() ?? '';
        return pw.Container(
          width: 120,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfImageFromPath(img['url']?.toString(), height: 100) ??
                  pw.Container(
                    height: 100,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Center(
                      child: pw.Text('${entry.key + 1}',
                          style: pw.TextStyle(
                              font: cairoBold,
                              fontSize: 14,
                              color: _subText)),
                    ),
                  ),
              pw.SizedBox(height: 2),
              pw.Text(
                _t(date),
                style: pw.TextStyle(font: cairoBold, fontSize: 8),
              ),
              if (note.isNotEmpty)
                pw.Text(
                  _t(note),
                  style: pw.TextStyle(
                      font: cairoRegular,
                      fontSize: 7,
                      color: _subText),
                  maxLines: 2,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ══════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════

  static pw.Widget _bulletItem(String text, pw.Font cairoRegular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 4,
            height: 4,
            margin: const pw.EdgeInsets.only(top: 5, left: 6),
            decoration:
                const pw.BoxDecoration(color: _primary, shape: pw.BoxShape.circle),
          ),
          pw.Expanded(
            child: pw.Text(_t(text),
                style: pw.TextStyle(
                    font: cairoRegular, fontSize: 10, color: _text)),
          ),
        ],
      ),
    );
  }

  static String _toArabicNumerals(String input) {
    const western = '0123456789';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    var result = input;
    for (var i = 0; i < western.length; i++) {
      result = result.replaceAll(western[i], arabic[i]);
    }
    return result;
  }

  static String _extractClinicPhone(ModularReport report) {
    final phones = report.doctorPhones;
    if (phones != null && phones.isNotEmpty) {
      for (final p in phones) {
        if (p is Map) {
          final cc = (p['city_code'] ?? '').toString().trim();
          final num = (p['number'] ?? '').toString().trim();
          if (num.isNotEmpty) {
            return cc.isNotEmpty ? '($cc) $num' : num;
          }
        }
      }
    }
    return '';
  }

  /// Convert international format (00963988668844) to local (0988668844)
  static String _formatMobile(String mobile) {
    if (mobile.startsWith('00963')) {
      return '0${mobile.substring(5)}';
    }
    if (mobile.startsWith('+963')) {
      return '0${mobile.substring(4)}';
    }
    return mobile;
  }

  static String _formatGender(String? gender) {
    if (gender == 'Male' || gender == 'ذكر') return 'ذكر';
    if (gender == 'Female' || gender == 'أنثى') return 'أنثى';
    return '-';
  }

  static String _calculateAge(String? dobString) {
    if (dobString == null || dobString.isEmpty) return '-';
    try {
      final dob = DateTime.parse(dobString);
      final age = DateTime.now().year - dob.year;
      return _toArabicNumerals('$age سنة');
    } catch (_) {
      return '-';
    }
  }
}
