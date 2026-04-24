import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/screens/home/Document/document_preview_page.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/modular_report_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  static Widget render(ModularReportSection section, BuildContext context) {
    final label = section.label ?? _sectionLabels[section.type] ?? section.type;
    final content = _renderContent(section, context);
    if (content == null) return const SizedBox.shrink();
    return PatientSectionCard(title: label, child: content);
  }

  /// Renders a loading placeholder for heavy sections being lazy-loaded.
  static Widget renderLoading(ModularReportSection section) {
    final label = section.label ?? _sectionLabels[section.type] ?? section.type;
    return PatientSectionCard(
      title: label,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.main,
          ),
        ),
      ),
    );
  }

  static Widget? _renderContent(ModularReportSection section, BuildContext context) {
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

      case 'body_map':
        return _bodyMap(section.value);

      case 'image_comparison':
        return _imageComparison(section.value, context);

      case 'attachments':
        return _attachments(section.value, context);

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

  static const _svgAspects = <String, double>{
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

  static const _categoryColors = <String, Color>{
    'pain': Color(0xFFE53935),
    'lesion': Color(0xFFFB8C00),
    'swelling': Color(0xFF1E88E5),
    'surgical': Color(0xFF8E24AA),
    'other': Color(0xFF757575),
  };

  static const _categoryLabels = <String, String>{
    'pain': 'ألم',
    'lesion': 'آفة',
    'swelling': 'تورم',
    'surgical': 'جراحي',
    'other': 'أخرى',
  };

  static Widget? _bodyMap(dynamic value) {
    if (value is! Map) return null;
    final pins = (value['pins'] as List?)?.whereType<Map>().toList() ?? [];
    if (pins.isEmpty) return null;

    final diagramType = value['diagram_type']?.toString() ?? '';
    final assetPath = _diagramTypeToAsset[diagramType] ??
        _diagramTypeToAsset['full_body_anterior']!;
    final aspect = _svgAspects[assetPath] ?? (2328.0 / 1052.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SVG diagram with pin overlay
        Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth * 0.7;
              final diagramWidth = maxW;
              final diagramHeight = diagramWidth * aspect;

              return SizedBox(
                width: diagramWidth,
                height: diagramHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: SvgPicture.asset(
                        assetPath,
                        fit: BoxFit.contain,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF424242),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    // Pin markers
                    for (int i = 0; i < pins.length; i++)
                      Builder(builder: (context) {
                        final pin = pins[i];
                        final px = (pin['x'] as num?)?.toDouble() ?? 0.0;
                        final py = (pin['y'] as num?)?.toDouble() ?? 0.0;
                        final cat = pin['category']?.toString() ?? 'other';
                        final color =
                            _categoryColors[cat] ?? _categoryColors['other']!;
                        const pinSize = 20.0;

                        return Positioned(
                          left: px * diagramWidth - pinSize / 2,
                          top: py * diagramHeight - pinSize / 2,
                          child: Container(
                            width: pinSize,
                            height: pinSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        ),
        SizedBox(height: 12.h),

        // Pin legend
        ...pins.asMap().entries.map((entry) {
          final pin = entry.value;
          final cat = pin['category']?.toString() ?? 'other';
          final color = _categoryColors[cat] ?? _categoryColors['other']!;
          final label = pin['label']?.toString() ?? '';
          final note = pin['note']?.toString() ?? '';
          final catLabel = _categoryLabels[cat] ?? 'أخرى';

          return Padding(
            padding: EdgeInsets.only(bottom: 6.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20.w,
                  height: 20.w,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${entry.key + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.isNotEmpty ? label : catLabel,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mainDark,
                        ),
                      ),
                      if (note.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 1.h),
                          child: Text(
                            note,
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              color: AppColors.textSubColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Image Comparison ──

  static void _openFullScreenImage(BuildContext context, String? url) {
    if (url == null || url.isEmpty) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    Widget imageWidget;
    if (url.startsWith('data:')) {
      final dataStr = url.split(',').last;
      final bytes = base64Decode(dataStr);
      imageWidget = Image.memory(bytes, fit: BoxFit.contain);
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
        ),
        errorWidget: (_, __, ___) => const Icon(
          Icons.image_not_supported_rounded,
          color: Colors.white38,
          size: 64,
        ),
      );
    }

    entry = OverlayEntry(
      builder: (_) {
        final padding = MediaQuery.of(context).padding;
        return Material(
          color: Colors.black,
          child: SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(child: imageWidget),
                ),
                Positioned(
                  top: padding.top + 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () {
                      if (entry.mounted) entry.remove();
                    },
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
  }

  static Widget _buildImage(String? url, {double? height}) {
    if (url == null || url.isEmpty) {
      return Container(
        height: height ?? 150,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: const Center(
          child: Icon(Icons.image_rounded, size: 32, color: Colors.grey),
        ),
      );
    }
    if (url.startsWith('data:')) {
      final dataStr = url.split(',').last;
      final bytes = base64Decode(dataStr);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: Image.memory(
          bytes,
          height: height ?? 150,
          fit: BoxFit.cover,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: CachedNetworkImage(
        imageUrl: url,
        height: height ?? 150,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: height ?? 150,
          color: Colors.grey.shade200,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.main,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          height: height ?? 150,
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.broken_image_rounded, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  static Widget? _imageComparison(dynamic value, BuildContext context) {
    if (value is! Map) return null;
    final mode = value['mode']?.toString() ?? '';
    final images = (value['images'] as List?)?.whereType<Map>().toList() ?? [];
    if (images.isEmpty) return null;

    if (mode == 'before_after') {
      final before = images.where((i) => i['role'] == 'before').firstOrNull;
      final after = images.where((i) => i['role'] == 'after').firstOrNull;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (before != null)
            Expanded(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _openFullScreenImage(context, before['url']?.toString()),
                    child: _buildImage(before['url']?.toString(), height: 160.h),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'قبل',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mainDark,
                    ),
                  ),
                  if ((before['date']?.toString() ?? '').isNotEmpty)
                    Text(
                      before['date'].toString(),
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.textSubColor,
                      ),
                    ),
                  if ((before['note']?.toString() ?? '').isNotEmpty)
                    Text(
                      before['note'].toString(),
                      style: TextStyle(
                        fontSize: 9.5.sp,
                        color: AppColors.textSubColor,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          SizedBox(width: 8.w),
          if (after != null)
            Expanded(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _openFullScreenImage(context, after['url']?.toString()),
                    child: _buildImage(after['url']?.toString(), height: 160.h),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'بعد',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mainDark,
                    ),
                  ),
                  if ((after['date']?.toString() ?? '').isNotEmpty)
                    Text(
                      after['date'].toString(),
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.textSubColor,
                      ),
                    ),
                  if ((after['note']?.toString() ?? '').isNotEmpty)
                    Text(
                      after['note'].toString(),
                      style: TextStyle(
                        fontSize: 9.5.sp,
                        color: AppColors.textSubColor,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
        ],
      );
    }

    // Progress timeline
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: images.asMap().entries.map((entry) {
        final img = entry.value;
        final date = img['date']?.toString() ?? '';
        final note = img['note']?.toString() ?? '';
        return SizedBox(
          width: 100.w,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _openFullScreenImage(context, img['url']?.toString()),
                child: _buildImage(img['url']?.toString(), height: 100.h),
              ),
              SizedBox(height: 2.h),
              if (date.isNotEmpty)
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mainDark,
                  ),
                ),
              if (note.isNotEmpty)
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    color: AppColors.textSubColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

  static Widget _attachments(dynamic value, BuildContext context) {
    final items = (value is List) ? value : [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final map = (item is Map)
            ? Map<String, dynamic>.from(item)
            : <String, dynamic>{};
        final name = map['name']?.toString() ?? 'مرفق';
        final url = map['url']?.toString() ?? '';
        final type = map['type']?.toString() ?? '';
        final encrypted = map['encrypted'] == true;

        return GestureDetector(
          onTap: url.isNotEmpty
              ? () => _openReportAttachment(
                    context,
                    url: url,
                    name: name,
                    type: type,
                    encrypted: encrypted,
                  )
              : null,
          child: Padding(
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
                if (url.isNotEmpty)
                  Icon(Icons.open_in_new_rounded,
                      size: 12.sp, color: AppColors.main.withOpacity(0.4)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  static Future<void> _openReportAttachment(
    BuildContext context, {
    required String url,
    required String name,
    required String type,
    required bool encrypted,
  }) async {
    try {
      final signedUrl = await Supabase.instance.client.storage
          .from('chat.attachments')
          .createSignedUrl(url, 60 * 60);

      final doc = UserDocument(
        id: '',
        userId: '',
        name: name,
        type: 'attachment',
        fileType: type == 'pdf' ? 'pdf' : 'image',
        patientId: '',
        previewUrl: signedUrl,
        pages: [signedUrl],
        uploadedAt: DateTime.now(),
        uploadedById: '',
        encrypted: encrypted,
      );

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentPreviewPage(
            document: doc,
            showActions: false,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء فتح المرفق')),
      );
    }
  }
}
