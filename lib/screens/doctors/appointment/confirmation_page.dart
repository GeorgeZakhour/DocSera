import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/doctors/appointment/select_patient_page.dart';
import 'package:docsera/screens/home/appointment/appointment_details_page.dart';
import 'package:docsera/screens/home/appointment/send_document.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/utils/time_utils.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppointmentConfirmedPage extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const AppointmentConfirmedPage({Key? key, required this.appointment})
      : super(key: key);

  /// إضافة إلى التقويم: نستخدم اللحظة المطلقة من timestamp (محلي الجهاز) ومدة قابلة للتخصيص
  void _addToCalendar(BuildContext context, {int clinicOffsetMinutes = 180}) {
    final appt = appointment;

    // 1) نقرأ الـ timestamp كـ UTC
    final tsUtc = DateTime.parse(appt['timestamp'].toString()).toUtc();

    // 2) وقت العيادة (UTC +3)
    final clinicWall = tsUtc.add(Duration(minutes: clinicOffsetMinutes));
    final startLocal = DateTime(
      clinicWall.year,
      clinicWall.month,
      clinicWall.day,
      clinicWall.hour,
      clinicWall.minute,
    );

    // 3) المدة
    final duration = (appt['durationMinutes'] is int)
        ? appt['durationMinutes'] as int
        : 30;
    final endLocal = startLocal.add(Duration(minutes: duration));

    // 4) العنوان
    final addr = (appt['clinicAddress'] ?? appt['clinic_address'] ?? const {}) as Map<String, dynamic>;
    final location = [
      addr['street']?.toString(),
      addr['buildingNr']?.toString(),
      addr['city']?.toString(),
      addr['country']?.toString(),
    ].where((s) => (s ?? '').toString().trim().isNotEmpty).join(', ');

    // 5) اسم الطبيب
    final doctorName = [
      (appt['doctorTitle'] ?? appt['doctor_title'] ?? '').toString().trim(),
      (appt['doctorName']  ?? appt['doctor_name']  ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    // 6) نصوص إضافية
    final clinicName = ((appt['clinicName'] ?? appt['clinic']) ?? '').toString().trim();
    final reasonText = (appt['reason'] ?? AppLocalizations.of(context)!.notSpecified).toString();

    // 7) بناء الحدث
    final event = Event(
      title: AppLocalizations.of(context)!.appointmentWithLabel(doctorName).trim(),
      description:
      "${AppLocalizations.of(context)!.clinicDetails}: "
          "${clinicName.isNotEmpty ? clinicName : AppLocalizations.of(context)!.clinicNotAvailable}\n"
          "${AppLocalizations.of(context)!.reasonForAppointment}: $reasonText",
      location: location,
      startDate: startLocal,
      endDate: endLocal,
      allDay: false,
    );

    // 8) إضافة للتقويم
    Add2Calendar.addEvent2Cal(event).then((success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? AppLocalizations.of(context)!.appointmentAddedToCalendar
                : AppLocalizations.of(context)!.appointmentFailedToAdd,
          ),
        ),
      );
    });
  }

  String get _appointmentId {
    return appointment['id']?.toString()
        ?? appointment['appointmentId']?.toString()
        ?? "";
  }

  List<Map<String, dynamic>> appointmentAttachments() {
    final raw = appointment['attachments'];

    if (raw == null) return [];

    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return [];
  }
  Widget _attachmentTile(Map<String, dynamic> att) {
    final name = att['name'] ?? 'Document';
    final type = att['file_type'] ?? '';
    final uploadDate = att['uploaded_at']?.toString().substring(0, 10) ?? '';
    final pages = att['page_count'] ?? 1;

    final icon = type == 'pdf'
        ? Icons.picture_as_pdf
        : Icons.image;

    return Container(
      margin: EdgeInsets.only(top: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.main, size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    )),
                SizedBox(height: 3),
                Text(
                  type == 'pdf' ? "$pages pages" : "Image",
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  uploadDate,
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              _openAttachment(att);
            },
            child: Text("View", style: TextStyle(color: AppColors.main)),
          ),
        ],
      ),
    );
  }

  Future<void> _openAttachment(Map<String, dynamic> att) async {
    final path = att['paths'][0];
    final bucket = att['bucket'];

    final url = Supabase.instance.client.storage
        .from(bucket)
        .getPublicUrl(path);

    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => AttachmentViewerPage(
    //       url: url,
    //       type: att['file_type'],
    //     ),
    //   ),
    // );
  }




  @override
  Widget build(BuildContext context) {
    final formattedDate = TimezoneUtils.formatBusinessDate(context, appointment);
    final tsUtc = DateTime.parse(appointment['timestamp'].toString()).toUtc();
    final formattedTime = TimezoneUtils.format12hLocalized(context, tsUtc);


    // مدة الموعد (اختياري لعرضها بجانب الوقت)
    final int? durationMinutes =
    appointment['durationMinutes'] is int ? appointment['durationMinutes'] as int : null;

    final imageResult = resolveDoctorImagePathAndWidget(
      doctor: {
        "doctor_image": appointment['doctor_image'],
        "gender": appointment['doctorGender'],
        "title": appointment['doctorTitle'],
      },
      width: 44,
      height: 44,
    );
    final imageProvider = imageResult.imageProvider;
    final attachments = appointmentAttachments();

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushAndRemoveUntil(
          context,
          fadePageRoute(const CustomBottomNavigationBar()),
              (route) => false,
        );
        return false; // منع الرجوع
      },
      child: Scaffold(
        backgroundColor: AppColors.background3,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: AppColors.main,
          title: Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: SvgPicture.asset(
              'assets/images/docsera_white.svg',
              height: 16.h,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.close, color: Colors.white, size: 24.sp),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                fadePageRoute(const CustomBottomNavigationBar()),
                    (route) => false,
              );
            },
          ),
        ),
        body: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // رسالة التأكيد
              Icon(Icons.check_circle, color: AppColors.main, size: 26.sp),
              SizedBox(height: 8.h),
              Text(AppLocalizations.of(context)!.appointmentConfirmed,
                  style: AppTextStyles.getTitle1(context)),
              Text(
                AppLocalizations.of(context)!.appointmentConfirmedMessage,
                style: AppTextStyles.getText2(context).copyWith(
                  fontSize: 12.sp,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h),

              // بطاقة تفاصيل الموعد
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  side: BorderSide(color: Colors.grey.shade200, width: 0.4),
                ),
                color: AppColors.background2,
                child: Column(
                  children: [
                    // شريط التاريخ والوقت
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
                      decoration: BoxDecoration(
                        color: AppColors.mainDark,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.white, size: 14.sp),
                              SizedBox(width: 6.w),
                              Text(
                                formattedDate,
                                style: AppTextStyles.getText3(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.access_time, color: Colors.white, size: 14.sp),
                              SizedBox(width: 6.w),
                              Text(
                                durationMinutes == null
                                    ? formattedTime
                                    : '$formattedTime • ${durationMinutes}m',
                                style: AppTextStyles.getText3(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // معلومات الطبيب
                    Padding(
                      padding: EdgeInsets.all(12.w),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            fadePageRoute(DoctorProfilePage(
                              doctorId: appointment['doctorId'],
                            )),
                          );
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22.r,
                              backgroundColor: AppColors.main.withOpacity(0.3),
                              backgroundImage: imageProvider,
                            ),
                            SizedBox(width: 12.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${appointment['doctorTitle'] ?? ''} ${appointment['doctorName'] ?? ''}".trim(),
                                  style: AppTextStyles.getTitle1(context).copyWith(fontSize: 13.sp),
                                ),
                                Text(
                                  appointment['specialty'] ?? "التخصص غير محدد",
                                  style: AppTextStyles.getText2(context).copyWith(color: Colors.black54),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 12.sp),
                          ],
                        ),
                      ),
                    ),
                    Divider(color: Colors.grey[200], height: 1.h),

                    // اسم المريض + الخيارات
                    _buildCardOption(
                      context,
                      Icons.person,
                      appointment['patientName'] ?? AppLocalizations.of(context)!.unknown,
                    ),
                    Divider(color: Colors.grey[200], height: 1.h),

                    _buildCardOption(
                      context,
                      Icons.calendar_today,
                      AppLocalizations.of(context)!.addToCalendar,
                      onTap: () => _addToCalendar(context),
                      isBold: true,
                    ),
                    Divider(color: Colors.grey[200], height: 1.h),

                    _buildCardOption(
                      context,
                      Icons.refresh,
                      AppLocalizations.of(context)!.bookAgain,
                      onTap: () {
                          Navigator.push(
                          context,
                          fadePageRoute(
                            SelectPatientPage(
                              doctorId: appointment["doctorId"] ?? appointment["doctor_id"] ?? "",
                              doctorName: appointment["doctorName"] ?? appointment["doctor_name"] ?? "",
                              doctorTitle: appointment["doctorTitle"] ?? appointment["doctor_title"] ?? "",
                              doctorGender: appointment["doctorGender"] ?? appointment["doctor_gender"] ?? "",
                              specialty: appointment["specialty"] ?? appointment["doctor_specialty"] ?? AppLocalizations.of(context)!.unknownSpecialty,
                              image: appointment["doctor_image"] ?? appointment["doctorImage"] ?? "assets/images/male-doc.png",
                              clinicName: appointment['clinic'] ?? appointment['clinicName'] ?? AppLocalizations.of(context)!.clinicNotAvailable,
                              clinicAddress: appointment['clinicAddress'] ?? appointment['clinic_address'] ?? const {},
                              clinicLocation: appointment['clinicLocation'] ?? appointment['location'] ?? const {},
                            ),

                          ),
                        );
                      },
                      isBold: true,
                      hasArrow: true,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 5.h),

              // إرسال المستندات
              _buildInfoCard(
                context,
                AppLocalizations.of(context)!.sendDocuments,
                subtitle: AppLocalizations.of(context)!.sendDocumentsSubtitle,
                icon: Icons.file_open_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    fadePageRoute(
                      SendDocumentToDoctorPage(
                        doctorName:
                        "${appointment['doctorTitle'] ?? ''} ${appointment['doctorName'] ?? ''}".trim(),
                        appointmentId: _appointmentId,   // 👈 إضافة الـ ID
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 5.h),

              if (attachments.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    Text(
                      AppLocalizations.of(context)!.sendDocuments,
                      style: AppTextStyles.getTitle1(context).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    ...attachments.map((att) => _attachmentTile(att)).toList(),
                  ],
                ),

              // عرض تفاصيل الموعد
              _buildInfoCard(
                context,
                AppLocalizations.of(context)!.viewMoreDetails.toUpperCase(),
                onTap: () {
                  Navigator.push(
                    context,
                    fadePageRoute(
                      AppointmentDetailsPage(
                        appointment: appointment,
                        isUpcoming: true,
                      ),
                    ),
                  );
                  print("🧭 [AppointmentConfirmedPage] Navigating to AppointmentDetailsPage");
                  print("   appointmentId = ${appointment['appointmentId'] ?? appointment['id']}");
                },
                isCentered: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= UI bits =================

  Widget _buildCardOption(
      BuildContext context,
      IconData icon,
      String text, {
        VoidCallback? onTap,
        bool isBold = false,
        bool hasArrow = false,
      }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
        child: Row(
          children: [
            Icon(icon, color: AppColors.main, size: 16.sp),
            SizedBox(width: 10.w),
            Text(
              text,
              style: AppTextStyles.getText2(context).copyWith(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: isBold ? AppColors.main : AppColors.blackText,
                fontSize: isBold ? 11.sp : 12.sp,
              ),
            ),
            if (hasArrow) const Spacer(),
            if (hasArrow) Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 12.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      BuildContext context,
      String title, {
        String? subtitle,
        VoidCallback? onTap,
        bool isCentered = false,
        IconData? icon,
      }) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
          side: BorderSide(color: Colors.grey.shade200, width: 0.4),
        ),
        color: AppColors.background2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.r),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: isCentered ? 8.h : 14.h,
              horizontal: 16.w,
            ),
            child: Row(
              mainAxisAlignment: isCentered ? MainAxisAlignment.center : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppColors.main, size: 16.sp),
                  SizedBox(width: 10.w),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        textAlign: isCentered ? TextAlign.center : TextAlign.start,
                        style: AppTextStyles.getText2(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.main,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 4.h),
                          child: Text(
                            subtitle,
                            style: AppTextStyles.getText3(context),
                            textAlign: isCentered ? TextAlign.center : TextAlign.start,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
