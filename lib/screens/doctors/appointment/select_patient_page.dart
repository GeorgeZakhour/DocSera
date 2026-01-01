import 'package:docsera/app/const.dart';
import 'package:docsera/models/appointment_details.dart';
import 'package:docsera/models/patient_profile.dart';
import 'package:docsera/screens/doctors/appointment/visited_doctor_page.dart';
import 'package:docsera/screens/home/account/add_relative.dart';
import 'package:docsera/utils/doctor_image_utils.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SelectPatientPage extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String doctorGender;
  final String doctorTitle;
  final String specialty;
  final String image;
  final String clinicName;
  final Map<String, dynamic> clinicAddress;
  final Map<String, dynamic> clinicLocation;

  const SelectPatientPage({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.doctorGender,
    required this.doctorTitle,
    required this.specialty,
    required this.image,
    required this.clinicName,
    required this.clinicAddress,
    required this.clinicLocation,
  });

  @override
  _SelectPatientPageState createState() => _SelectPatientPageState();
}

class _SelectPatientPageState extends State<SelectPatientPage> {
  String userName = "Loading...";
  String userGender = "ذكر";
  int userAge = 0;
  String patientDOB = "";
  String patientPhoneNumber = "";
  String patientEmail = "";

  String? userId;
  List<Map<String, dynamic>> relatives = [];
  String? selectedPatientId;

  String selectedPatientName = "";
  String selectedPatientGender = "";
  int selectedPatientAge = 0;
  String? latestDoctorImage;

  @override
  void initState() {
    super.initState();
    debugPrint("📍 [SelectPatientPage] Received clinicLocation = ${widget.clinicLocation}");

    _loadUserInfo();
    _fetchLatestDoctorImage();
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
      final dob = DateTime.parse(dobString);
      final today = DateTime.now();
      var age = today.year - dob.year;
      if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
        age--;
      }
      return age;
    } catch (e) {
      debugPrint("❌ Error parsing dateOfBirth: $e");
      return 0;
    }
  }

  // Future<void> _loadRelatives() async {
  //   final client = Supabase.instance.client;
  //
  //   try {
  //     final res = await client.rpc('rpc_get_my_relatives');
  //
  //     if (res == null || res is! List) {
  //       debugPrint("⚠️ rpc_get_my_relatives returned empty or invalid data");
  //       setState(() {
  //         relatives = [];
  //       });
  //       return;
  //     }
  //
  //     setState(() {
  //       relatives = res.map<Map<String, dynamic>>((r) {
  //         return {
  //           "id": r["id"],
  //           "first_name": r["first_name"] ?? "",
  //           "last_name": r["last_name"] ?? "",
  //           "gender": r["gender"] ?? "",
  //           "age": _calculateAge(r["date_of_birth"]),
  //         };
  //       }).toList();
  //     });
  //   } catch (e) {
  //     debugPrint("❌ Error loading relatives via rpc_get_my_relatives: $e");
  //   }
  // }

  void _showAddRelativeSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: const ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            child: AddRelativePage(),
          ),
        );
      },
    );

    if (mounted) {
      await _loadUserInfo();
    }

  }

  Future<void> _fetchLatestDoctorImage() async {
    try {
      final response = await Supabase.instance.client
          .from('doctors')
          .select('doctor_image')
          .eq('id', widget.doctorId)
          .maybeSingle();

      if (response != null && response['doctor_image'] != null) {
        setState(() {
          latestDoctorImage = response['doctor_image'];
        });
        debugPrint("📸 Latest doctor image from Supabase: $latestDoctorImage");
      } else {
        debugPrint("⚠️ No doctor image found in Supabase.");
      }
    } catch (e) {
      debugPrint("❌ Error fetching doctor image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageResult = resolveDoctorImagePathAndWidget(
      doctor: {
        "doctor_image": latestDoctorImage ?? widget.image,
        "gender": widget.doctorGender,
        "title": widget.doctorTitle,
      },
      width: 40,
      height: 40,
    );
    final imageProvider = imageResult.imageProvider;

    return BaseScaffold(
      titleAlignment: 2,
      height: 75.h,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.background2.withOpacity(0.3),
            radius: 18.r,
            backgroundImage: imageProvider,
          ),
          SizedBox(width: 15.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.makeAppointment,
                style: AppTextStyles.getText2(context).copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w300,
                  color: AppColors.whiteText,
                ),
              ),
              Text(
                widget.doctorName,
                style: AppTextStyles.getTitle2(context).copyWith(
                  fontSize: 14.sp,
                  color: AppColors.whiteText,
                ),
              ),
            ],
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.whoIsThisFor,
              style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
            ),
            SizedBox(height: 15.h),

            _buildPatientList(),

            SizedBox(height: 20.h),

            GestureDetector(
              onTap: _showAddRelativeSheet,
              child: Row(
                children: [
                  SvgPicture.asset(
                    "assets/icons/add-user.svg",
                    height: 14.sp,
                    colorFilter: const ColorFilter.mode(AppColors.main, BlendMode.srcIn),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    AppLocalizations.of(context)!.addRelative,
                    style: AppTextStyles.getText2(context).copyWith(color: AppColors.main),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30.h),

            GestureDetector(
              onTap: selectedPatientId != null
                  ? () {
                debugPrint(
                    "Selected Patient: $selectedPatientName, Gender: $selectedPatientGender, Age: $selectedPatientAge");

                Navigator.push(
                  context,
                  fadePageRoute(
                    VisitedDoctorPage(
                      patientProfile: PatientProfile(
                        patientId: selectedPatientId!,
                        doctorId: widget.doctorId,
                        patientName: selectedPatientName,
                        patientGender: selectedPatientGender,
                        patientAge: selectedPatientAge,
                        patientDOB: patientDOB,
                        patientPhoneNumber: patientPhoneNumber,
                        patientEmail: patientEmail,
                        reason: "",
                      ),
                      appointmentDetails: AppointmentDetails(
                        doctorId: widget.doctorId,
                        doctorName: widget.doctorName,
                        doctorGender: widget.doctorGender,
                        doctorTitle: widget.doctorTitle,
                        specialty: widget.specialty,
                        image: latestDoctorImage ?? widget.image,
                        patientId: selectedPatientId!,
                        isRelative: selectedPatientId != userId,
                        patientName: selectedPatientName,
                        patientGender: selectedPatientGender,
                        patientAge: selectedPatientAge,
                        newPatient: false,
                        reason: "",
                        clinicName: widget.clinicName,
                        clinicAddress: widget.clinicAddress,
                        location: widget.clinicLocation,
                      ),
                    ),
                  ),
                );
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

  Widget _buildPatientList() {
    final tiles = <Widget>[];

    if (userId != null) {
      final parts = userName.trim().split(" ");
      final firstName = parts.isNotEmpty ? parts.first : "";
      final lastName  = parts.length > 1 ? parts[1] : "";

      tiles.add(
        _buildPatientTile(
          userId!,
          firstName,
          lastName,
          userGender,
          userAge,
          true,
          true,
          relatives.isEmpty,
        ),
      );
    }


    for (int i = 0; i < relatives.length; i++) {
      final isFirst = userId == null && i == 0;
      final isLast = i == relatives.length - 1;

      tiles.add(
        _buildPatientTile(
          relatives[i]["id"],
          relatives[i]["first_name"],
          relatives[i]["last_name"],
          relatives[i]["gender"],
          relatives[i]["age"] is int ? relatives[i]["age"] : 0,
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
      child: Column(children: tiles),
    );
  }

  void _updateSelectedPatient(
      String id, String firstName, String lastName, String gender, int age) {
    selectedPatientId = id;
    selectedPatientName = "$firstName $lastName".trim();
    selectedPatientGender = gender;
    selectedPatientAge = age;
  }

  String normalizeArabicInitial(String input) {
    if (input.isEmpty) return "";
    final firstChar = input[0];
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
    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(firstName);
    String avatarText;

    if (isArabic) {
      avatarText = firstName.isNotEmpty
          ? normalizeArabicInitial(firstName).toUpperCase()
          : "?";
    } else {
      final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : "";
      final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : "";
      avatarText = (f + l).isNotEmpty ? f + l : "?";
    }
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _updateSelectedPatient(id, firstName, lastName, gender, age);
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
}
