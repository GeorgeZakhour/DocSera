import 'package:docsera/screens/home/account/edit_profile.dart';
import 'package:docsera/screens/home/account/my_relatives.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


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

  /// ✅ Fetch user data from Supabase
  void _fetchUserData() async {
    final data = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null || !mounted) return;

    String firstName = data['first_name'] ?? '';
    String lastName = data['last_name'] ?? '';
    String fullName = "$firstName $lastName".trim();

    String birthDateStr = data['date_of_birth'] ?? "Not provided";
    int userAge = _calculateAge(birthDateStr);

    // ✅ Handle address properly if it's stored as a Map (json column)
    String formattedAddress = AppLocalizations.of(context)!.addressNotProvided;
    if (data['address'] is Map<String, dynamic>) {
      Map<String, dynamic> addressMap = data['address'];
      String street = addressMap['street'] ?? '';
      String buildingNr = addressMap['buildingNr'] ?? '';
      String city = addressMap['city'] ?? '';
      String country = addressMap['country'] ?? '';

      formattedAddress = [street, buildingNr, city, country]
          .where((part) => part.isNotEmpty)
          .join(", ");
    } else if (data['address'] is String) {
      formattedAddress = data['address'];
    }

    setState(() {
      userName = fullName.isNotEmpty ? fullName : "No name provided";
      birthDate = birthDateStr;
      age = userAge;
      address = address = formattedAddress.isNotEmpty
          ? formattedAddress
          : AppLocalizations.of(context)!.addressNotProvided;
      ;
    });
  }


  /// ✅ Calculate age from birth date with enhanced parsing
  int _calculateAge(String birthDateStr) {
    try {
      // ✅ parse as ISO-8601 format
      DateTime dob = DateTime.parse(birthDateStr);
      DateTime today = DateTime.now();

      int years = today.year - dob.year;
      if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
        years--;
      }

      return years;
    } catch (e) {
      print("❌ Error parsing birth date: $e");
      return 0;
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
                    onTap: () async {
                      final result = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const EditProfilePage(),
                      );

                      if (result == true) {
                        _fetchUserData();
                      }
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
