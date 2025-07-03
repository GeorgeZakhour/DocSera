import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/models/patient_profile.dart';
import 'package:docsera/screens/home/account/add_relative.dart';
import 'package:docsera/screens/home/messages/conversation_page.dart';
import 'package:docsera/screens/home/messages/message_select_reason_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SelectPatientForMessagePage extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String doctorGender;
  final String doctorTitle;
  final String specialty;
  final String image;
  final UserDocument? attachedDocument;

  const SelectPatientForMessagePage({
    Key? key,
    required this.doctorId,
    required this.doctorName,
    required this.doctorGender,
    required this.doctorTitle,
    required this.specialty,
    required this.image,
    this.attachedDocument,
  }) : super(key: key);

  @override
  State<SelectPatientForMessagePage> createState() => _SelectPatientForMessagePageState();
}

class _SelectPatientForMessagePageState extends State<SelectPatientForMessagePage> {
  String? userId;
  String userName = "Loading...";
  String userGender = "Male";
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId');

    if (userId == null) return;

    final String currentUserId = userId!;

    final response = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', currentUserId)
        .maybeSingle();

    final userData = response;


    if (userData != null) {
      String firstName = userData['first_name'] ?? "";
      String lastName = userData['last_name'] ?? "";
      String gender = userData['gender'] ?? "Unknown";
      String? dobString = userData['date_of_birth'];

      int age = _calculateAge(dobString);

      setState(() {
        userName = "$firstName $lastName";
        userGender = gender;
        userAge = age;
      });

      _loadRelatives();
    }
  }

  Future<void> _loadRelatives() async {
    if (userId == null) return;

    final String currentUserId = userId!;

    final response = await Supabase.instance.client
        .from('relatives')
        .select()
        .eq('user_id', currentUserId);

    setState(() {
      relatives = response.map<Map<String, dynamic>>((data) {
        return {
          "id": data["id"] ?? "",
          "firstName": data["first_name"] ?? "",
          "lastName": data["last_name"] ?? "",
          "gender": data["gender"] ?? "",
          "age": _calculateAge(data["date_of_birth"]) ?? 0,
        };
      }).toList();
    });
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
      print("⚠️ Failed to parse DOB: $dobString - $e");
      return 0;
    }
  }

  String normalizeArabicInitial(String input) {
    if (input.isEmpty) return "";
    String firstChar = input[0];
    return firstChar == 'ه' ? 'هـ' : firstChar;
  }

  Widget _buildPatientTile(String id, String firstName, String lastName, String gender, int age, bool isMainUser, bool isFirst, bool isLast) {
    bool isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(firstName);
    String avatarText = isArabic
        ? normalizeArabicInitial(firstName).toUpperCase()
        : "${firstName[0].toUpperCase()}${lastName[0].toUpperCase()}";

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              selectedPatientId = id;
              selectedPatientName = "$firstName $lastName";
              selectedPatientGender = gender;
              selectedPatientAge = age;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
            decoration: BoxDecoration(
              color: selectedPatientId == id ? AppColors.main.withOpacity(0.1) : Colors.transparent,
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
                  backgroundColor: selectedPatientId == id ? AppColors.main : Colors.grey.shade400,
                  radius: 20.sp,
                  child: Text(
                    avatarText,
                    style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white),
                  ),
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "$firstName $lastName",
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
                  selectedPatientId == id ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selectedPatientId == id ? AppColors.main : Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (!isLast) Divider(color: Colors.grey.shade300, thickness: 1, height: 1),
      ],
    );
  }

  Widget _buildPatientList() {
    List<Widget> patientTiles = [];

    if (userId != null) {
      patientTiles.add(_buildPatientTile(userId!, userName.split(" ")[0], userName.split(" ")[1], userGender, userAge, true, true, relatives.isEmpty));
    }

    for (int i = 0; i < relatives.length; i++) {
      bool isFirst = userId == null && i == 0;
      bool isLast = i == relatives.length - 1;

      patientTiles.add(
        _buildPatientTile(
          relatives[i]["id"] ?? "",
          relatives[i]["firstName"] ?? "",
          relatives[i]["lastName"] ?? "",
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
              child: Image.asset(widget.image, width: 40.w, height: 40.h, fit: BoxFit.cover),
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
                      ConversationPage(
                        conversationId: conversationId,
                        doctorName: widget.doctorName,
                        doctorSpecialty: widget.specialty,
                        doctorImage: widget.image,
                        isClosed: docData['is_closed'] ?? false,
                        patientName: docData['patient_name'] ?? selectedPatientName,
                        accountHolderName: userName,
                        selectedReason: docData['selected_reason'] ?? '',
                        attachedDocument: widget.attachedDocument,
                      ),
                    ),
                  );
                }
                else {
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
                        doctorName: widget.doctorName,
                        doctorImage: widget.image,
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
