import 'package:docsera/Business_Logic/Account_page/profile/account_profile_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/profile/account_profile_state.dart';
import 'package:docsera/screens/home/account/edit_profile.dart';
import 'package:docsera/screens/home/account/my_relatives.dart';
import 'package:docsera/utils/full_page_loader.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart';


class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {

  @override
  void initState() {
    super.initState();
    context.read<AccountProfileCubit>().loadProfile();
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

  int _calculateAge(String birthDateStr) {
    try {
      final dob = DateTime.parse(birthDateStr);
      final today = DateTime.now();

      int years = today.year - dob.year;
      if (today.month < dob.month ||
          (today.month == dob.month && today.day < dob.day)) {
        years--;
      }
      return years;
    } catch (_) {
      return 0;
    }
  }


  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';


    return BlocBuilder<AccountProfileCubit, AccountProfileState>(
        builder: (context, state) {
          if (state is AccountProfileLoading) {
            return BaseScaffold(
              color: Color.lerp(AppColors.background2, AppColors.mainDark, 0.06) ?? AppColors.background2, // ✅ Fallback color
              title: Text(
                AppLocalizations.of(context)!.myProfile,
                style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white, fontSize: 12.sp),

              ),
              child:  const Center(child: FullPageLoader()),
            );
          }
          if (state is AccountProfileError) {
            return BaseScaffold(
              color: Color.lerp(AppColors.background2, AppColors.mainDark, 0.06) ?? AppColors.background2, // ✅ Fallback color
              title: Text(
                AppLocalizations.of(context)!.myProfile,
                style: AppTextStyles.getTitle1(context).copyWith(color: Colors.white, fontSize: 12.sp),

              ),
              child: Center(
                child: Text(state.message),
              ),
            );
          }

          if (state is! AccountProfileLoaded) {
            return const SizedBox.shrink();
          }

          final profile = state;
          final fullName = profile.fullName;
          final dob = profile.dateOfBirth; // String? (ISO)
          final addressMap = profile.address;

          final age = dob == null ? 0 : _calculateAge(dob);

          final formattedDate =
          dob == null ? '' : formatDateLocalized(context, dob);

          final formattedAge = formatAgeLocalized(context, age);

          String formattedAddress = AppLocalizations.of(context)!.addressNotProvided;
          if (addressMap != null) {
            formattedAddress = [
              addressMap['street'],
              addressMap['buildingNr'],
              addressMap['city'],
              addressMap['country'],
            ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
          }


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
                              fullName.isNotEmpty ? _getInitials(fullName).toUpperCase() : 'NA',
                              style: AppTextStyles.getText2(context).copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                              ),                        ),
                          ),
                          SizedBox(height: 12.h),
                          Text(fullName.isEmpty ? AppLocalizations.of(context)!.noName : fullName,
                              style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold)),

                          SizedBox(height: 6.h),
                          Text(
                              dob != null
                                  ? "${AppLocalizations.of(context)!.bornOn(formattedDate)} ($formattedAge)"
                                  : AppLocalizations.of(context)!.birthDateNotProvided,
                              style: AppTextStyles.getText3(context),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                              formattedAddress.isNotEmpty
                                  ? formattedAddress
                                  : AppLocalizations.of(context)!.addressNotProvided,
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
                            context.read<AccountProfileCubit>().loadProfile();
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
    );
  }
}
