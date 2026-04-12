import 'package:docsera/app/const.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/modular_report_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'patient_section_card.dart';

class PatientSectionRenderers {
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

  static Widget render(ModularReportSection section) {
    final label = section.label ?? _sectionLabels[section.type] ?? section.type;
    final content = _renderContent(section);
    if (content == null) return const SizedBox.shrink();
    return PatientSectionCard(title: label, child: content);
  }

  static Widget? _renderContent(ModularReportSection section) {
    switch (section.type) {
      case 'chief_complaint':
      case 'additional_notes':
      case 'custom_text':
        return _plainText(section.value.toString());

      case 'referral':
        return _referral(section.value);

      case 'custom_table':
        return _customTable(section.value);

      case 'clinical_examination':
      case 'treatment_instructions':
        return _bulletList(section.value);

      case 'treatment_procedures':
        return _numberedList(section.value);

      case 'diagnosis':
        return _diagnosis(section.value);

      case 'prescriptions':
      case 'in_clinic_treatments':
        return _prescriptions(section.value);

      case 'requested_exams':
        return _requestedExams(section.value);

      case 'follow_up':
        return _followUp(section.value);

      case 'vitals':
      case 'measurements':
        return _vitalsTable(section);

      case 'scoring':
        return _scoring(section);

      case 'checklist':
        return _checklist(section);

      case 'attachments':
        return _attachments(section.value);

      default:
        if (section.value is String) {
          return _plainText(section.value.toString());
        }
        return null;
    }
  }

  // =====================================================
  // Content renderers — compact medical-report style
  // =====================================================

  static Widget _plainText(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 12.sp, height: 1.5, color: AppColors.mainDark),
    );
  }

  static Widget _bulletList(dynamic value) {
    final items = (value is List)
        ? value.map((e) => e.toString()).toList()
        : [value.toString()];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((item) => Padding(
                padding: EdgeInsets.only(bottom: 3.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4.w,
                      height: 4.w,
                      margin: EdgeInsets.only(top: 6.h, left: 4.w, right: 4.w),
                      decoration: BoxDecoration(
                        color: AppColors.main.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(item,
                          style: TextStyle(
                              fontSize: 12.sp,
                              height: 1.4,
                              color: AppColors.mainDark)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  static Widget _numberedList(dynamic value) {
    final items = (value is List)
        ? value.map((e) => e.toString()).toList()
        : [value.toString()];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((entry) {
        return Padding(
          padding: EdgeInsets.only(bottom: 3.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 18.w,
                child: Text(
                  '${entry.key + 1}.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.main,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
              Expanded(
                child: Text(entry.value,
                    style: TextStyle(
                        fontSize: 12.sp, color: AppColors.mainDark)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static Widget _diagnosis(dynamic value) {
    if (value is Map) {
      final text = value['text']?.toString() ?? '';
      final icd = value['icd_code']?.toString() ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text,
              style: TextStyle(fontSize: 12.sp, color: AppColors.mainDark)),
          if (icd.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppColors.main.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                icd,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: AppColors.main,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      );
    }
    return _plainText(value.toString());
  }

  static Widget _prescriptions(dynamic value) {
    final items = (value is List) ? value : [];
    return Column(
      children: items.map((item) {
        if (item is Map) {
          final name = item['name']?.toString() ?? '';
          final dosage = item['dosage']?.toString() ?? '';
          final frequency = item['frequency']?.toString() ?? '';
          final duration = item['duration']?.toString() ?? '';
          final notes = item['notes']?.toString() ?? '';
          return Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 6.h),
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.main.withOpacity(0.04),
              border: Border.all(color: AppColors.main.withOpacity(0.12)),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dosage.isNotEmpty ? '$name  $dosage' : name,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mainDark,
                  ),
                ),
                if (frequency.isNotEmpty || duration.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 2.h),
                    child: Text(
                      [frequency, duration]
                          .where((e) => e.isNotEmpty)
                          .join(' · '),
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        color: AppColors.textSubColor,
                      ),
                    ),
                  ),
                if (notes.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 2.h),
                    child: Text(
                      notes,
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        color: AppColors.textSubColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
        return _plainText(item.toString());
      }).toList(),
    );
  }

  static Widget _requestedExams(dynamic value) {
    final items = (value is List) ? value : [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        if (item is Map) {
          final name =
              item['exam_name']?.toString() ?? item['name']?.toString() ?? '';
          final notes = item['notes']?.toString() ?? '';
          return Padding(
            padding: EdgeInsets.only(bottom: 3.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4.w,
                  height: 4.w,
                  margin:
                      EdgeInsets.only(top: 6.h, left: 4.w, right: 4.w),
                  decoration: BoxDecoration(
                    color: AppColors.main.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    notes.isNotEmpty ? '$name ($notes)' : name,
                    style: TextStyle(
                        fontSize: 12.sp, color: AppColors.mainDark),
                  ),
                ),
              ],
            ),
          );
        }
        return _plainText(item.toString());
      }).toList(),
    );
  }

  static Widget _followUp(dynamic value) {
    if (value is Map) {
      final date = value['date']?.toString() ?? '';
      final period = value['period']?.toString() ?? '';
      final notes = value['notes']?.toString() ?? '';
      final dateDisplay = date.isNotEmpty ? date : period;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dateDisplay.isNotEmpty)
            Row(
              children: [
                Icon(Icons.event_rounded,
                    size: 13.sp, color: AppColors.main.withOpacity(0.7)),
                SizedBox(width: 4.w),
                Text(
                  dateDisplay,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mainDark,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
          if (notes.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(notes,
                  style: TextStyle(
                      fontSize: 11.sp, color: AppColors.textSubColor)),
            ),
        ],
      );
    }
    return _plainText(value.toString());
  }

  static Widget _vitalsTable(ModularReportSection section) {
    final value = section.value;
    final config = section.config;

    // Build a unified list of {name, value, unit} entries from
    // either data shape:
    //
    //  Shape A (DocSera-Pro):
    //    value : { 'Systolic BP': '120', 'Heart Rate': '80' }
    //    config: { 'fields': [ {'name':'Systolic BP','unit':'mmHg'}, ... ] }
    //
    //  Shape B (generic):
    //    value : [ {'name':'X', 'value':'Y', 'unit':'Z'}, ... ]

    final entries = <Map<String, String>>[];

    if (value is Map) {
      // Shape A — merge fields from config to get units
      final fields = <String, Map<String, dynamic>>{};
      if (config != null && config['fields'] is List) {
        for (final f in (config['fields'] as List)) {
          if (f is Map) {
            final name = f['name']?.toString() ?? '';
            if (name.isNotEmpty) {
              fields[name] = Map<String, dynamic>.from(f);
            }
          }
        }
      }
      for (final e in value.entries) {
        final name = e.key.toString();
        final val = e.value?.toString().trim() ?? '';
        if (val.isEmpty || val == 'null') continue;
        final unit = fields[name]?['unit']?.toString() ?? '';
        entries.add({'name': name, 'value': val, 'unit': unit});
      }
    } else if (value is List) {
      // Shape B — list of maps
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

    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      children: entries.map((e) {
        final unit = e['unit'] ?? '';
        final displayValue = unit.isNotEmpty
            ? '${e['value']} $unit'
            : e['value'] ?? '';
        return Padding(
          padding: EdgeInsets.only(bottom: 4.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(e['name'] ?? '',
                  style: TextStyle(
                      fontSize: 11.sp, color: AppColors.textSubColor)),
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Montserrat',
                  color: AppColors.mainDark,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static Widget _scoring(ModularReportSection section) {
    final value = section.value;
    if (value is Map) {
      // DocSera-Pro shape: { 'answers': {q0: 1, q1: 2}, 'total_score': 5 }
      final totalScore = value['total_score'];
      final answers = value['answers'];
      final name = value['name']?.toString() ?? '';
      final score = totalScore?.toString() ?? value['score']?.toString() ?? '';
      final interpretation = value['interpretation']?.toString() ?? '';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score badge
          Row(
            children: [
              if (name.isNotEmpty)
                Flexible(
                  child: Text(name,
                      style: TextStyle(
                          fontSize: 12.sp, color: AppColors.mainDark)),
                ),
              if (score.isNotEmpty) ...[
                SizedBox(width: 6.w),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppColors.main.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    score,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.main,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (interpretation.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(interpretation,
                  style: TextStyle(
                      fontSize: 11.sp, color: AppColors.textSubColor)),
            ),
          // Show individual answers if available
          if (answers is Map && answers.isNotEmpty) ...[
            SizedBox(height: 8.h),
            ...answers.entries.map((e) {
              return Padding(
                padding: EdgeInsets.only(bottom: 3.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key.toString(),
                        style: TextStyle(
                            fontSize: 11.sp, color: AppColors.textSubColor)),
                    Text(
                      e.value.toString(),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Montserrat',
                        color: AppColors.mainDark,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      );
    }
    return _plainText(value.toString());
  }

  static Widget _checklist(ModularReportSection section) {
    final value = section.value;

    // DocSera-Pro shape:  { 'Reflexes': 'Normal', 'Pupils': 'Abnormal' }
    // Generic shape:      [ {'label': 'X', 'checked': true}, ... ]

    final entries = <MapEntry<String, String>>[];

    if (value is Map) {
      for (final e in value.entries) {
        final key = e.key.toString();
        final val = e.value?.toString() ?? '';
        if (val.isNotEmpty && val != 'null') {
          entries.add(MapEntry(key, val));
        }
      }
    } else if (value is List) {
      for (final item in value) {
        if (item is Map) {
          final label = item['label']?.toString() ?? '';
          final checked =
              item['checked'] == true || item['status'] == 'checked';
          entries.add(MapEntry(label, checked ? '✓' : '✗'));
        }
      }
    }

    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((e) {
        final isPositive = e.value.toLowerCase() == 'normal' ||
            e.value == '✓' ||
            e.value.toLowerCase() == 'yes';
        return Padding(
          padding: EdgeInsets.only(bottom: 3.h),
          child: Row(
            children: [
              Icon(
                isPositive
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16.sp,
                color: isPositive ? AppColors.main : Colors.grey.shade400,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 12.sp, color: AppColors.mainDark),
                    children: [
                      TextSpan(
                        text: e.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: '  ${e.value}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static Widget _referral(dynamic value) {
    if (value is! Map) return _plainText(value?.toString() ?? '');
    final map = Map<String, dynamic>.from(value);
    final specialty = map['specialty_label']?.toString() ?? '';
    final doctor = map['doctor_name']?.toString() ?? '';
    final reason = map['reason']?.toString() ?? '';
    final urgency = map['urgency']?.toString() ?? 'routine';

    Color urgencyColor;
    String urgencyLabel;
    switch (urgency) {
      case 'emergency':
        urgencyColor = const Color(0xFFE53935);
        urgencyLabel = 'طارئ';
        break;
      case 'urgent':
        urgencyColor = const Color(0xFFFB8C00);
        urgencyLabel = 'عاجل';
        break;
      case 'routine':
      default:
        urgencyColor = const Color(0xFF5C6BC0);
        urgencyLabel = 'روتيني';
        break;
    }

    Widget row(String label, String val) {
      if (val.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(bottom: 3.h),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
                fontSize: 12.sp, height: 1.5, color: AppColors.mainDark),
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: val),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row('التخصص', specialty),
        row('الطبيب', doctor),
        row('السبب', reason),
        SizedBox(height: 4.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: urgencyColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: urgencyColor.withOpacity(0.5)),
          ),
          child: Text(
            urgencyLabel,
            style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: urgencyColor),
          ),
        ),
      ],
    );
  }

  static Widget _customTable(dynamic value) {
    if (value is! Map) return _plainText(value?.toString() ?? '');
    final map = Map<String, dynamic>.from(value);
    final columns = ((map['columns'] ?? map['headers']) as List?)
            ?.map((e) => e?.toString() ?? '')
            .toList() ??
        const <String>[];
    final rawRows = (map['rows'] as List?)
            ?.whereType<List>()
            .map<List<String>>(
                (r) => r.map((e) => e?.toString() ?? '').toList())
            .toList() ??
        const <List<String>>[];
    if (columns.isEmpty || rawRows.isEmpty) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 40,
          horizontalMargin: 12,
          columnSpacing: 18,
          headingRowColor:
              WidgetStateProperty.all(AppColors.main.withOpacity(0.08)),
          headingTextStyle: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.mainDark,
          ),
          dataTextStyle: TextStyle(
            fontSize: 11.sp,
            color: AppColors.mainDark,
          ),
          columns: [
            for (final c in columns) DataColumn(label: Text(c)),
          ],
          rows: [
            for (final r in rawRows)
              DataRow(cells: [
                for (int i = 0; i < columns.length; i++)
                  DataCell(Text(i < r.length ? r[i] : '')),
              ]),
          ],
        ),
      ),
    );
  }

  static Widget _attachments(dynamic value) {
    final items = (value is List) ? value : [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final name =
            (item is Map) ? (item['name']?.toString() ?? 'مرفق') : item.toString();
        return Padding(
          padding: EdgeInsets.only(bottom: 3.h),
          child: Row(
            children: [
              Icon(Icons.attach_file_rounded,
                  size: 14.sp, color: AppColors.main.withOpacity(0.6)),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(name,
                    style: TextStyle(
                        fontSize: 12.sp, color: AppColors.mainDark)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
