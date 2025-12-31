import 'dart:ui';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import '../visit_report_model.dart';

class ReportCardWidget extends StatelessWidget {
  final VisitReport report;
  final VoidCallback onTap;

  const ReportCardWidget({
    super.key,
    required this.report,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final imageResult = resolveDoctorImagePathAndWidget(
      doctor: {
        "doctor_image": report.doctorImagePath,
        "gender": report.doctorGender ?? "unknown",
        "title": report.doctorTitle ?? "",
      },
      width: 30,
      height: 30,
    );

    final formattedDate =
        "${report.date.day.toString().padLeft(2, '0')}/${report.date.month.toString().padLeft(2, '0')}/${report.date.year}";

    final reportAddedText =
        "${t.health_report_added} $formattedDate";

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.main.withOpacity(0.22)),
            ),
            child: Stack(
              children: [
                // TEXT AREA
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isRtl ? 16 : 68,
                    18,
                    isRtl ? 68 : 16,
                    14,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Doctor info + "report added"
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.doctorName,
                              style: AppTextStyles.getText1(context).copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.mainDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (report.doctorSpecialty != null &&
                                report.doctorSpecialty!.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  report.doctorSpecialty!,
                                  style: AppTextStyles.getText3(context).copyWith(
                                    fontSize: 11,
                                    color: AppColors.mainDark.withOpacity(0.6),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 10),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildCheckBadge(),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    reportAddedText,
                                    style: AppTextStyles.getText3(context)
                                        .copyWith(
                                      fontSize: 11,
                                      color: AppColors.mainDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Small arrow
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.mainDark.withOpacity(0.35),
                      ),
                    ],
                  ),
                ),

                // AVATAR + REPORT ICON
                Positioned(
                  top: 10,
                  right: isRtl ? 14 : null,
                  left: isRtl ? null : 14,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Doctor avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.main.withOpacity(0.1),
                        backgroundImage: imageResult.imageProvider,
                      ),

                      // Report icon below the avatar
                      Positioned(
                        bottom: -12,
                        left: isRtl ? -6 : null,
                        right: isRtl ? null : -6,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              "assets/icons/visit_report.svg",
                              width: 25,
                              height: 25,
                            ),
                          ),
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

  /// ⭐ NEW BADGE — Zigzag star background with white check mark
  Widget _buildCheckBadge() {
    return SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SvgPicture.string(
            '''
<svg width="18" height="18" viewBox="0 0 24 24">
  <path fill="${_hex(AppColors.main)}"
        d="M12 0
           L14.6 2.2
           L18 1.2
           L19.2 4.6
           L22.8 5.4
           L22 9
           L24 12
           L22 15
           L22.8 18.6
           L19.2 19.4
           L18 22.8
           L14.6 21.8
           L12 24
           L9.4 21.8
           L6 22.8
           L4.8 19.4
           L1.2 18.6
           L2 15
           L0 12
           L2 9
           L1.2 5.4
           L4.8 4.6
           L6 1.2
           L9.4 2.2
           Z"/>
</svg>
          ''',
            width: 16,
            height: 16,
          ),

          const Icon(
            Icons.check,
            size: 10,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  String _hex(Color c) =>
      "#${c.value.toRadixString(16).substring(2).toUpperCase()}";
}
