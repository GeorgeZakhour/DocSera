import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/doctors/appointment/select_patient_page.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/screens/doctors/doctor_profile_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class AppointmentCancelledPage extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const AppointmentCancelledPage({Key? key, required this.appointment}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    DateTime appointmentDate = DateTime.parse(appointment['timestamp']);
    String locale = Localizations.localeOf(context).languageCode;
    String formattedDate = DateFormat("EEEE, d MMMM yyyy", locale).format(appointmentDate);
    String formattedTime = DateFormat("HH:mm", locale).format(appointmentDate);

    String gender = (appointment['doctor_gender'] ?? '').toString().toLowerCase();
    String title = (appointment['doctor_title'] ?? '').toString().toLowerCase();
    String? doctorImage = appointment['doctor_image'];

    final imagePath = getDoctorImage(
      imageUrl: doctorImage,
      gender: gender,
      title: title,
    );

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
            child: SvgPicture.asset('assets/images/docsera_white.svg', height: 16.h),
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
              Icon(Icons.cancel, color: AppColors.red, size: 35.sp),
              SizedBox(height: 8.h),
              Text(AppLocalizations.of(context)!.appointmentCancelled,
                  style: AppTextStyles.getTitle1(context)),
              Text(
                AppLocalizations.of(context)!.appointmentCancelledMessage,
                style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp, color: Colors.black87),
              ),
              SizedBox(height: 20.h),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  side: BorderSide(color: Colors.grey.shade200, width: 0.4),
                ),
                color: AppColors.background2,
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
                      decoration: BoxDecoration(
                        color: AppColors.mainDark.withOpacity(0.9),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.white, size: 14.sp),
                              SizedBox(width: 6.w),
                              Text(formattedDate,
                                  style: AppTextStyles.getText3(context).copyWith(
                                      color: Colors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.access_time, color: Colors.white, size: 14.sp),
                              SizedBox(width: 6.w),
                              Text(formattedTime,
                                  style: AppTextStyles.getText3(context).copyWith(
                                      color: Colors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12.w),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            fadePageRoute(DoctorProfilePage(doctorId: appointment['doctor_id'])),
                          );
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22.r,
                              backgroundColor: AppColors.main.withOpacity(0.2),
                              backgroundImage: imagePath.toString().startsWith("http")
                                  ? NetworkImage(imagePath) as ImageProvider
                                  : AssetImage(imagePath),
                            ),

                            SizedBox(width: 12.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${appointment['doctor_title'] ?? ''} ${appointment['doctor_name'] ?? ''}".trim(),
                                  style: AppTextStyles.getTitle1(context).copyWith(fontSize: 13.sp),
                                ),
                                Text(
                                  appointment['doctor_specialty'] ?? "التخصص غير محدد",
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
                    _buildCardOption(context, Icons.person,
                        appointment['patient_name'] ?? AppLocalizations.of(context)!.unknown),
                    Divider(color: Colors.grey[200], height: 1.h),
                    _buildCardOption(
                      context,
                      Icons.refresh,
                      AppLocalizations.of(context)!.bookAgain,
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          fadePageRoute(
                            SelectPatientPage(
                              doctorId: appointment["doctor_id"] ?? "",
                              doctorName: appointment["doctor_name"] ?? "Unknown",
                              doctorTitle: appointment["doctor_title"] ?? "",
                              doctorGender: appointment["doctor_gender"] ?? "",
                              specialty: appointment["doctor_specialty"] ?? "General Practice",
                              image: appointment["doctor_image"] ?? "assets/images/female-doc.png",
                              clinicName: appointment['clinic'] ?? "Unknown Clinic",
                              clinicAddress: appointment['clinic_address'] ?? {},
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

              _buildInfoCard(
                context,
                AppLocalizations.of(context)!.toAppointmentPage.toUpperCase(),
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    fadePageRoute(const CustomBottomNavigationBar(initialIndex: 1)),
                        (route) => false,
                  );

                },
                isCentered: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                  fontSize: isBold ? 11.sp : 12.sp),
            ),
            if (hasArrow) Spacer(),
            if (hasArrow) Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 12.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title,
      {String? subtitle, VoidCallback? onTap, bool isCentered = false, IconData? icon}) {
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
                vertical: isCentered ? 8.h : 14.h, horizontal: 16.w),
            child: Row(
              mainAxisAlignment:
              isCentered ? MainAxisAlignment.center : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppColors.main, size: 16.sp),
                  SizedBox(width: 10.w),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: isCentered
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        textAlign: isCentered ? TextAlign.center : TextAlign.start,
                        style: AppTextStyles.getText2(context)
                            .copyWith(fontWeight: FontWeight.bold, color: AppColors.main),
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
