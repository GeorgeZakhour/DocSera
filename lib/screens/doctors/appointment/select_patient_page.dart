import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/models/appointment_details.dart';
import 'package:docsera/models/patient_profile.dart';
import 'package:docsera/screens/doctors/appointment/visited_doctor_page.dart';
import 'package:docsera/screens/home/account/add_relative.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';


class SelectPatientPage extends StatefulWidget {
  final String doctorId;
  final String doctorName; // ✅ Receive doctor name
  final String doctorGender; // ✅ Receive doctor name
  final String doctorTitle;
  final String specialty;
  final String image;
  final String clinicName; // ✅ استلام العيادة
  final Map<String, dynamic> clinicAddress;// ✅ استلام العنوان



  const SelectPatientPage({Key? key, required this.doctorId, required this.doctorName,required this.doctorGender,required this.doctorTitle,required this.specialty, required this.image, required this.clinicName,required this.clinicAddress}) : super(key: key);

  @override
  _SelectPatientPageState createState() => _SelectPatientPageState();
}

class _SelectPatientPageState extends State<SelectPatientPage> {
  String userName = "Loading...";
  String userGender = "Male"; // Default, will be fetched
  int userAge = 0; // Default, will be fetched
  bool isSelected = true; // Default selection for main user
  String patientDOB = ""; // ✅ Store Date of Birth
  String patientPhoneNumber = ""; // ✅ Store Phone Number
  String patientEmail = ""; // ✅ Store Email

  String? userId; // ✅ Declare userId at class level
  List<Map<String, dynamic>> relatives = []; // ✅ Declare relatives list
  String? selectedPatientId;

  String selectedPatientName = "";
  String selectedPatientGender = "";
  int selectedPatientAge = 0;



  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId'); // ✅ Assign class-level userId

    if (userId == null) {
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;

        if (userData != null) {
          String firstName = userData['firstName'] ?? "";
          String lastName = userData['lastName'] ?? "";
          String gender = userData['gender'] ?? "Unknown";
          String? dobString = userData['dateOfBirth'];
          String phoneNumber = userData['phoneNumber'] ?? "Not provided"; // ✅ Retrieve phone number
          String email = userData['email'] ?? "Not provided"; // ✅ Retrieve email

          int age = _calculateAge(dobString);


          setState(() {
            userName = "$firstName $lastName";
            userGender = gender;
            userAge = age;
            patientDOB = dobString ?? ""; // ✅ Store formatted DOB
            patientPhoneNumber = phoneNumber; // ✅ Store phone number
            patientEmail = email; // ✅ Store email
          });

          _loadRelatives();

        }
      }
    } catch (e) {
      // Handle Firestore errors silently
    }
  }

  int _calculateAge(String? dobString) {
    if (dobString == null || dobString.isEmpty) return 0; // ✅ Ensure a default value

    try {
      List<String> parts = dobString.split('.');
      if (parts.length == 3) {
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        DateTime dob = DateTime(year, month, day);
        DateTime today = DateTime.now();
        int age = today.year - dob.year;

        if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
          age--;
        }
        return age;
      }
    } catch (e) {
      print("❌ Error parsing dateOfBirth: $e");
    }
    return 0; // ✅ Ensure a fallback integer value
  }


  Future<void> _loadRelatives() async {
    if (userId == null) return;

    try {
      QuerySnapshot relativesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('relatives')
          .get();

      setState(() {
        relatives = relativesSnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return {
            "id": doc.id,
            "firstName": data["firstName"] ?? "Unknown",
            "lastName": data["lastName"] ?? "",
            "gender": data["gender"] ?? "Unknown",
            "age": _calculateAge(data["dateOfBirth"]) ?? 0, // ✅ Ensure age is always an int
          };
        }).toList();
      });
    } catch (e) {
      print("❌ Error fetching relatives: $e");
    }
  }

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
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: const AddRelativePage(),
              ),
            ),
          ),
        );
      },
    );

    if (mounted) {
      _loadRelatives(); // ✅ يتم تحميل البيانات فقط عند عودة المستخدم للصفحة
    }
  }






  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      titleAlignment: 2,
        height: 75.h,
        title:  Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.background2.withOpacity(0.3),
              radius: 18.r,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Image.asset(
                  widget.image,
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
                Text(AppLocalizations.of(context)!.makeAppointment,
                style: AppTextStyles.getText2(context).copyWith(fontSize: 12.sp,fontWeight: FontWeight.w300,color: AppColors.whiteText),),
                Text(widget.doctorName,style: AppTextStyles.getTitle2(context).copyWith(fontSize: 14.sp,color: AppColors.whiteText)),
              ],
            ),
          ],
        ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 "Who is this appointment for?"
            Text(
              AppLocalizations.of(context)!.whoIsThisFor,
              style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp),
            ),
            SizedBox(height: 15.h),

            _buildPatientList(), // ✅ Display patient selection card with dividers

            SizedBox(height: 20.h),

            // 🔹 Add a relative (Dummy Button for Now)
            GestureDetector(
              onTap: _showAddRelativeSheet,
              child: Row(
                children:  [
                  SvgPicture.asset(
                    "assets/icons/add-user.svg", // ✅ استخدام أيقونة SVG
                    height: 14.sp, // ✅ تعيين الحجم بحيث يتناسب مع التصميم
                    colorFilter: ColorFilter.mode(AppColors.main, BlendMode.srcIn), // ✅ جعل اللون متناسقًا مع الثيم
                  ),
                  SizedBox(width: 6.w),
                  Text(AppLocalizations.of(context)!.addRelative, style: AppTextStyles.getText2(context).copyWith(color: AppColors.main)),
                ],
              ),
            ),
            SizedBox(height: 30.h),

            // 🔹 Continue Button
            GestureDetector(
              onTap: selectedPatientId != null
                  ? () {
                print("Selected Patient: $selectedPatientName, Gender: $selectedPatientGender, Age: $selectedPatientAge");

                Navigator.push(
                  context,
                  fadePageRoute(
                    VisitedDoctorPage(
                      patientProfile: PatientProfile(
                        patientId: selectedPatientId!, // ✅ مضاف
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
                        image: widget.image,
                        patientName: selectedPatientName,
                        patientGender: selectedPatientGender,
                        patientAge: selectedPatientAge,
                        newPatient: false,
                        reason: "",
                        clinicName: widget.clinicName,
                        clinicAddress: widget.clinicAddress,
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
                    color: Colors.white ,
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
    List<Widget> patientTiles = [];

    // إضافة المستخدم الرئيسي
    if (userId != null) {
      patientTiles.add(_buildPatientTile(userId!, userName.split(" ")[0], userName.split(" ")[1], userGender, userAge, true, true, relatives.isEmpty));
    }

    // إضافة الأقارب مع ضبط الأول والأخير
    for (int i = 0; i < relatives.length; i++) {
      bool isFirst = userId == null && i == 0; // أول عنصر فقط إن لم يكن هناك مستخدم رئيسي
      bool isLast = i == relatives.length - 1; // آخر عنصر

      patientTiles.add(
        _buildPatientTile(
          relatives[i]["id"],
          relatives[i]["firstName"],
          relatives[i]["lastName"],
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
      child: Column(
        children: patientTiles,
      ),
    );
  }

  void _updateSelectedPatient(String id, String firstName, String lastName, String gender, int age) {
    setState(() {
      selectedPatientId = id;
      selectedPatientName = "$firstName $lastName";
      selectedPatientGender = gender;
      selectedPatientAge = age;
    });
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
                      "${gender.toLowerCase() == 'male' ? AppLocalizations.of(context)!.male : AppLocalizations.of(context)!.female} , "
                          "$age ${AppLocalizations.of(context)!.yearsOld}",
                      style: AppTextStyles.getText2(context).copyWith(
                        color: Colors.black87,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Icon(
                  selectedPatientId == id ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selectedPatientId == id ? AppColors.main : Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (!isLast) Divider(color: Colors.grey.shade300, thickness: 1, height: 1), // ✅ إزالة الفراغ بين العنصر والتظليل
      ],
    );
  }

}

