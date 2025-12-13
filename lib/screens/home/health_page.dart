import 'dart:ui';

import 'package:docsera/Business_Logic/Account_page/user_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/user_state.dart';
import 'package:docsera/Business_Logic/Health_page/patient_switcher_cubit.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/account/add_relative.dart';
import 'package:docsera/screens/home/documents_page.dart';
import 'package:docsera/screens/home/health/pages/allergies/allergies_page.dart';
import 'package:docsera/screens/home/health/pages/chronic/chronic_diseases_page.dart';
import 'package:docsera/screens/home/health/pages/family/family_history_page.dart';
import 'package:docsera/screens/home/health/pages/medications/medications_page.dart';
import 'package:docsera/screens/home/health/pages/surgeries/surgeries_page.dart';
import 'package:docsera/screens/home/health/pages/vaccinations/vaccinations_page.dart';
import 'package:docsera/screens/home/health/pages/visit_reports/visit_reports_page.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HealthPage extends StatelessWidget {
  const HealthPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final t = AppLocalizations.of(context)!;
    final summary = _buildHealthSummary(t);
    final personal = _buildPersonalRecords(t);


    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureMainUserSet(context);
    });
    // _loadRelatives(context);


    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,

          /// اللون العلوي يتماشى مع لون الـ Scaffold الرئيسي (AppColors.main)
          colors: [
            AppColors.main,
            AppColors.background,
          ],

          /// الأبيض يظهر بشكل مبكر جداً (60%)
          stops: const [0.0, 0.80],
        ),
      ),

      child: SafeArea(
        top: true,
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              SizedBox(height: 10.h),
              _buildPatientGlassSwitcher(context),

              SizedBox(height: 20.h),

              // ---------------------------
              // FIRST TITLE — HEALTH SUMMARY
              // ---------------------------
              _buildSectionTitle(
                context,
                t.health_summary,
                t.health_patientSubtitle,
              ),

              SizedBox(height: 14.h),
              _buildCategoriesGrid(context, summary, isArabic),

              SizedBox(height: 18.h),

              // ---------------------------
              // SECOND TITLE — PERSONAL RECORDS
              // ---------------------------
              _build2ndSectionTitle(
                context,
                t.health_personalRecords_title,
                t.health_personalRecords_subtitle,
              ),

              SizedBox(height: 10.h),
              _buildCategoriesGrid(context, personal, isArabic),
            ],
          ),
        ),
      ),
    );
  }



  void _ensureMainUserSet(BuildContext context) {
    print("🩺 [_ensureMainUserSet] called");

    final cubit = context.read<PatientSwitcherCubit>();
    final userState = context.read<UserCubit>().state;

    if (userState is UserLoaded) {
      if (cubit.state.mainUserId == null) {
        cubit.setMainUser(userState.userId, userState.userName);
      }
    }
  }




  Widget _buildPatientGlassSwitcher(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return BlocBuilder<PatientSwitcherCubit, PatientSwitcherState>(
      builder: (context, state) {
        return GestureDetector(
          onTap: () {print("MAIN USER ID = ${state.mainUserId}");
          print("RELATIVES COUNT = ${state.relatives.length}");
          print("RELATIVES = ${state.relatives}");
          _loadRelatives(context, forceReload: true);
          _openPatientPopup(context);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                      color: AppColors.main.withOpacity(0.35), width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    )
                  ],
                ),
                child: Row(
                  textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                  children: [
                    Expanded(
                      child: Text(
                        state.patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign:
                        isArabic ? TextAlign.right : TextAlign.left,
                        style: AppTextStyles.getTitle1(context).copyWith(
                          fontSize: 14.sp,
                          color: AppColors.whiteText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.4),
                        border: Border.all(
                          color: AppColors.main.withOpacity(0.45),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.mainDark,
                        size: 22.sp,
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
  }

  void _loadRelatives(BuildContext context, {bool forceReload = false}) {
    final cubit = context.read<PatientSwitcherCubit>();
    final supabase = Supabase.instance.client;

    final String? userId = cubit.state.mainUserId;

    print("👨‍👩‍👧 [_loadRelatives] called → "
        "forceReload=$forceReload, mainUserId=$userId, "
        "current relatives count=${cubit.state.relatives.length}");

    if (userId == null || userId.isEmpty) {
      print("⚠️ [_loadRelatives] mainUserId is null/empty → abort");
      return;
    }

    if (!forceReload && cubit.state.relatives.isNotEmpty) {
      print("✅ [_loadRelatives] relatives already loaded and forceReload=false → skip fetching");
      return;
    }

    Future.microtask(() async {
      try {
        print("🛰 [_loadRelatives] fetching from Supabase for user_id=$userId ...");
        final result = await supabase
            .from("relatives")
            .select()
            .eq("user_id", userId);

        print("✅ [_loadRelatives] fetched ${result.length} relatives from DB");

        cubit.updateRelatives(
          List<Map<String, dynamic>>.from(result),
        );
      } catch (e) {
        print("❌ [_loadRelatives] Error fetching relatives: $e");
      }
    });
  }





  void _openPatientPopup(BuildContext context) {
    final cubit = context.read<PatientSwitcherCubit>();

    // _loadRelatives(context, forceReload: true); // <– NEW

    final state = cubit.state;
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final mainUserName = context.read<UserCubit>().state is UserLoaded
        ? (context.read<UserCubit>().state as UserLoaded).userName
        : "";

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 320.w,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.health_switch,
                    style: AppTextStyles.getTitle1(context).copyWith(
                      fontSize: 14.sp,
                      color: AppColors.mainDark,
                    ),
                  ),

                  SizedBox(height: 12.h),

                  /// Main User
                  _patientOption(
                    context,
                    id: state.userId!,
                    name: mainUserName,
                    selected: state.relativeId == null,
                  ),



                  SizedBox(height: 6.h),

                  /// Relatives
                  ...state.relatives.map((r) {
                    final rName = "${r["first_name"]} ${r["last_name"]}";
                    return Column(
                      children: [
                        _patientOption(
                          context,
                          id: r["id"],
                          name: rName,
                          selected: state.relativeId == r["id"],
                        ),
                        SizedBox(height: 6.h),
                      ],
                    );
                  }),

                  SizedBox(height: 12.h),
                  Divider(),

                  /// Add new relative
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _openAddRelativeSheet(context);
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      child: Text(
                        "+ ${AppLocalizations.of(context)!.addRelative}",
                        style: AppTextStyles.getTitle1(context).copyWith(
                          fontSize: 13.sp,
                          color: AppColors.main,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _patientOption(
      BuildContext context, {
        required String id,
        required String name,
        required bool selected,
      }) {
    final switcher = context.read<PatientSwitcherCubit>();

    final currentUserId =
        (context.read<UserCubit>().state as UserLoaded).userId;

    return GestureDetector(
      onTap: () {
        final currentUser = (context.read<UserCubit>().state as UserLoaded);

        print("📌 TAP ON PATIENT OPTION → id=$id name=$name");
        print("📌 CURRENT USER → ${currentUser.userId}");

        if (id == currentUser.userId) {
          print("➡ Switching to MAIN USER");
          switcher.switchToUser(id, name);
        } else {
          print("➡ Switching to RELATIVE");
          switcher.switchToRelative(id, name);
        }

        print("🧠 [PatientSwitcher] new state after tap → "
            "userId=${switcher.state.userId}, "
            "relativeId=${switcher.state.relativeId}, "
            "mainUserId=${switcher.state.mainUserId}, "
            "patientName=${switcher.state.patientName}");

        Navigator.pop(context);

      },

      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.main.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_rounded,
              color: selected ? AppColors.main : AppColors.grayMain,
              size: 20.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: selected ? AppColors.mainDark : AppColors.grayMain,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _openAddRelativeSheet(BuildContext context) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            child: const AddRelativePage(),
          ),
        );
      },
    );

    // NEW: If relative was added → reload immediately
    if (result == true) {
      print("🔄 New relative added → Reloading relatives...");
      _loadRelatives(context, forceReload: true);
    }
  }




  Widget _buildSectionTitle(
      BuildContext context,
      String title,
      String subtitle,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.getTitle1(context).copyWith(
            fontSize: 15.sp,
            color: AppColors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          subtitle,
          style: AppTextStyles.getText3(context).copyWith(
            fontSize: 11.sp,
            color: AppColors.background3,
          ),
        ),
      ],
    );
  }

  Widget _build2ndSectionTitle(
      BuildContext context,
      String title,
      String subtitle,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.getTitle1(context).copyWith(
            fontSize: 13.sp,
            color: AppColors.mainDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          subtitle,
          style: AppTextStyles.getText3(context).copyWith(
            fontSize: 11.sp,
            color: AppColors.grayMain,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesGrid(
      BuildContext context, List<_HealthCategory> items, bool isArabic) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
        childAspectRatio: 1.22,
      ),
      itemBuilder: (ctx, i) {
        return _HealthCategoryCard(
          category: items[i],
          isArabic: isArabic,
          onTap: () => _onCategoryTap(ctx, items[i]),
        );
      },
    );
  }

  void _onCategoryTap(BuildContext context, _HealthCategory category) {
    if (category.id == "documents") {
      Navigator.push(context, fadePageRoute(const DocumentsPage()));
      return;
    }

    if (category.id == "allergies") {
      Navigator.push(
        context,
        fadePageRoute(const AllergiesPage()),
      );
      return;
    }

    if (category.id == "chronic") {
      Navigator.push(
        context,
        fadePageRoute(const ChronicDiseasePage()),
      );
      return;
    }

    if (category.id == "operations") {
      Navigator.push(
        context,
        fadePageRoute(const SurgeriesPage()),
      );
      return;
    }

    if (category.id == "medications") {
      Navigator.push(
        context,
        fadePageRoute(const MedicationsPage()),
      );
      return;
    }


    if (category.id == "family") {
      Navigator.push(
        context,
        fadePageRoute(const FamilyHistoryPage()),
      );
      return;
    }

    if (category.id == "vaccines") {
      Navigator.push(
        context,
        fadePageRoute(const VaccinationPage()),
      );
      return;
    }

    if (category.id == "visit_reports") {
      final switcher = context.read<PatientSwitcherCubit>().state;

      print("📘 [HealthPage._onCategoryTap] opening VisitReportsPage with: "
          "userId=${switcher.userId}, relativeId=${switcher.relativeId}, "
          "mainUserId=${switcher.mainUserId}, patientName=${switcher.patientName}");

      Navigator.push(
        context,
        fadePageRoute(
          const VisitReportsPage(),
        ),
      );
      return;
    }



    // باقي التابات لاحقاً
    Navigator.push(
      context,
      fadePageRoute(
        HealthSectionPlaceholderPage(
          title: category.title,
          description: category.description,
          icon: category.icon,
        ),
      ),
    );
  }




  List<_HealthCategory> _buildHealthSummary(AppLocalizations t) {
    return [
      _HealthCategory(
        id: "allergies",
        title: t.health_allergies_title,
        description: t.health_allergies_desc,
        icon: Icons.coronavirus_rounded,
      ),
      _HealthCategory(
        id: "chronic",
        title: t.health_chronic_title,
        description: t.health_chronic_desc,
        icon: Icons.favorite_rounded,
      ),
      _HealthCategory(
        id: "operations",
        title: t.health_operations_title,
        description: t.health_operations_desc,
        icon: Icons.local_hospital_rounded,
      ),
      _HealthCategory(
        id: "medications",
        title: t.health_medications_title,
        description: t.health_medications_desc,
        icon: Icons.medication_rounded,
      ),
      _HealthCategory(
        id: "family",
        title: t.health_family_title,
        description: t.health_family_desc,
        icon: Icons.group_rounded,
      ),
      _HealthCategory(
        id: "vaccines",
        title: t.health_vaccines_title,
        description: t.health_vaccines_desc,
        icon: Icons.vaccines_rounded,
      ),
    ];
  }

  List<_HealthCategory> _buildPersonalRecords(AppLocalizations t) {
    return [
      _HealthCategory(
        id: "visit_reports",
        title: t.health_reports_title,
        description: t.health_reports_desc,
        icon: Icons.receipt_long_rounded,
      ),
      _HealthCategory(
        id: "documents",
        title: t.health_documents_title,
        description: t.health_documents_desc,
        icon: Icons.description_rounded,
      ),
    ];
  }

}

class _HealthCategory {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  _HealthCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _HealthCategoryCard extends StatelessWidget {
  final _HealthCategory category;
  final bool isArabic;
  final VoidCallback onTap;

  const _HealthCategoryCard({
    Key? key,
    required this.category,
    required this.isArabic,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18.r),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.97),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.main.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 9,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment:
              isArabic ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 30.w,
                height: 30.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.main.withOpacity(0.10),
                ),
                child: Icon(category.icon,
                    size: 18.sp, color: AppColors.mainDark),
              ),
            ),

            SizedBox(height: 8.h),

            Text(
              category.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: AppTextStyles.getTitle1(context).copyWith(
                fontSize: 12.sp,
                color: AppColors.blackText,
              ),
            ),

            SizedBox(height: 4.h),

            Expanded(
              child: Text(
                category.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                style: AppTextStyles.getText3(context).copyWith(
                  fontSize: 10.sp,
                  color: AppColors.grayMain,
                ),
              ),
            ),

            SizedBox(height: 4.h),

            Align(
              alignment:
              isArabic ? Alignment.centerLeft : Alignment.centerRight,
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12.sp,
                color: AppColors.mainDark.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HealthSectionPlaceholderPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const HealthSectionPlaceholderPage({
    Key? key,
    required this.title,
    required this.description,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.main,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              textDirection:
              isArabic ? TextDirection.rtl : TextDirection.ltr,
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.main.withOpacity(0.12),
                  ),
                  child: Icon(icon,
                      size: 24.sp, color: AppColors.mainDark),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    title,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    style: AppTextStyles.getTitle1(context).copyWith(
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Text(
              description,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: AppTextStyles.getText2(context).copyWith(
                color: AppColors.grayMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
