import 'dart:convert';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/appointment_details.dart';
import 'package:docsera/screens/doctors/appointment/confirmation_page.dart'; // يحتوي AppointmentConfirmedPage
import 'package:docsera/screens/doctors/appointment/waiting_for_confirmation_page.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../widgets/base_scaffold.dart';

class ConfirmationPage extends StatefulWidget {
  final AppointmentDetails appointmentDetails;

  // لم نعد نستخدمه فعليًا للكتابة (ننشئ صفًا جديدًا)، لكنه موجود للتوافق
  final String appointmentId;

  final DateTime appointmentTimestamp; // عادةً UTC من صفحة المواعيد
  final String appointmentTime;        // نص جاهز 12 ساعة من صفحة المواعيد (AM/PM)

  /// اسم السبب (label) — اختياري. إن لم يصل، سنجلبه من الجدول.
  final String? reasonLabel;

  const ConfirmationPage({
    Key? key,
    required this.appointmentDetails,
    required this.appointmentId,
    required this.appointmentTimestamp,
    required this.appointmentTime,
    this.reasonLabel,
  }) : super(key: key);

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  bool _submitting = false;
  String? _reasonLabel; // الاسم المقروء للسبب
  bool _loadingReason = false;

  @override
  void initState() {
    super.initState();
    _initReasonLabel();
  }

  Future<void> _initReasonLabel() async {
    if ((widget.reasonLabel ?? '').trim().isNotEmpty) {
      _reasonLabel = widget.reasonLabel!.trim();
      setState(() {});
      return;
    }
    final reasonId = widget.appointmentDetails.reason;
    if (reasonId.trim().isEmpty) return;

    try {
      setState(() => _loadingReason = true);
      final supabase = Supabase.instance.client;
      final row = await supabase
          .from('appointment_reasons')
          .select('label')
          .eq('id', reasonId)
          .maybeSingle();

      _reasonLabel = (row?['label'] as String?)?.trim();
    } catch (_) {
      // تجاهل
    } finally {
      if (mounted) setState(() => _loadingReason = false);
    }
  }

  Future<String> _ensureReasonLabelText() async {
    if ((_reasonLabel ?? '').trim().isNotEmpty) return _reasonLabel!.trim();
    if ((widget.reasonLabel ?? '').trim().isNotEmpty) return widget.reasonLabel!.trim();

    final reasonId = widget.appointmentDetails.reason;
    if (reasonId.trim().isEmpty) return reasonId; // fallback

    try {
      final supabase = Supabase.instance.client;
      final row = await supabase
          .from('appointment_reasons')
          .select('label')
          .eq('id', reasonId)
          .maybeSingle();
      final label = (row?['label'] as String?)?.trim();
      if ((label ?? '').isNotEmpty) return label!;
    } catch (_) {}
    return reasonId; // آخر حل
  }

  Future<String> _ensureAccountName(String? userId, String currentName) async {
    if ((currentName).trim().isNotEmpty) return currentName.trim();
    if (userId == null || userId.isEmpty) return '';

    try {
      final supabase = Supabase.instance.client;
      final row = await supabase
          .from('users')
          .select('full_name,name,username')
          .eq('id', userId)
          .maybeSingle();

      final a = (row?['full_name'] as String?) ?? '';
      final b = (row?['name'] as String?) ?? '';
      final c = (row?['username'] as String?) ?? '';
      final best = [a, b, c].firstWhere((s) => (s).trim().isNotEmpty, orElse: () => '');
      return best.trim();
    } catch (_) {
      return '';
    }
  }

  /// يحوّل clinicAddress الوارد من AppointmentDetails إلى Map جاهزة للحفظ كـ jsonb.
  Map<String, dynamic>? _normalizeClinicAddressToMap(dynamic raw) {
    if (raw == null) return null;

    if (raw is Map<String, dynamic>) {
      return raw;
    }

    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return null;
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // لو السلسلة ليست JSON صالح، نتجاهلها
      }
      return null;
    }

    // أنواع أخرى نتجاهلها
    return null;
  }

  Future<void> _confirmBooking(BuildContext context) async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final supabase = Supabase.instance.client;

      // 👤 المستخدم
      final authUser = supabase.auth.currentUser;
      String? userId = authUser?.id;
      String userName = (authUser?.userMetadata?['full_name'] as String?) ?? '';

      if (userId == null || userId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('userId');
        userName = prefs.getString('userName') ?? userName;
      }
      if (userId == null || userId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.loginFirst)),
        );
        setState(() => _submitting = false);
        return;
      }

      final reasonId = widget.appointmentDetails.reasonId ?? '';
      final reasonText = await _ensureReasonLabelText();


      // ⚙️ هل الطبيب يتطلب موافقة؟
      final doctorInfo = await supabase
          .from('doctors')
          .select('require_confirmation')
          .eq('id', widget.appointmentDetails.doctorId)
          .maybeSingle();

      final requiresConfirmation =
          (doctorInfo?['require_confirmation'] as bool?) ?? true;

      // 🕒 نحفظ UTC في timestamp/booking_timestamp
      final bookingTimestampUtc = DateTime.now().toUtc();
      final slotUtc = widget.appointmentTimestamp.toUtc();

      final prefs = await SharedPreferences.getInstance();
      final accountName = prefs.getString('userName') ?? "Unknown";
      // العنوان كـ JSON (Map) للحفظ في jsonb
      final Map<String, dynamic>? addrMap =
      _normalizeClinicAddressToMap(widget.appointmentDetails.clinicAddress);

      // تطبيع جنس الطبيب إلى العربية عند وجود قيم إنجليزية
      final String rawGender = widget.appointmentDetails.doctorGender;
      final String normalizedDoctorGender = () {
        final g = rawGender.trim().toLowerCase();
        if (g == 'male' || g == 'm') return 'ذكر';
        if (g == 'female' || g == 'f') return 'أنثى';
        return rawGender; // اتركه كما هو إن كان عربي أصلاً
      }();

      // 🆕 الإدخال — ❌ لا نرسل appointment_date/time: الـ Trigger سيحسبهما من timestamp (UTC+3)
      final insertPayload = {
        'doctor_id': widget.appointmentDetails.doctorId,
        'user_id': userId,
        'timestamp': slotUtc.toIso8601String(),                    // UTC
        'reason_id': reasonId.isNotEmpty ? reasonId : null,   // ✅ خزن الـ id
        'reason': reasonText,                                // النص للعرض
        'booked': true,
        'new_patient': widget.appointmentDetails.newPatient,
        'patient_name': widget.appointmentDetails.patientName,
        'user_gender': widget.appointmentDetails.patientGender,
        'user_age': widget.appointmentDetails.patientAge,
        'clinic_address': addrMap,
        'location': widget.appointmentDetails.location,
        'doctor_title': widget.appointmentDetails.doctorTitle,
        'doctor_image': widget.appointmentDetails.image,
        'doctor_specialty': widget.appointmentDetails.specialty,
        'account_name': accountName,
        'booking_timestamp': bookingTimestampUtc.toIso8601String(),// UTC
        'doctor_name': widget.appointmentDetails.doctorName,
        'doctor_gender': normalizedDoctorGender,                   // عربي
        'clinic': widget.appointmentDetails.clinicName,
        'is_docsera_user': true,
        'booked_via': 'DocSera',
        'attachments': null,
        'is_confirmed': !requiresConfirmation,
        if (widget.appointmentDetails.isRelative)
          'relative_id': widget.appointmentDetails.patientId,
      };

      print("📝 [ConfirmationPage] Insert Payload:");
      insertPayload.forEach((key, value) {
        print("   $key: $value");
      });

// ركز على الموقع
      final loc = widget.appointmentDetails.location;
      if (loc == null || (loc is Map && loc.isEmpty)) {
        print("⚠️ [ConfirmationPage] Location is EMPTY or NULL!");
      } else {
        print("✅ [ConfirmationPage] Location to insert = $loc");
      }

      final inserted = await supabase
          .from('appointments')
          .insert(insertPayload)
          .select('id')
          .single();

      // 📌 إضافة الطبيب إلى قائمة الأطباء الذين زارهم المريض/القريب
      try {
        final targetTable =
        widget.appointmentDetails.isRelative ? 'relatives' : 'users';
        final targetId = widget.appointmentDetails.patientId;

        final existingDoctorsResponse = await supabase
            .from(targetTable)
            .select('doctors')
            .eq('id', targetId)
            .maybeSingle();

        List<String> existingDoctors = [];
        if (existingDoctorsResponse != null &&
            existingDoctorsResponse['doctors'] is List) {
          existingDoctors = List<String>.from(existingDoctorsResponse['doctors']);
        }

        if (!existingDoctors.contains(widget.appointmentDetails.doctorId)) {
          existingDoctors.add(widget.appointmentDetails.doctorId);
          await supabase
              .from(targetTable)
              .update({'doctors': existingDoctors})
              .eq('id', targetId);
        }
      } catch (_) {
        // تجاهل أخطاء التحديث غير الحرجة
      }

      // ⏭️ التوجيه — للعرض يمكنك تمرير الوقت النصّي القادم من الصفحة الحالية
      final navPayload = {
        'doctorId': widget.appointmentDetails.doctorId,
        'doctorName': widget.appointmentDetails.doctorName,
        'doctorTitle': widget.appointmentDetails.doctorTitle,
        'doctorGender': normalizedDoctorGender,
        'doctor_image': widget.appointmentDetails.image,
        'specialty': widget.appointmentDetails.specialty,
        'clinic': widget.appointmentDetails.clinicName,
        'clinicAddress': addrMap, // Map لسهولة العرض
        'location': widget.appointmentDetails.location,
        'patientName': widget.appointmentDetails.patientName,
        'reasonId': reasonId,       // ✅ جديد
        'reason': reasonText,       // النص للعرض
        'timestamp': slotUtc.toIso8601String(),                    // UTC
        'bookingTimestamp': bookingTimestampUtc.toIso8601String(), // UTC
        'appointmentId': inserted['id'],
        // للعرض فقط (من الصفحة): 12 ساعة جاهز
        'appointmentTimeDisplay': widget.appointmentTime,
      };


      if (!mounted) return;

      if (requiresConfirmation) {
        Navigator.pushReplacement(
          context,
          fadePageRoute(WaitingForConfirmationPage(appointment: navPayload)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          fadePageRoute(AppointmentConfirmedPage(appointment: navPayload)),
        );
        print("🧭 [ConfirmationPage] Navigating to AppointmentConfirmedPage");
        print("   appointmentId = ${navPayload['appointmentId']}");
      }
    } catch (e) {
      final msg = e.toString().toLowerCase().contains('duplicate') ||
          e.toString().toLowerCase().contains('unique')
          ? AppLocalizations.of(context)!.slotAlreadyBooked
          : '${AppLocalizations.of(context)!.errorBookingAppointment}: $e';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // للعرض فقط:
    // - التاريخ من timestamp محلي
    // - الوقت من widget.appointmentTime (جاهز 12 ساعة)
    final localTs = widget.appointmentTimestamp.toLocal();
    final dateOnly = DateFormat(
      'EEEE, d MMMM',
      Localizations.localeOf(context).toString(),
    ).format(localTs);
    final displayDateTime = '$dateOnly • ${widget.appointmentTime}';

    final imageResult = resolveDoctorImagePathAndWidget(
      doctor: {
        "doctor_image": widget.appointmentDetails.image,
        "gender": widget.appointmentDetails.doctorGender,
        "title": widget.appointmentDetails.doctorTitle,
      },
      width: 40,
      height: 40,
    );
    final imageProvider = imageResult.imageProvider;

    // سبب قابل للعرض
    final shownReason =
    (_reasonLabel ?? widget.reasonLabel)?.trim().isNotEmpty == true
        ? (_reasonLabel ?? widget.reasonLabel)!.trim()
        : widget.appointmentDetails.reason;

    // عنوان للعرض من Map (مع fallback لو null)
    final Map<String, dynamic>? addrMap =
    _normalizeClinicAddressToMap(widget.appointmentDetails.clinicAddress);
    final String addressLine = (addrMap == null)
        ? ''
        : [
      addrMap['street'],
      addrMap['city'],
    ].where((x) => (x is String) && x.trim().isNotEmpty).join(', ');

    return BaseScaffold(
      titleAlignment: 2,
      height: 75.h,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.background2.withOpacity(0.3),
                radius: 18.r,
                backgroundImage: imageProvider,
              ),
              Positioned(
                bottom: 0,
                right: isArabic ? null : 0,
                left: isArabic ? 0 : null,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: AppColors.main, width: 1),
                  ),
                  child: Icon(Icons.lock, color: AppColors.main, size: 14.sp),
                ),
              ),
            ],
          ),
          SizedBox(width: 15.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayDateTime,
                style: AppTextStyles
                    .getText2(context)
                    .copyWith(fontWeight: FontWeight.w700, color: AppColors.whiteText),
              ),
              SizedBox(height: 3.h),
              Text(
                AppLocalizations.of(context)!.slotReservedFor,
                style: AppTextStyles
                    .getText3(context)
                    .copyWith(fontWeight: FontWeight.w300, color: AppColors.whiteText),
              ),
            ],
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // بطاقة المعلومات
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300, width: 0.5),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                children: [
                  _buildDoctorInfo(context),
                  Divider(color: Colors.grey.shade300, thickness: 1, height: 20.h),
                  _buildAppointmentDetails(context, displayDateTime, shownReason, addressLine),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // زر التأكيد
            ElevatedButton(
              onPressed: _submitting ? null : () => _confirmBooking(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainDark,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 10.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                minimumSize: Size(double.infinity, 50.w),
              ),
              child: _submitting
                  ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.whiteText,),
              )
                  : Text(
                AppLocalizations.of(context)!.confirmAppointment.toUpperCase(),
                style: AppTextStyles.getTitle1(context).copyWith(fontSize: 10.sp, color: Colors.white),
              ),
            ),
            SizedBox(height: 15.h),

            // ملاحظة
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppColors.main.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.mainDark, size: 18.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: AppLocalizations.of(context)!.byConfirming,
                        style: AppTextStyles.getText3(context).copyWith(color: Colors.black87),
                        children: [
                          TextSpan(
                            text: AppLocalizations.of(context)!.agreeToHonor,
                            style: AppTextStyles.getText3(context).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorInfo(BuildContext context) {
    final doctorFullName = widget.appointmentDetails.doctorTitle.isNotEmpty
        ? "${widget.appointmentDetails.doctorTitle} ${widget.appointmentDetails.doctorName}"
        : widget.appointmentDetails.doctorName;

    final imageResult = resolveDoctorImagePathAndWidget(
      doctor: {
        "doctor_image": widget.appointmentDetails.image,
        "gender": widget.appointmentDetails.doctorGender,
        "title": widget.appointmentDetails.doctorTitle,
      },
      width: 50,
      height: 50,
    );
    final imageProvider = imageResult.imageProvider;

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.orange.withOpacity(0.3),
          radius: 25.r,
          backgroundImage: imageProvider,
        ),
        SizedBox(width: 12.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doctorFullName,
              style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.blackText),
            ),
            Text(
              widget.appointmentDetails.specialty,
              style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp, color: Colors.black54),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        children: [
          Icon(icon, color: AppColors.mainDark, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.sp, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentDetails(
      BuildContext context,
      String displayDateTime,
      String shownReason,
      String addressLine,
      ) {
    return Column(
      children: [
        _buildDetailRow(Icons.person, widget.appointmentDetails.patientName),
        _buildDetailRow(Icons.calendar_today, displayDateTime), // وقت 12-ساعة للعرض
        _buildDetailRow(Icons.location_on, addressLine),
        _buildDetailRow(Icons.local_hospital, shownReason),   // اسم السبب لا الـ id
      ],
    );
  }
}
