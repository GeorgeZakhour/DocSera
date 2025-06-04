import 'package:docsera/Business_Logic/Messages_page/messages_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/models/patient_profile.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';import 'package:shared_preferences/shared_preferences.dart';

class WriteMessagePage extends StatefulWidget {
  final String doctorName;
  final String doctorImage;
  final String doctorSpecialty;
  final String selectedReason;
  final PatientProfile patientProfile;
  final UserDocument? attachedDocument;

  const WriteMessagePage({
    Key? key,
    required this.doctorName,
    required this.doctorImage,
    required this.doctorSpecialty,
    required this.selectedReason,
    required this.patientProfile,
    this.attachedDocument,

  }) : super(key: key);

  @override
  State<WriteMessagePage> createState() => _WriteMessagePageState();
}

class _WriteMessagePageState extends State<WriteMessagePage> {
  final TextEditingController _controller = TextEditingController();
  int charCount = 0;

  void _showHelpBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.5,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.helpTitle,
                        style: AppTextStyles.getTitle1(context).copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close),
                    )
                  ],
                ),
                SizedBox(height: 40.h),
                Image.asset("assets/images/message.png", height: 80.h),
                SizedBox(height: 40.h),
                Text(
                  AppLocalizations.of(context)!.helpMessage1,
                  style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  AppLocalizations.of(context)!.helpMessage2,
                  style: AppTextStyles.getText2(context).copyWith(color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      titleAlignment: 2,
      height: 75.h,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.background2.withOpacity(0.3),
            radius: 18.r,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Image.asset(widget.doctorImage, width: 40.w, height: 40.h, fit: BoxFit.cover),
            ),
          ),
          SizedBox(width: 15.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.sendMessage,
                  style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp, color: AppColors.whiteText)),
              Text(widget.doctorName,
                  style: AppTextStyles.getTitle2(context).copyWith(fontSize: 14.sp, color: AppColors.whiteText)),
            ],
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: AppColors.main.withOpacity(0.6),
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: Row(
                  children: [
                    Icon(Icons.mail_outline, size: 18.sp, color: AppColors.whiteText),
                    SizedBox(width: 8.w),
                    Text(widget.selectedReason,
                        style: AppTextStyles.getTitle1(context)
                            .copyWith(color: AppColors.whiteText, fontSize: 11.sp)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 25.h),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.whatDoYouNeed,
                        style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
                      ),
                      GestureDetector(
                        onTap: _showHelpBottomSheet,
                        child: Row(
                          children: [
                            Icon(Icons.help_outline, size: 16.sp, color: AppColors.main),
                            SizedBox(width: 4.w),
                            Text(
                              AppLocalizations.of(context)!.help,
                              style: AppTextStyles.getText2(context).copyWith(
                                color: AppColors.main,
                                fontWeight: FontWeight.bold,
                                fontSize: 10.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 10.h),
                        TextField(
                          controller: _controller,
                          maxLines: 5,
                          maxLength: 800,
                          onChanged: (value) {
                            setState(() => charCount = value.length);
                          },
                          style: AppTextStyles.getText2(context),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: AppLocalizations.of(context)!.messageHint,
                            hintStyle: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                            counterText: '',
                          ),
                        ),
                        SizedBox(height: 10.h),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text("$charCount/800",
                              style: AppTextStyles.getText3(context).copyWith(color: Colors.grey)),
                        ),
                        SizedBox(height: 20.h),
                        GestureDetector(
                          onTap: () {},
                          child: Row(
                            children: [
                              Icon(Icons.attach_file, size: 18.sp, color: AppColors.main),
                              SizedBox(width: 6.w),
                              Text(AppLocalizations.of(context)!.attachDocuments,
                                  style: AppTextStyles.getText3(context).copyWith(color: AppColors.main)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40.h),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final messageText = _controller.text.trim();
                      if (messageText.isEmpty) return;

                      final patientId = widget.patientProfile.patientId;
                      final doctorId = widget.patientProfile.doctorId;

                      // ✅ جرّب أولًا من AuthCubit
                      String accountHolderName = '';
                      final authState = context.read<AuthCubit>().state;
                      if (authState is AuthAuthenticated) {
                        final user = authState.user;
                        accountHolderName = "${user.displayName ?? ''}".trim();
                      }

                      // ✅ fallback إلى SharedPreferences لو فشل
                      if (accountHolderName.isEmpty) {
                        final prefs = await SharedPreferences.getInstance();
                        accountHolderName = prefs.getString('userName') ?? '';
                      }

                      await context.read<MessagesCubit>().startConversation(
                        patientId: patientId,
                        doctorId: doctorId,
                        message: messageText,
                        doctorName: widget.doctorName,
                        doctorSpecialty: widget.doctorSpecialty,
                        doctorImage: widget.doctorImage,
                        patientName: widget.patientProfile.patientName,
                        accountHolderName: accountHolderName,
                        selectedReason: widget.selectedReason,
                      );

                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    icon: SvgPicture.asset(
                      "assets/icons/send.svg",
                      height: 18.sp,
                      colorFilter: ColorFilter.mode(AppColors.whiteText, BlendMode.srcIn),
                    ),
                    label: Text(
                      AppLocalizations.of(context)!.sendMyMessage,
                      style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainDark,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      minimumSize: Size(double.infinity, 50.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
