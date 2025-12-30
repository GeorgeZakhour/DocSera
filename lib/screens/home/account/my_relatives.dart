import 'package:docsera/Business_Logic/Account_page/relatives/relatives_cubit.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/account/add_relative.dart';
import 'package:docsera/screens/home/account/edit_relative.dart';
import 'package:docsera/screens/home/account/manage_access_right.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../utils/full_page_loader.dart';

class MyRelativesPage extends StatefulWidget {
  const MyRelativesPage({super.key});

  @override
  State<MyRelativesPage> createState() => _MyRelativesPageState();
}

class _MyRelativesPageState extends State<MyRelativesPage> {

  @override
  void initState() {
    super.initState();
    context.read<RelativesCubit>().loadRelatives();
  }

  // ---------------------------------------------------------------------------
  // Utils
  // ---------------------------------------------------------------------------

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

  String normalizeArabicInitial(String input) {
    if (input.isEmpty) return "";
    return input[0] == 'ه' ? 'هـ' : input[0];
  }

  String convertToArabicNumbers(String input) {
    const english = ['0','1','2','3','4','5','6','7','8','9'];
    const arabic  = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  String formatLocalizedDate(String dob, BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final parts = dob.split(RegExp(r'[./-]'));
    if (parts.length != 3) return dob;

    if (isArabic) {
      return "${convertToArabicNumbers(parts[0])} / "
          "${convertToArabicNumbers(parts[1])} / "
          "${convertToArabicNumbers(parts[2])}";
    }
    return "${parts[0]}/${parts[1]}/${parts[2]}";
  }

  String _formatPhoneForDisplay(String phone) {
    if (phone.startsWith('00963') && phone.length == 14) {
      return '0${phone.substring(5)}';
    }
    return phone;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset('assets/icons/relatives2.svg', height: 140.h),
        SizedBox(height: 20.h),
        Text(
          AppLocalizations.of(context)!.noRelativesTitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.getTitle2(context),
        ),
        SizedBox(height: 10.h),
        Text(
          AppLocalizations.of(context)!.noRelativesDesc,
          textAlign: TextAlign.center,
          style: AppTextStyles.getText2(context)
              .copyWith(color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildRelativeCard(Map<String, dynamic> relative) {
    final firstName = relative['first_name'] ?? "";
    final lastName  = relative['last_name'] ?? "";

    final isArabicName = RegExp(r'[\u0600-\u06FF]').hasMatch(firstName);
    final initials = isArabicName
        ? normalizeArabicInitial(firstName)
        : "${firstName.isNotEmpty ? firstName[0] : ""}"
        "${lastName.isNotEmpty ? lastName[0] : ""}";

    final isArabicLocale =
        Localizations.localeOf(context).languageCode == 'ar';

    final age = _calculateAge(relative['date_of_birth'] ?? "");
    final formattedDate =
    formatLocalizedDate(relative['date_of_birth'] ?? "", context);

    final formattedAge = AppLocalizations.of(context)!.yearsCount(
      isArabicLocale
          ? convertToArabicNumbers(age.toString())
          : age.toString(),
    );

    final email = relative['email'] ?? '';
    final phone = relative['phone_number'] ?? '';

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
                CircleAvatar(
                  radius: 20.r,
                  backgroundColor: AppColors.main.withOpacity(0.5),
                  child: Text(
                    initials.toUpperCase(),
                    style: AppTextStyles.getText2(context)
                        .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$firstName $lastName".toUpperCase(),
                        style: AppTextStyles.getText2(context)
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        "${AppLocalizations.of(context)!.bornOn(formattedDate)} "
                            "($formattedAge)",
                        style: AppTextStyles.getText3(context),
                        textDirection: TextDirection.ltr,
                      ),
                      SizedBox(height: 4.h),
                      if (email.isNotEmpty)
                        Text(email,
                            style: AppTextStyles.getText3(context)
                                .copyWith(color: Colors.black54)),
                      if (phone.isNotEmpty)
                        Text(
                          isArabicLocale
                              ? convertToArabicNumbers(
                              _formatPhoneForDisplay(phone))
                              : _formatPhoneForDisplay(phone),
                          style: AppTextStyles.getText3(context)
                              .copyWith(color: Colors.black54),
                        ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      fadePageRoute(
                        EditRelativePage(
                          relativeId: relative['id'],
                          relativeData: relative,
                        ),
                      ),
                    );
                    if (result == true) {
                      context.read<RelativesCubit>().loadRelatives();
                    }
                  },
                  child: Row(
                    children: [
                      Icon(Icons.edit,
                          size: 14.sp, color: AppColors.mainDark),
                      SizedBox(width: 4.w),
                      Text(
                        AppLocalizations.of(context)!.edit,
                        style: AppTextStyles.getText3(context).copyWith(
                          color: AppColors.mainDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1.h),
          InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                fadePageRoute(
                  ManageAccessRightsPage(
                    relativeId: relative['id'],
                    relativeName: "$firstName $lastName",
                  ),
                ),
              );
              if (result == true) {
                context.read<RelativesCubit>().loadRelatives();
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.manageAccessRights,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: AppColors.main,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.sp,
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 16.sp, color: AppColors.main),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background2,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.myRelatives,
          style: AppTextStyles.getTitle1(context)
              .copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.main,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 16.sp, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<RelativesCubit, RelativesState>(
        builder: (context, state) {
          if (state is RelativesLoading) {
            return const Center(child: FullPageLoader());
          }

          if (state is RelativesLoaded) {
            if (state.relatives.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: _buildEmptyState(),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.only(top: 16.h),
              itemCount: state.relatives.length,
              itemBuilder: (_, i) =>
                  _buildRelativeCard(state.relatives[i]),
            );
          }

          if (state is RelativesError) {
            return Center(child: Text(state.message));
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.main,
        elevation: 0,
        icon: Icon(Icons.person_add, size: 16.sp, color: Colors.white),
        label: Text(
          AppLocalizations.of(context)!.addRelative,
          style: AppTextStyles.getText2(context)
              .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.r)),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            fadePageRoute(const AddRelativePage()),
          );
          if (result == true) {
            context.read<RelativesCubit>().loadRelatives();
          }
        },
      ),
    );
  }
}
