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
      case 'referral':
        return _plainText(section.value.toString());

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
        return _vitalsTable(section.value);

      case 'scoring':
        return _scoring(section.value);

      case 'checklist':
        return _checklist(section.value);

      case 'attachments':
        return _attachments(section.value);

      default:
        if (section.value is String) return _plainText(section.value.toString());
        return null;
    }
  }

  static Widget _plainText(String text) {
    return Text(text, style: TextStyle(fontSize: 13.sp, height: 1.5));
  }

  static Widget _bulletList(dynamic value) {
    final items = (value is List) ? value.map((e) => e.toString()).toList() : [value.toString()];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => Padding(
        padding: EdgeInsets.only(bottom: 4.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 5.w, height: 5.w,
              margin: EdgeInsets.only(top: 7.h, left: 6.w),
              decoration: BoxDecoration(color: AppColors.main, shape: BoxShape.circle),
            ),
            SizedBox(width: 4.w),
            Expanded(child: Text(item, style: TextStyle(fontSize: 13.sp, height: 1.4))),
          ],
        ),
      )).toList(),
    );
  }

  static Widget _numberedList(dynamic value) {
    final items = (value is List) ? value.map((e) => e.toString()).toList() : [value.toString()];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((entry) => Padding(
        padding: EdgeInsets.only(bottom: 4.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${entry.key + 1}. ', style: TextStyle(
              fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.main)),
            Expanded(child: Text(entry.value, style: TextStyle(fontSize: 13.sp))),
          ],
        ),
      )).toList(),
    );
  }

  static Widget _diagnosis(dynamic value) {
    if (value is Map) {
      final text = value['text']?.toString() ?? '';
      final icd = value['icd_code']?.toString() ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: TextStyle(fontSize: 13.sp)),
          if (icd.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppColors.main.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(icd, style: TextStyle(
                fontSize: 11.sp, color: AppColors.main, fontFamily: 'Montserrat')),
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
            margin: EdgeInsets.only(bottom: 6.h),
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name ${dosage.isNotEmpty ? dosage : ""}', style: TextStyle(
                  fontSize: 13.sp, fontWeight: FontWeight.w600)),
                if (frequency.isNotEmpty || duration.isNotEmpty)
                  Text([frequency, duration].where((e) => e.isNotEmpty).join(' · '),
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
                if (notes.isNotEmpty)
                  Text(notes, style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
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
          final name = item['exam_name']?.toString() ?? item['name']?.toString() ?? '';
          final notes = item['notes']?.toString() ?? '';
          return Padding(
            padding: EdgeInsets.only(bottom: 4.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5.w, height: 5.w,
                  margin: EdgeInsets.only(top: 7.h, left: 6.w),
                  decoration: BoxDecoration(color: AppColors.main, shape: BoxShape.circle),
                ),
                SizedBox(width: 4.w),
                Expanded(child: Text(
                  notes.isNotEmpty ? '$name ($notes)' : name,
                  style: TextStyle(fontSize: 13.sp),
                )),
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
            Text('الموعد: $dateDisplay', style: TextStyle(
              fontSize: 13.sp, fontWeight: FontWeight.w600)),
          if (notes.isNotEmpty)
            Text(notes, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
        ],
      );
    }
    return _plainText(value.toString());
  }

  static Widget _vitalsTable(dynamic value) {
    final items = (value is List) ? value : [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: items.map((item) {
        if (item is Map) {
          final name = item['name']?.toString() ?? '';
          final val = item['value']?.toString() ?? '';
          final unit = item['unit']?.toString() ?? '';
          return Padding(
            padding: EdgeInsets.only(bottom: 4.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700)),
                Text('$val $unit', style: TextStyle(
                  fontSize: 12.sp, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }

  static Widget _scoring(dynamic value) {
    if (value is Map) {
      final name = value['name']?.toString() ?? '';
      final score = value['score']?.toString() ?? '';
      final interpretation = value['interpretation']?.toString() ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$name: $score', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
          if (interpretation.isNotEmpty)
            Text(interpretation, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
        ],
      );
    }
    return _plainText(value.toString());
  }

  static Widget _checklist(dynamic value) {
    final items = (value is List) ? value : [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        if (item is Map) {
          final label = item['label']?.toString() ?? '';
          final checked = item['checked'] == true || item['status'] == 'checked';
          return Padding(
            padding: EdgeInsets.only(bottom: 4.h),
            child: Row(
              children: [
                Icon(
                  checked ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18.sp,
                  color: checked ? AppColors.main : Colors.grey,
                ),
                SizedBox(width: 6.w),
                Text(label, style: TextStyle(fontSize: 13.sp)),
              ],
            ),
          );
        }
        return _plainText(item.toString());
      }).toList(),
    );
  }

  static Widget _attachments(dynamic value) {
    final items = (value is List) ? value : [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final name = (item is Map) ? (item['name']?.toString() ?? 'مرفق') : item.toString();
        return Padding(
          padding: EdgeInsets.only(bottom: 4.h),
          child: Row(
            children: [
              Icon(Icons.attach_file, size: 16.sp, color: Colors.grey),
              SizedBox(width: 4.w),
              Text(name, style: TextStyle(fontSize: 13.sp)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
