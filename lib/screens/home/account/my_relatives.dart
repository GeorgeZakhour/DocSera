import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/home/account/add_relative.dart';
import 'package:docsera/screens/home/account/edit_relative.dart';
import 'package:docsera/screens/home/account/manage_access_right.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class MyRelativesPage extends StatefulWidget {
  const MyRelativesPage({super.key});

  @override
  _MyRelativesPageState createState() => _MyRelativesPageState();
}

class _MyRelativesPageState extends State<MyRelativesPage> {
  String userId = "";
  String accountHolderEmail = "";
  String accountHolderPhone = "";
  List<Map<String, dynamic>> relatives = [];

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  /// ✅ Load userId and user info from SharedPreferences
  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId') ?? "";
    if (userId.isNotEmpty) {
      _fetchUserInfo();
      _fetchRelatives();
    }
  }

  /// ✅ Fetch user’s email & phone for fallback data
  void _fetchUserInfo() async {
    final data = await Supabase.instance.client
        .from('users')
        .select('email, phone_number')
        .eq('id', userId)
        .maybeSingle();

    if (data != null && mounted) {
      setState(() {
        accountHolderEmail = data['email'] ?? "No email provided";
        accountHolderPhone = data['phone_number'] ?? "No phone provided";
      });
    }
  }



  /// ✅ Fetch relatives from Supabase
  void _fetchRelatives() {
    Supabase.instance.client
        .from('relatives')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((List<Map<String, dynamic>> data) {
      if (mounted) {
        setState(() {
          relatives = data;
        });
      }
    });
  }


  /// ✅ Calculate age from birth date
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


  /// ✅ Empty state UI
  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset('assets/icons/relatives2.svg', height: 140.h),
        SizedBox(height: 20.h),
        Text(AppLocalizations.of(context)!.noRelativesTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.getTitle2(context).copyWith(color: Colors.black87)),
        SizedBox(height: 10.h),
        SizedBox(height: 10.h),
        Text(AppLocalizations.of(context)!.noRelativesDesc,
            textAlign: TextAlign.center,
            style: AppTextStyles.getText2(context).copyWith(color: Colors.black54)),
      ],
    );
  }

  String normalizeArabicInitial(String input) {
    if (input.isEmpty) return "";
    String firstChar = input[0];
    return firstChar == 'ه' ? 'هـ' : firstChar;
  }

  String convertToArabicNumbers(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  String formatLocalizedDate(String dob, BuildContext context) {
    Locale locale = Localizations.localeOf(context);
    bool isArabic = locale.languageCode == 'ar';

    List<String> parts = dob.split(RegExp(r'[./-]')); // يفصل dd.MM.yyyy أو غيرها

    if (parts.length != 3) return dob;

    String day = parts[0];
    String month = parts[1];
    String year = parts[2];

    if (isArabic) {
      // ✅ نعرضها بشكل يدوي من اليمين لليسار بالأرقام العربية
      return "${convertToArabicNumbers(day)} / ${convertToArabicNumbers(month)} / ${convertToArabicNumbers(year)}";
    } else {
      return "$day/$month/$year";
    }
  }

  String _formatPhoneForDisplay(String phone) {
    if (phone.startsWith('00963') && phone.length == 14) {
      return '0${phone.substring(5)}';
    }
    return phone;
  }


  /// ✅ Relative Card UI
  Widget _buildRelativeCard(Map<String, dynamic> relative) {
    String firstName = relative['first_name'] ?? "";
    String lastName = relative['last_name'] ?? "";
    bool isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(firstName);

    String initials = isArabic
        ? normalizeArabicInitial(firstName).toUpperCase()
        : "${firstName.isNotEmpty ? firstName[0].toUpperCase() : ""}${lastName.isNotEmpty ? lastName[0].toUpperCase() : ""}";

    bool isArabicLocale = Localizations.localeOf(context).languageCode == 'ar';

    int age = _calculateAge(relative['date_of_birth'] ?? "Unknown");
    String formattedDate = formatLocalizedDate(relative['date_of_birth'] ?? "", context);
    String formattedAge = AppLocalizations.of(context)!.yearsCount(
        isArabicLocale ? convertToArabicNumbers(age.toString()) : age.toString()
    );

    // ✅ Check if email or phone is missing, fallback to account holder’s info
    String email = relative['email'] ?? accountHolderEmail;
    String phone = relative['phone_number'] ?? accountHolderPhone;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Profile initials
                CircleAvatar(
                  radius: 20.r,
                  backgroundColor: AppColors.main.withOpacity(0.5),
                  child: Text(initials, style: AppTextStyles.getText2(context).copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                SizedBox(width: 12.w),

                // ✅ Relative details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${relative['first_name']} ${relative['last_name']}".toUpperCase(),
                          style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold)),
                      SizedBox(height: 6.h),
                      Text(
                        "${AppLocalizations.of(context)!.bornOn(formattedDate)} ($formattedAge)",
                        style: AppTextStyles.getText3(context),
                        textDirection: TextDirection.ltr, // ✅ إجباري لعرض اليوم أولاً
                      ),
                      SizedBox(height: 4.h),
                      Text(email, style: AppTextStyles.getText3(context).copyWith(color: Colors.black54)),
                      Text(
                        isArabicLocale
                            ? convertToArabicNumbers(_formatPhoneForDisplay(phone))
                            : _formatPhoneForDisplay(phone),
                        style: AppTextStyles.getText3(context).copyWith(color: Colors.black54),
                      ),

                    ],
                  ),
                ),

                // ✅ Edit button
                InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      fadePageRoute(EditRelativePage(
                        relativeId: relative['id'], // Pass the relative ID
                        relativeData: relative, // Pass all existing relative data
                      )),
                    );

                    if (result == true) {
                      _fetchRelatives(); // ✅ حمّل الأقارب من جديد
                    }
                  },
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: AppColors.mainDark, size: 14.sp),
                      SizedBox(width: 4.w),
                      Text(AppLocalizations.of(context)!.edit,
                          style: AppTextStyles.getText3(context).copyWith(
                              color: AppColors.mainDark, fontWeight: FontWeight.bold)),],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1.h, color: Colors.grey[300]),
          InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                fadePageRoute(ManageAccessRightsPage(
                  relativeId: relative['id'], // Retrieve the correct relative ID
                  relativeName: "${relative['first_name']} ${relative['last_name']}", // Retrieve the correct relative name
                )),
              );
              if (result == true) {
                _fetchRelatives(); // استدعِ فقط إذا صار تعديل
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context)!.manageAccessRights,
                      style: AppTextStyles.getText2(context).copyWith(
                          color: AppColors.main, fontWeight: FontWeight.bold, fontSize: 11.sp)),
                  Icon(Icons.chevron_right, color: AppColors.main, size: 16.sp),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: relatives.isEmpty ? AppColors.background2 : Color.lerp(AppColors.background2, AppColors.mainDark, 0.05) ?? AppColors.background2, // ✅ Fallback color
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.myRelatives, style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white)),
        backgroundColor: AppColors.main,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16.sp),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: relatives.isEmpty
          ? Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: _buildEmptyState(),
      )
          : ListView.builder(
        padding: EdgeInsets.only(top: 16.h),
        itemCount: relatives.length,
        itemBuilder: (context, index) => _buildRelativeCard(relatives[index]),
      ),

      // ✅ Add Relative Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, fadePageRoute(const AddRelativePage()));

          if (result == true) {
            _fetchRelatives(); // استدعِ فقط إذا صار تعديل
          }
        },
        backgroundColor: AppColors.main,
        elevation: 0,
        icon: Icon(Icons.person_add, color: Colors.white, size: 16.sp),
        label: Text(AppLocalizations.of(context)!.addRelative,  style: AppTextStyles.getText2(context).copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.r)),
      ),
    );
  }
}
