import 'dart:ui';

import 'package:docsera/Business_Logic/Messages_page/conversation_cubit.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/models/patient_profile.dart';
import 'package:docsera/screens/home/account/add_relative.dart';
import 'package:docsera/screens/home/messages/conversation/conversation_page.dart';
import 'package:docsera/screens/home/messages/message_select_reason_page.dart';
import 'package:docsera/services/supabase/supabase_conversation_service.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SelectPatientForMessagePage extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String doctorGender;
  final String doctorTitle;
  final String specialty;
  final ImageProvider doctorImage;
  final String doctorImageUrl;
  final UserDocument? attachedDocument;

  const SelectPatientForMessagePage({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.doctorGender,
    required this.doctorTitle,
    required this.specialty,
    required this.doctorImage,
    required this.doctorImageUrl,
    this.attachedDocument,
  });

  @override
  State<SelectPatientForMessagePage> createState() => _SelectPatientForMessagePageState();
}

class _SelectPatientForMessagePageState extends State<SelectPatientForMessagePage> {
  String? userId;
  String userName = "Loading...";
  String userGender = "ذكر";
  int userAge = 0;
  String? selectedPatientId;

  String selectedPatientName = "";
  String selectedPatientGender = "";
  int selectedPatientAge = 0;

  List<Map<String, dynamic>> relatives = [];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final client = Supabase.instance.client;

    try {
      final ctx = await client.rpc('rpc_get_my_patient_context');

      if (ctx == null) {
        debugPrint("❌ rpc_get_my_patient_context returned null");
        return;
      }

      final user = ctx['user'];
      final rels = ctx['relatives'] as List<dynamic>;

      final firstName = user['first_name'] ?? '';
      final lastName  = user['last_name'] ?? '';
      final gender    = user['gender'] ?? '';
      final dob       = user['date_of_birth'];

      final age = _calculateAge(dob);

      setState(() {
        userId = user['id'];
        userName = "$firstName $lastName".trim();
        userGender = gender;
        userAge = age;

        // افتراضيًا: المستخدم نفسه
        selectedPatientId = userId;
        selectedPatientName = userName;
        selectedPatientGender = gender;
        selectedPatientAge = age;

        relatives = rels.map<Map<String, dynamic>>((r) {
          return {
            "id": r["id"],
            "first_name": r["first_name"] ?? "",
            "last_name": r["last_name"] ?? "",
            "gender": r["gender"] ?? "",
            "age": _calculateAge(r["date_of_birth"]),
          };
        }).toList();
      });
    } catch (e) {
      debugPrint("❌ Failed to load patient context: $e");
    }
  }

  int _calculateAge(String? dobString) {
    if (dobString == null || dobString.isEmpty) return 0;

    try {
      DateTime dob = DateTime.parse(dobString);
      DateTime today = DateTime.now();
      int age = today.year - dob.year;
      if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
        age--;
      }
      return age;
    } catch (e) {
      debugPrint("⚠️ Failed to parse DOB: $dobString - $e");
      return 0;
    }
  }

  String normalizeArabicInitial(String input) {
    if (input.isEmpty) return "";
    String firstChar = input[0];
    return firstChar == 'ه' ? 'هـ' : firstChar;
  }

  Widget _buildPatientTile(
      String id,
      String firstName,
      String lastName,
      String gender,
      int age,
      bool isMainUser,
      bool isFirst,
      bool isLast,
      ) {
    final safeFirst = firstName.trim();
    final safeLast  = lastName.trim();

    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(safeFirst);

    String avatarText;

    if (isArabic) {
      avatarText = safeFirst.isNotEmpty
          ? normalizeArabicInitial(safeFirst).toUpperCase()
          : "?";
    } else {
      final f = safeFirst.isNotEmpty ? safeFirst[0].toUpperCase() : "";
      final l = safeLast.isNotEmpty ? safeLast[0].toUpperCase() : "";
      avatarText = (f + l).isNotEmpty ? f + l : "?";
    }

    final displayName = [safeFirst, safeLast].where((e) => e.isNotEmpty).join(" ");

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              selectedPatientId = id;
              selectedPatientName = displayName;
              selectedPatientGender = gender;
              selectedPatientAge = age;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
            decoration: BoxDecoration(
              color: selectedPatientId == id
                  ? AppColors.main.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.only(
                topLeft: isFirst ? Radius.circular(12.r) : Radius.zero,
                topRight: isFirst ? Radius.circular(12.r) : Radius.zero,
                bottomLeft: isLast ? Radius.circular(12.r) : Radius.zero,
                bottomRight: isLast ? Radius.circular(12.r) : Radius.zero,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: selectedPatientId == id
                      ? AppColors.main
                      : Colors.grey.shade400,
                  radius: 20.sp,
                  child: Text(
                    avatarText,
                    style: AppTextStyles.getTitle1(context)
                        .copyWith(color: Colors.white),
                  ),
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          displayName.isNotEmpty
                              ? displayName
                              : AppLocalizations.of(context)!.unknown,
                          style: AppTextStyles.getTitle1(context).copyWith(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.blackText,
                          ),
                        ),
                        if (isMainUser) ...[
                          SizedBox(width: 5.w),
                          Text(
                            AppLocalizations.of(context)!.me,
                            style: AppTextStyles.getText2(context).copyWith(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      (gender.toLowerCase().contains('male') || gender == 'ذكر')
                          ? "${AppLocalizations.of(context)!.male} , $age ${AppLocalizations.of(context)!.yearsOld}"
                          : "${AppLocalizations.of(context)!.female} , $age ${AppLocalizations.of(context)!.yearsOld}",
                      style: AppTextStyles.getText2(context).copyWith(
                        color: Colors.black87,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(
                  selectedPatientId == id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selectedPatientId == id
                      ? AppColors.main
                      : Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(color: Colors.grey.shade300, thickness: 1, height: 1),
      ],
    );
  }

  Widget _buildPatientList() {
    List<Widget> patientTiles = [];

    if (userId != null) {
      patientTiles.add(_buildPatientTile(userId!, userName.split(" ")[0], userName.split(" ")[1], userGender, userAge, true, true, relatives.isEmpty));
    }

    for (int i = 0; i < relatives.length; i++) {
      final isFirst = userId == null && i == 0;
      final isLast  = i == relatives.length - 1;

      patientTiles.add(
        _buildPatientTile(
          relatives[i]["id"] ?? "",
          relatives[i]["first_name"] ?? "",
          relatives[i]["last_name"] ?? "",
          relatives[i]["gender"] ?? "",
          relatives[i]["age"] ?? 0,
          false,
          isFirst,
          isLast,
        ),
      );
    }


    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(children: patientTiles),
    );
  }

  void _showAddRelativeSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddRelativePage(),
    );
    _loadUserInfo();
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
              child: Image(
                image: widget.doctorImage,
                width: 40.w,
                height: 40.h,
                fit: BoxFit.cover,
              ),
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
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.selectMessagePatient,
                style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp)),
            SizedBox(height: 15.h),
            _buildPatientList(),
            SizedBox(height: 20.h),
            GestureDetector(
              onTap: _showAddRelativeSheet,
              child: Row(
                children: [
                  SvgPicture.asset("assets/icons/add-user.svg", height: 14.sp, colorFilter: const ColorFilter.mode(AppColors.main, BlendMode.srcIn)),
                  SizedBox(width: 6.w),
                  Text(AppLocalizations.of(context)!.addRelative,
                      style: AppTextStyles.getText2(context).copyWith(color: AppColors.main)),
                ],
              ),
            ),
            SizedBox(height: 30.h),
            GestureDetector(
              onTap: selectedPatientId != null
                  ? () async {

                // ✅ أولاً: نتحقق هل المريض أو القريب محظور من الطبيب
                final blockCheck = await Supabase.instance.client
                    .from('doctor_patient_blocks')
                    .select('id')
                    .eq('doctor_id', widget.doctorId)
                    .eq('patient_id', userId!)
                    .or('relative_id.eq.$selectedPatientId,patient_id.eq.$selectedPatientId')
                    .limit(1)
                    .maybeSingle();

                if (blockCheck != null) {
                  // ❌ المريض محظور
                  showDialog(
                    context: context,
                    barrierColor: Colors.black.withOpacity(0.3),
                    builder: (_) {
                      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                      return Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                            child: Container(
                              width: 320.w,
                              padding: EdgeInsets.all(22.w),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.15),
                                ),
                                color: Colors.white.withOpacity(0.85),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 🔹 أيقونة القفل
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.main.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.lock_rounded,
                                        color: AppColors.main, size: 34),
                                  ),
                                  SizedBox(height: 14.h),

                                  // 🔹 العنوان
                                  Text(
                                    AppLocalizations.of(context)!.cannotSendMessageTitle,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.getTitle1(context).copyWith(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.blackText,
                                      decoration: TextDecoration.none, // ✅ يزيل أي خط سفلي افتراضي
                                    ),
                                  ),
                                  SizedBox(height: 10.h),

                                  // 🔹 المحتوى
                                  Text(
                                    "${AppLocalizations.of(context)!.thisPatientCannotMessageDoctor} ${widget.doctorName}",
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.getText2(context).copyWith(
                                      fontSize: 13.sp,
                                      color: Colors.black87,
                                      height: 1.4,
                                      decoration: TextDecoration.none, // ✅ يزيل أي خط سفلي افتراضي
                                    ),
                                  ),
                                  SizedBox(height: 22.h),

                                  // 🔹 زر الإغلاق
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.main,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        padding: EdgeInsets.symmetric(vertical: 12.h),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        AppLocalizations.of(context)!.ok,
                                        style: AppTextStyles.getTitle2(context)
                                            .copyWith(color: Colors.white, fontSize: 13.sp),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                  return; // 🚫 لا نكمل
                }

                // ✅ غير محظور → نتابع كالمعتاد
                final response = await Supabase.instance.client
                    .from('conversations')
                    .select()
                    .eq('doctor_id', widget.doctorId)
                    .eq('patient_id', selectedPatientId!)
                    .eq('is_closed', false)
                    .limit(1)
                    .maybeSingle();

                if (response != null) {
                  final docData = response;
                  final conversationId = docData['id'];

                  Navigator.push(
                    context,
                    fadePageRoute(
                      BlocProvider(
                        create: (_) => ConversationCubit(ConversationService()),
                        child: ConversationPage(
                          conversationId: conversationId,
                          doctorName: widget.doctorName,
                          patientName: docData['patient_name'] ?? selectedPatientName,
                          accountHolderName: userName,
                          doctorAvatar: widget.doctorImage,      // ImageProvider جاهز
                        )

                      ),
                    ),
                  );

                } else {
                  final patientProfile = PatientProfile(
                    patientId: selectedPatientId!,
                    doctorId: widget.doctorId,
                    patientName: selectedPatientName,
                    patientGender: selectedPatientGender,
                    patientAge: selectedPatientAge,
                    patientDOB: "",
                    patientPhoneNumber: "",
                    patientEmail: "",
                    reason: "",
                  );

                  Navigator.push(
                    context,
                    fadePageRoute(
                      SelectMessageReasonPage(
                        doctorId: widget.doctorId,
                        doctorName: widget.doctorName,
                        doctorImage: widget.doctorImage,
                        doctorImageUrl: widget.doctorImageUrl,
                        doctorSpecialty: widget.specialty,
                        patientProfile: patientProfile,
                        attachedDocument: widget.attachedDocument,
                      ),
                    ),
                  );
                }
              }
                  : null,


              child: Container(
                width: double.infinity,
                height: 50.h,
                decoration: BoxDecoration(
                  color: selectedPatientId != null ? AppColors.mainDark : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(15.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  AppLocalizations.of(context)!.continueButton,
                  style: AppTextStyles.getText2(context).copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),


          ],
        ),
      ),
    );
  }
}
