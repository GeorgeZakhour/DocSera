import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/doctors/appointment/select_patient_page.dart';
import 'package:docsera/screens/home/appointment/appointment_details_page.dart';
import 'package:docsera/screens/home/appointment/send_document.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class AppointmentConfirmedPage extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const AppointmentConfirmedPage({Key? key, required this.appointment})
      : super(key: key);

  void _addToCalendar(BuildContext context) {
    DateTime startTime = DateTime.parse(appointment['timestamp']);
    DateTime endTime = startTime.add(const Duration(minutes: 30));

    final Event event = Event(
      title: "${AppLocalizations.of(context)!.appointmentWith} ${appointment['doctorTitle'] ?? ''} ${appointment['doctorName'] ?? ''}",
      description: "${AppLocalizations.of(context)!.reasonForAppointment}: ${appointment['reason'] ?? AppLocalizations.of(context)!.notSpecified}",
      location: "${appointment['clinicAddress']['street'] ?? ''}, ${appointment['clinicAddress']['city'] ?? ''}",
      startDate: startTime,
      endDate: endTime,
      allDay: false,
    );

    Add2Calendar.addEvent2Cal(event).then((success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? AppLocalizations.of(context)!.appointmentAddedToCalendar
              : AppLocalizations.of(context)!.appointmentFailedToAdd),
        ),
      );
    });
  }


  @override
  Widget build(BuildContext context) {
    DateTime appointmentDate = DateTime.parse(appointment['timestamp']);
    // ✅ تحديد لغة التنسيق تلقائيًا
    String locale = Localizations.localeOf(context).languageCode;

// ✅ تنسيق التاريخ والوقت بناءً على اللغة
    String formattedDate = DateFormat("EEEE, d MMMM yyyy", locale).format(appointmentDate);
    String formattedTime = DateFormat("HH:mm", locale).format(appointmentDate);

    final imagePath = (appointment['doctor_image'] != null && appointment['doctor_image'].toString().isNotEmpty)
        ? appointment['doctor_image']
        : (appointment['doctorTitle'].toString().toLowerCase() == "dr."
        ? (appointment['doctorGender'].toString().toLowerCase() == "female"
        ? 'assets/images/female-doc.png'
        : 'assets/images/male-doc.png')
        : (appointment['doctorGender'].toString().toLowerCase() == "male"
        ? 'assets/images/male-phys.png'
        : 'assets/images/female-phys.png'));

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushAndRemoveUntil(
          context,
          fadePageRoute(const CustomBottomNavigationBar()),
              (route) => false,
        );
        return false; // يمنع الرجوع العادي
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
                fadePageRoute(CustomBottomNavigationBar()),
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
              // ✅ Confirmation Message
              Icon(Icons.check_circle, color: AppColors.main, size: 26.sp),
              SizedBox(height: 8.h),
              Text(AppLocalizations.of(context)!.appointmentConfirmed,
                  style: AppTextStyles.getTitle1(context)),
              Text(
                AppLocalizations.of(context)!.appointmentConfirmedMessage,
                style: AppTextStyles.getText2(context).copyWith(
                    fontSize: 12.sp, color: Colors.black87),
              ),
              SizedBox(height: 20.h),

              // ✅ Appointment Details Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  side: BorderSide(color: Colors.grey.shade200, width: 0.4),
                ),
                color: AppColors.background2,
                child: Column(
                  children: [
                    // 🔹 Date & Time Bar
                    Container(
                      padding: EdgeInsets.symmetric(
                          vertical: 10.h, horizontal: 16.w),
                      decoration: BoxDecoration(
                        color: AppColors.mainDark,
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12.r)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.white,
                                  size: 14.sp),
                              SizedBox(width: 6.w),
                              Text(formattedDate,
                                  style: AppTextStyles.getText3(context).copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.access_time, color: Colors.white,
                                  size: 14.sp),
                              SizedBox(width: 6.w),
                              Text(formattedTime,
                                  style: AppTextStyles.getText3(context).copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 🔹 Doctor Information
                    Padding(
                      padding: EdgeInsets.all(12.w),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            fadePageRoute(DoctorProfilePage(
                                doctorId: appointment['doctorId'])),
                          );
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22.r,
                              backgroundColor: AppColors.main.withOpacity(0.3),
                              backgroundImage: AssetImage(imagePath),
                            ),
                          SizedBox(width: 12.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${appointment['doctorTitle'] ??
                                      ''} ${appointment['doctorName'] ?? ''}"
                                      .trim(),
                                  style: AppTextStyles.getTitle1(context)
                                      .copyWith(fontSize: 13.sp),
                                ),
                                Text(
                                  appointment['specialty'] ?? "التخصص غير محدد",
                                  style: AppTextStyles.getText2(context).copyWith(
                                      color: Colors.black54),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_forward_ios, color: Colors.grey,
                                size: 12.sp),
                          ],
                        ),
                      ),
                    ),
                    Divider(color: Colors.grey[200], height: 1.h,),

                    // 🔹 Patient Name + Options
                    _buildCardOption(context, Icons.person,
                        appointment['patientName'] ?? AppLocalizations.of(context)!.unknown),
                    Divider(color: Colors.grey[200], height: 1.h,),
                    _buildCardOption(context, Icons.calendar_today,
                        AppLocalizations.of(context)!.addToCalendar,
                        onTap: () => _addToCalendar(context), isBold: true),
                    Divider(color: Colors.grey[200], height: 1.h,),
                    _buildCardOption(
                      context,
                      Icons.refresh,
                      AppLocalizations.of(context)!.bookAgain,
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          fadePageRoute(
                            SelectPatientPage(
                              doctorId: appointment["doctorId"] ?? "",
                              doctorName: appointment["doctorName"] ?? "Unknown",
                              doctorTitle: appointment["doctorTitle"] ?? "",
                              doctorGender: appointment["doctorGender"] ?? "",
                              specialty: appointment["specialty"] ?? "General Practice",
                              image: appointment["doctor_image"] ?? "assets/images/female-doc.png",
                              clinicName: appointment['clinicName'] ?? "Unknown Clinic",
                              clinicAddress: appointment['clinicAddress'] ?? {},
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

              // ✅ "إرسال المستندات" مع أيقونة الملف
              _buildInfoCard(
                context,
                AppLocalizations.of(context)!.sendDocuments,
                subtitle: AppLocalizations.of(context)!.sendDocumentsSubtitle,
                icon: Icons.file_open_outlined, // ✅ تمت إضافة الأيقونة هنا
                onTap: () {
                  Navigator.push(
                    context,
                    fadePageRoute(
                      SendDocumentToDoctorPage(
                        doctorName: "${appointment['doctorTitle'] ?? ''} ${appointment['doctorName'] ?? ''}".trim(),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 5.h),

      // ✅ "عرض تفاصيل الموعد" بدون أيقونة، محاذاة مركزية، وارتفاع أقل
              _buildInfoCard(
                context,
                AppLocalizations.of(context)!.viewMoreDetails.toUpperCase(),
                onTap: () {
                  Navigator.push(
                    context,
                    fadePageRoute(AppointmentDetailsPage(appointment: appointment, isUpcoming: true)),
                  );
                },
                isCentered: true, // 🔹 يجعل النص في المنتصف وارتفاع العنصر أقل
              ),


            ],
          ),
        ),
      ),
    );
  }

  /// 🔹 Card Row with Icon
  Widget _buildCardOption(BuildContext context, IconData icon, String text,
      {VoidCallback? onTap, bool isBold = false, bool hasArrow = false}) {
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
                fontSize: isBold ? 11.sp : 12.sp
              ),
            ),
            if (hasArrow) Spacer(),
            if (hasArrow) Icon(
                Icons.arrow_forward_ios, color: Colors.grey, size: 12.sp),
          ],
        ),
      ),
    );
  }

  /// 🔹 Creates a full-width card for additional options
  Widget _buildInfoCard(BuildContext context, String title,
      {String? subtitle, VoidCallback? onTap, bool isCentered = false, IconData? icon}) {
    return SizedBox(
      width: double.infinity, // ✅ يجعل العرض كاملًا
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
          side: BorderSide(color: Colors.grey.shade200, width: 0.4), // ✅ تحسين سمك الإطار
        ),
        color: AppColors.background2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.r),
          child: Padding(
            padding: EdgeInsets.symmetric(
                vertical: isCentered ? 8.h : 14.h, horizontal: 16.w), // ✅ تقليل الارتفاع للبطاقة الوسطى
            child: Row(
              mainAxisAlignment: isCentered ? MainAxisAlignment.center : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[ // ✅ إضافة الأيقونة إذا كانت موجودة
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

