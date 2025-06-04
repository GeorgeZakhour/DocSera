import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/screens/home/account/edit_profile.dart';
import 'package:docsera/screens/home/account/my_relatives.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart';


class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String userId = "";
  String userName = "Loading...";
  String birthDate = "Not provided";
  String address = "Address not entered";
  int age = 0;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  /// ✅ Load userId from SharedPreferences
  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId') ?? "";
    if (userId.isNotEmpty) {
      _fetchUserData();
    }
  }

  /// ✅ Fetch user data from Firestore
  void _fetchUserData() {
    FirebaseFirestore.instance.collection('users').doc(userId).snapshots().listen((docSnapshot) {
      if (docSnapshot.exists) {
        Map<String, dynamic> userData = docSnapshot.data()!;

        String firstName = userData['firstName'] ?? '';
        String lastName = userData['lastName'] ?? '';
        String fullName = "$firstName $lastName".trim();

        String birthDateStr = userData['dateOfBirth'] ?? "Not provided";
        int userAge = _calculateAge(birthDateStr);

        // ✅ Handle the address properly if it's stored as a Map
        String formattedAddress = "Address not entered";
        if (userData['address'] is Map<String, dynamic>) {
          Map<String, dynamic> addressMap = userData['address'];
          String street = addressMap['street'] ?? '';
          String buildingNr = addressMap['buildingNr'] ?? '';
          String city = addressMap['city'] ?? '';
          String country = addressMap['country'] ?? '';

          formattedAddress = [street, buildingNr, city, country]
              .where((part) => part.isNotEmpty)
              .join(", ");
        } else if (userData['address'] is String) {
          formattedAddress = userData['address'];
        }

        if (!mounted) return; // ✅ Prevent setState after dispose

        setState(() {
          userName = fullName.isNotEmpty ? fullName : "No name provided";
          birthDate = birthDateStr;
          age = userAge;
          address = formattedAddress;
        });
      }
    });
  }


  /// ✅ Calculate age from birth date with enhanced parsing
  int _calculateAge(String birthDateStr) {
    if (birthDateStr == "Not provided") return 0;

    try {
      List<String> parts;

      // Handle both "dd/MM/yyyy" and "dd.MM.yyyy" formats
      if (birthDateStr.contains('/')) {
        parts = birthDateStr.split('/');
      } else if (birthDateStr.contains('.')) {
        parts = birthDateStr.split('.');
      } else {
        print("❌ Unsupported date format: $birthDateStr");
        return 0;
      }

      if (parts.length != 3) return 0;

      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]);
      DateTime dob = DateTime(year, month, day);

      DateTime today = DateTime.now();
      int years = today.year - dob.year;
      int months = today.month - dob.month;
      int days = today.day - dob.day;

      // 🔹 Adjust if the birthday hasn't occurred yet this year
      if (months < 0 || (months == 0 && days < 0)) {
        years--;
      }

      return years;
    } catch (e) {
      print("❌ Error parsing birth date: $e");
      return 0;
    }
  }



  /// ✅ Edit field dialog
  void _showEditDialog(String field, String title, String currentValue) {
    TextEditingController controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: 'New $title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _updateUserData(field, controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: AppColors.main)),
          ),
        ],
      ),
    );
  }

  /// ✅ Update Firestore with new data
  Future<void> _updateUserData(String field, String newValue) async {
    if (userId.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        field: newValue,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$field updated successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update $field: $e'), backgroundColor: AppColors.red),
      );
    }
  }


  String convertToArabicNumbers(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  String formatDateLocalized(BuildContext context, String dob) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final parts = dob.split(RegExp(r'[./-]'));
    if (parts.length != 3) return dob;
    final d = parts[0];
    final m = parts[1];
    final y = parts[2];
    return isArabic
        ? "${convertToArabicNumbers(d)} / ${convertToArabicNumbers(m)} / ${convertToArabicNumbers(y)}"
        : "$d/$m/$y";
  }

  String formatAgeLocalized(BuildContext context, int age) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return AppLocalizations.of(context)!.yearsCount(isArabic ? convertToArabicNumbers(age.toString()) : age.toString());
  }



  String _getInitials(String name) {
    final names = name.trim().split(' ');
    final first = names.isNotEmpty ? names[0] : "";
    final last = names.length > 1 ? names[1] : "";
    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(name);

    if (first.isEmpty) return "NA";
    if (isArabic) {
      return (first.startsWith("ه") ? "هـ" : first.characters.first).toUpperCase();
    }

    final firstInitial = first.characters.isNotEmpty ? first.characters.first.toUpperCase() : "";
    final lastInitial = last.characters.isNotEmpty ? last.characters.first.toUpperCase() : "";
    return (firstInitial + lastInitial).isEmpty ? "NA" : firstInitial + lastInitial;
  }


  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final formattedDate = birthDate.isNotEmpty ? formatDateLocalized(context, birthDate) : "";
    final formattedAge = formatAgeLocalized(context, age);

    return BaseScaffold(
      color: Color.lerp(AppColors.background2, AppColors.mainDark, 0.06) ?? AppColors.background2, // ✅ Fallback color
      title: Text(
        AppLocalizations.of(context)!.myProfile,
        style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white, fontSize: 12.sp),

      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ✅ Top White Container
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22.r,
                        backgroundColor: AppColors.main.withOpacity(0.5),
                        child: Text(
                          userName.isNotEmpty ? _getInitials(userName).toUpperCase() : 'NA',
                          style: AppTextStyles.getText2(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(userName.isEmpty ? AppLocalizations.of(context)!.noName : userName,
                          style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold)),

                      SizedBox(height: 6.h),
                      Text(
                        birthDate.isNotEmpty
                            ? "${AppLocalizations.of(context)!.bornOn(formattedDate)} ($formattedAge)"
                            : AppLocalizations.of(context)!.birthDateNotProvided,
                        style: AppTextStyles.getText3(context),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        address.isNotEmpty ? address : AppLocalizations.of(context)!.addressNotProvided,
                        style: AppTextStyles.getText3(context).copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                // ✅ Edit Button
                InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent, // Makes it full-screen with rounded corners
                      builder: (context) => const EditProfilePage(),
                    );

                  },
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: AppColors.mainDark, size: 16.sp),
                      SizedBox(width: 4.w),
                      Text(AppLocalizations.of(context)!.edit,
                          style: AppTextStyles.getText3(context).copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.mainDark,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // ✅ "Did you know?" Section
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: Colors.grey.shade200, // ✅ Thin grey border
                width: 0.5,                   // ✅ Border width
              ),
            ),
            child: Column(
              children: [
                SvgPicture.asset(
                    'assets/icons/relatives1.svg',
                    width: 120.w, // same as size in Icon
                    height: 120.h,
                ),
                SizedBox(height: 20.h),
                Text(AppLocalizations.of(context)!.didYouKnow,
                    style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold)),
                SizedBox(height: 15.h),
                Text(AppLocalizations.of(context)!.didYouKnowDesc,
                    style: AppTextStyles.getText3(context), textAlign: TextAlign.center),
                SizedBox(height: 20.h),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, fadePageRoute(const MyRelativesPage()));
                  },
                  child: Text(AppLocalizations.of(context)!.manageMyRelatives,
                      style: AppTextStyles.getText2(context).copyWith(
                          color: AppColors.main, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
