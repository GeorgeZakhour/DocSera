import 'dart:typed_data';

import 'package:docsera/screens/home/health/pages/visit_reports/modular_report_model.dart';
import 'package:docsera/utils/arabic_reshaper/arabic_reshaper.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates a patient-facing PDF for modular reports.
/// Mirrors the DocSera-Pro "Refined Elegant" design language:
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
  }) async {
    // ── Fonts ──
    final cairoRegData =
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final cairoBoldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final montRegData =
        await rootBundle.load('assets/fonts/Montserrat-Regular.ttf');
    final cairoRegular = pw.Font.ttf(cairoRegData);
    final cairoBold = pw.Font.ttf(cairoBoldData);
    final montserratRegular = pw.Font.ttf(montRegData);

    // ── Logo ──
    pw.SvgImage? logoSvg;
    try {
      final svgString =
          await rootBundle.loadString('assets/images/docsera_main.svg');
      logoSvg = pw.SvgImage(svg: svgString);
    } catch (_) {}

    // ── Doctor info ──
    var doctorName = report.doctorName ?? '';
    if (doctorName.isNotEmpty &&
        !doctorName.startsWith('د.') &&
        !doctorName.toLowerCase().startsWith('dr')) {
      doctorName = 'د. $doctorName';
    }
    final specialty = report.doctorSpecialty ?? '';
    final clinic = report.doctorClinic ?? '';
    final doctorPhone = _extractClinicPhone(report);
    final doctorMobile = _formatMobile((report.doctorMobile ?? '').trim());
    final doctorEmail = (report.doctorEmail ?? '').trim();
    final doctorWebsite = (report.doctorWebsite ?? '').trim();
    final date =
        '${report.createdAt.year}/${report.createdAt.month.toString().padLeft(2, '0')}/${report.createdAt.day.toString().padLeft(2, '0')}';
    final patientName = report.patientName ?? 'زائر';
    final patientGender = _formatGender(report.patientGender);
    final patientAge = _calculateAge(report.patientDob);

    final pdfTheme = pw.ThemeData.withFont(
      base: cairoRegular,
      bold: cairoBold,
      fontFallback: [cairoRegular],
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pdfTheme,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(20),
        header: (ctx) => _buildHeader(
          logoSvg: logoSvg,
          doctorName: doctorName,
          specialty: specialty,
          clinic: clinic,
          phone: doctorPhone,
          mobile: doctorMobile,
          email: doctorEmail,
          website: doctorWebsite,
          cairoBold: cairoBold,
          cairoRegular: cairoRegular,
          montserratRegular: montserratRegular,
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
    String phone = '',
    String mobile = '',
    String email = '',
    String website = '',
    required pw.Font cairoBold,
    required pw.Font cairoRegular,
    required pw.Font montserratRegular,
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
            pw.SizedBox(height: 10, child: logoSvg),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Center(
        child: pw.Column(children: [
          pw.Text(_t(doctorName),
              style: pw.TextStyle(
                  font: cairoBold, fontFallback: [cairoRegular], fontSize: 15, color: _text)),
          if (specialty.isNotEmpty)
            pw.Text(_t(specialty),
                style: pw.TextStyle(
                    font: cairoRegular, fontSize: 9, color: _subText)),
          if (clinic.isNotEmpty)
            pw.Text(_t(clinic),
                style: pw.TextStyle(
                    font: cairoRegular, fontSize: 8.5, color: _subText)),
          if (contactLine1.isNotEmpty)
            pw.Text(contactLine1,
                textDirection: pw.TextDirection.ltr, style: ltrStyle),
          if (contactLine2.isNotEmpty)
            pw.Text(contactLine2,
                textDirection: pw.TextDirection.ltr, style: ltrStyle),
        ]),
      ),
      pw.SizedBox(height: 6),
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

  static const _sectionLabels = {
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
    final label = section.label ?? _sectionLabels[section.type] ?? section.type;
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
  }) {
    if (!section.hasContent) return null;
    switch (section.type) {
      case 'chief_complaint':
      case 'additional_notes':
      case 'custom_text':
        return _plainText(section.value.toString(), cairoRegular);

      case 'referral':
        return _referral(section.value, cairoBold, cairoRegular);

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

      case 'vitals':
        return _vitals(section.value, cairoBold, cairoRegular);

      case 'measurements':
        return _measurements(section.value, cairoBold, cairoRegular, montserratRegular);

      case 'scoring':
        return _scoring(section.value, cairoBold, cairoRegular);

      case 'checklist':
        return _checklist(section.value, cairoRegular);

      case 'custom_table':
        return _customTable(section.value, cairoBold, cairoRegular);

      case 'body_map':
        return pw.Text(_t('(خريطة الجسم — انظر التطبيق)'),
            style: pw.TextStyle(
                font: cairoRegular,
                fontSize: 9,
                color: _subText,
                fontStyle: pw.FontStyle.italic));

      case 'image_comparison':
        return pw.Text(_t('(مقارنة الصور — انظر التطبيق)'),
            style: pw.TextStyle(
                font: cairoRegular,
                fontSize: 9,
                color: _subText,
                fontStyle: pw.FontStyle.italic));

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

  // ── Numbered list ──

  static pw.Widget _numberedList(
      dynamic value, pw.Font cairoRegular, pw.Font cairoBold) {
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
              pw.Text('$num. ',
                  style: pw.TextStyle(
                      font: cairoBold, fontFallback: [cairoRegular], fontSize: 10, color: _primary)),
              pw.Expanded(
                child: pw.Text(_t(entry.value),
                    style: pw.TextStyle(
                        font: cairoRegular, fontSize: 10, color: _text)),
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
            decoration: pw.BoxDecoration(
              color: _lightTeal,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Medication name with number
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$num. ',
                        style: pw.TextStyle(
                            font: cairoBold, fontFallback: [cairoRegular], fontSize: 10, color: _primary)),
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
                      return pw.Padding(
                        padding: pw.EdgeInsets.only(left: d.key > 0 ? 0 : 0),
                        child: pw.Row(children: [
                          if (d.key > 0)
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                              child: pw.Text('·',
                                  style: pw.TextStyle(
                                      fontSize: 10, color: _subText)),
                            ),
                          pw.Text(_t(d.value),
                              style: pw.TextStyle(
                                  font: cairoRegular,
                                  fontSize: 8.5,
                                  color: _subText)),
                        ]),
                      );
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
      final period = value['period']?.toString() ?? '';
      final notes = value['notes']?.toString() ?? '';
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

  // ── Vitals ──

  static const _vitalNamesAr = {
    'blood pressure': 'ضغط الدم',
    'bp systolic': 'الضغط الانقباضي',
    'bp diastolic': 'الضغط الانبساطي',
    'systolic': 'الانقباضي',
    'diastolic': 'الانبساطي',
    'heart rate': 'معدل ضربات القلب',
    'pulse': 'النبض',
    'temperature': 'درجة الحرارة',
    'respiratory rate': 'معدل التنفس',
    'oxygen saturation': 'تشبع الأكسجين',
    'spo2': 'تشبع الأكسجين',
    'weight': 'الوزن',
    'height': 'الطول',
    'bmi': 'مؤشر كتلة الجسم',
    'blood sugar': 'سكر الدم',
    'glucose': 'الغلوكوز',
  };

  static const _vitalUnits = {
    'bp systolic': 'mmHg',
    'bp diastolic': 'mmHg',
    'blood pressure': 'mmHg',
    'systolic': 'mmHg',
    'diastolic': 'mmHg',
    'heart rate': 'bpm',
    'pulse': 'bpm',
    'temperature': '°C',
    'respiratory rate': '/min',
    'oxygen saturation': '%',
    'spo2': '%',
    'weight': 'kg',
    'height': 'cm',
    'bmi': 'kg/m²',
    'blood sugar': 'mg/dL',
    'glucose': 'mg/dL',
  };

  static String _translateVital(String name) {
    return _vitalNamesAr[name.toLowerCase()] ?? name;
  }

  static String _vitalUnit(String name, String existingUnit) {
    if (existingUnit.isNotEmpty) return existingUnit;
    return _vitalUnits[name.toLowerCase()] ?? '';
  }

  static pw.Widget _vitals(
      dynamic value, pw.Font cairoBold, pw.Font cairoRegular) {
    final entries = <Map<String, String>>[];

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

    // Clean table rows with alternating backgrounds
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
      },
      children: entries.asMap().entries.map((entry) {
        final i = entry.key;
        final e = entry.value;
        final arName = _translateVital(e['name']!);
        final unit = _vitalUnit(e['name']!, e['unit']!);
        final displayValue = unit.isNotEmpty
            ? '${e['value']!} $unit'
            : e['value']!;
        final bg = i.isEven ? _lightTeal : const PdfColor.fromInt(0xFFFFFFFF);

        return pw.TableRow(
          decoration: pw.BoxDecoration(color: bg),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: pw.Text(_t(arName),
                  style: pw.TextStyle(
                      font: cairoRegular, fontSize: 9, color: _text)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: pw.Text(displayValue,
                  textDirection: pw.TextDirection.ltr,
                  style: pw.TextStyle(
                      font: cairoBold, fontFallback: [cairoRegular], fontSize: 10, color: _primary)),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ── Measurements ──

  static pw.Widget _measurements(
    dynamic value,
    pw.Font cairoBold,
    pw.Font cairoRegular,
    pw.Font montserratRegular,
  ) {
    if (value is Map) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: value.entries.map((e) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(children: [
              pw.Text('${_t(e.key.toString())}: ',
                  style: pw.TextStyle(
                      font: cairoBold, fontFallback: [cairoRegular], fontSize: 9, color: _subText)),
              pw.Text(e.value.toString(),
                  style: pw.TextStyle(
                      font: montserratRegular, fontSize: 9, color: _text)),
            ]),
          );
        }).toList(),
      );
    }
    return _vitals(value, cairoBold, cairoRegular);
  }

  // ── Scoring ──

  static pw.Widget _scoring(
      dynamic value, pw.Font cairoBold, pw.Font cairoRegular) {
    if (value is Map) {
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

  static pw.Widget _checklist(dynamic value, pw.Font cairoRegular) {
    final items = (value is List) ? value : [];
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

    PdfColor urgencyColor;
    String urgencyLabel;
    switch (urgency) {
      case 'emergency':
        urgencyColor = const PdfColor.fromInt(0xFFE53935);
        urgencyLabel = 'طارئ';
        break;
      case 'urgent':
        urgencyColor = const PdfColor.fromInt(0xFFFB8C00);
        urgencyLabel = 'عاجل';
        break;
      case 'routine':
      default:
        urgencyColor = const PdfColor.fromInt(0xFF5C6BC0);
        urgencyLabel = 'روتيني';
        break;
    }

    pw.Widget row(String label, String val) {
      if (val.trim().isEmpty) return pw.SizedBox();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('${_t(label)}: ',
                style: pw.TextStyle(
                    font: cairoBold,
                    fontFallback: [cairoRegular],
                    fontSize: 10,
                    color: _subText)),
            pw.Expanded(
              child: pw.Text(_t(val),
                  style: pw.TextStyle(
                      font: cairoRegular, fontSize: 10, color: _text)),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        row('التخصص', specialty),
        row('الطبيب', doctor),
        row('السبب', reason),
        pw.SizedBox(height: 2),
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: pw.BoxDecoration(
            color: PdfColor(urgencyColor.red, urgencyColor.green,
                urgencyColor.blue, 0.1),
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: urgencyColor, width: 0.6),
          ),
          child: pw.Text(_t(urgencyLabel),
              style: pw.TextStyle(
                  font: cairoBold,
                  fontFallback: [cairoRegular],
                  fontSize: 9,
                  color: urgencyColor)),
        ),
      ],
    );
  }

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
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items.map((item) {
        final name = (item is Map)
            ? (item['name']?.toString() ?? 'مرفق')
            : item.toString();
        return _bulletItem(name, cairoRegular);
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
