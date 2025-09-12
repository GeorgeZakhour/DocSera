import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/utils/time_utils.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:docsera/utils/page_transitions.dart';

class WaitingForConfirmationPage extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const WaitingForConfirmationPage({Key? key, required this.appointment})
      : super(key: key);


  @override
  Widget build(BuildContext context) {
    final formattedDate = formatBusinessDate(context, appointment);
    final tsUtc = DateTime.parse(appointment['timestamp'].toString()).toUtc();
    final formattedTime = format12hLocalized(context, tsUtc);

    // مدة الموعد (اختيارية): مرّرها في الـ navPayload باسم durationMinutes
    final int? durationMinutes = appointment['durationMinutes'] is int
        ? appointment['durationMinutes'] as int
        : null;

    final imageResult = resolveDoctorImagePathAndWidget(
      doctor: {
        'doctor_image': appointment['doctor_image'],
        'gender': appointment['doctorGender'],
        'title': appointment['doctorTitle'],
      },
      width: 44,
      height: 44,
    );
    final imageProvider = imageResult.imageProvider;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushAndRemoveUntil(
          context,
          fadePageRoute(const CustomBottomNavigationBar()),
              (route) => false,
        );
        return false;
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
              Icon(Icons.hourglass_bottom_rounded, color: AppColors.main, size: 28.sp),
              SizedBox(height: 8.h),
              Text(AppLocalizations.of(context)!.awaitingDoctorConfirmation,
                  style: AppTextStyles.getTitle1(context)),
              Text(
                AppLocalizations.of(context)!.waitingForDoctorToApprove,
                style: AppTextStyles.getText2(context).copyWith(
                  fontSize: 12.sp,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h),

              // ✅ تفاصيل الموعد
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  side: BorderSide(color: Colors.grey.shade200, width: 0.4),
                ),
                color: AppColors.background2,
                child: Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الطبيب
                      Row(
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
                                appointment['specialty'] ?? AppLocalizations.of(context)!.notSpecified,
                                style: AppTextStyles.getText2(context).copyWith(color: Colors.black54),
                              ),
                            ],
                          ),
                        ],
                      ),

                      SizedBox(height: 12.h),

                      // التاريخ والوقت (من appointmentDate/Time أو fallback)
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: AppColors.main, size: 16.sp),
                          SizedBox(width: 8.w),
                          Text(formattedDate, style: AppTextStyles.getText2(context)),
                          SizedBox(width: 16.w),
                          Icon(Icons.access_time, color: AppColors.main, size: 16.sp),
                          SizedBox(width: 8.w),
                          Text(formattedTime, style: AppTextStyles.getText2(context)),
                          if (durationMinutes != null) ...[
                            SizedBox(width: 8.w),
                            Text('• ${durationMinutes}m',
                                style: AppTextStyles.getText2(context).copyWith(color: Colors.black54)),
                          ],
                        ],
                      ),

                      SizedBox(height: 10.h),

                      // المريض
                      Row(
                        children: [
                          Icon(Icons.person, color: AppColors.main, size: 16.sp),
                          SizedBox(width: 8.w),
                          Text(
                            appointment['patientName'] ?? AppLocalizations.of(context)!.unknown,
                            style: AppTextStyles.getText2(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 30.h),

              // زر الرجوع للرئيسية
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      fadePageRoute(const CustomBottomNavigationBar()),
                          (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mainDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.backToHome,
                    style: AppTextStyles
                        .getTitle1(context)
                        .copyWith(color: Colors.white, fontSize: 12.sp),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
