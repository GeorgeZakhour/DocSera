import 'dart:ui';
import 'package:docsera/Business_Logic/Account_page/profile/account_profile_cubit.dart';
import 'package:docsera/Business_Logic/Account_page/profile/account_profile_state.dart';
import 'package:docsera/Business_Logic/Account_page/relatives/relatives_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
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
import 'package:docsera/utils/full_page_loader.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HealthPage extends StatelessWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AppAuthState>(
      builder: (context, authState) {
        if (authState is AuthLoading || authState is AuthInitial) {
          return const Center(child: FullPageLoader());
        }

        if (authState is AuthUnauthenticated) {
          return const HealthLoggedOutView();
        }

        if (authState is AuthAuthenticated) {
          return const HealthAuthenticatedView();
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class HealthAuthenticatedView extends StatefulWidget {
  const HealthAuthenticatedView({super.key});

  @override
  State<HealthAuthenticatedView> createState() =>
      _HealthAuthenticatedViewState();
}

class _HealthAuthenticatedViewState extends State<HealthAuthenticatedView> {

  @override
  void initState() {
    super.initState();

    // 1) تحميل الأقارب (كما هو)
    context.read<RelativesCubit>().loadRelatives();
    // 2) تحميل البروفايل (مصدر اسم المستخدم الأساسي الحقيقي)
    context.read<AccountProfileCubit>().loadProfile();
  }




  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final t = AppLocalizations.of(context)!;
    final summary = _buildHealthSummary(t);
    final personal = _buildPersonalRecords(t);

    return MultiBlocListener(
      listeners: [
        BlocListener<AccountProfileCubit, AccountProfileState>(
          listenWhen: (prev, curr) => curr is AccountProfileLoaded,
          listener: (context, state) {
            final s = state as AccountProfileLoaded;

            // الاسم يأتي من جدول users عبر rpc_get_my_user
            final mainName = (s.fullName).trim();

            // hydrate PatientSwitcher
            context.read<PatientSwitcherCubit>().setMainUser(
              id: s.userId,
              name: mainName.isEmpty
                  ? AppLocalizations.of(context)!.unknown
                  : mainName,
            );
          },
        ),
      ],
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.main, AppColors.background],
            stops: [0.0, 0.80],
          ),
        ),
        child: SafeArea(
          top: true,
          bottom: false,
          child: BlocBuilder<PatientSwitcherCubit, PatientSwitcherState>(
            builder: (context, state) {
              if (state.mainUserId == null) {
                return const Center(child: FullPageLoader(size: 28));
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10.h),
                    _buildPatientGlassSwitcher(context),
                    SizedBox(height: 20.h),

                    _buildSectionTitle(
                      context,
                      t.health_summary,
                      t.health_patientSubtitle,
                    ),
                    SizedBox(height: 14.h),
                    _buildCategoriesGrid(context, summary, isArabic),

                    SizedBox(height: 18.h),

                    _build2ndSectionTitle(
                      context,
                      t.health_personalRecords_title,
                      t.health_personalRecords_subtitle,
                    ),
                    SizedBox(height: 10.h),
                    _buildCategoriesGrid(context, personal, isArabic),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }


  Widget _buildPatientGlassSwitcher(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return BlocBuilder<PatientSwitcherCubit, PatientSwitcherState>(
      builder: (context, state) {
        return GestureDetector(
          onTap: () => _openPatientPopup(context),
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
                    color: AppColors.main.withOpacity(0.35),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Row(
                  textDirection:
                  isArabic ? TextDirection.rtl : TextDirection.ltr,
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
                            offset: const Offset(0, 2),
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



  void _openPatientPopup(BuildContext pageContext) {
    final state = context.read<PatientSwitcherCubit>().state;

    showDialog(
      context: pageContext,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (dialogContext) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 320.w,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.health_switch,
                    style: AppTextStyles.getTitle1(context)
                        .copyWith(fontSize: 14.sp),
                  ),
                  SizedBox(height: 12.h),
                  BlocBuilder<RelativesCubit, RelativesState>(
                    builder: (context, relState) {
                      if (relState is RelativesLoading) {
                        return const Center(child: FullPageLoader(size: 24));
                      }

                      if (relState is! RelativesLoaded) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// المستخدم الأساسي
                          _patientOption(
                            context,
                            id: state.mainUserId!,
                            name: state.mainUserName,
                            selected: state.relativeId == null,
                          ),

                          const SizedBox(height: 6),

                          /// الأقارب
                          ...relState.relatives.map((r) {
                            final name =
                            "${r['first_name'] ?? ''} ${r['last_name'] ?? ''}".trim();

                            return Padding(
                              padding: EdgeInsets.only(top: 6.h),
                              child: _patientOption(
                                context,
                                id: r['id'],
                                name: name.isEmpty
                                    ? AppLocalizations.of(context)!.unknown
                                    : name,
                                selected: state.relativeId == r['id'],
                              ),
                            );
                          }),

                          const SizedBox(height: 12),
                          const Divider(),

                          GestureDetector(
                            onTap: () {
                              Navigator.of(dialogContext).pop(); // أغلق dialog
                              _openAddRelativeSheet(pageContext);
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              child: Text(
                                "+ ${AppLocalizations.of(context)!.addRelative}",
                                style: AppTextStyles.getTitle1(context)
                                    .copyWith(color: AppColors.main),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
    final mainUserId = switcher.state.mainUserId;

    return GestureDetector(
      onTap: () {
        if (id == mainUserId) {
          switcher.switchToUser();
        } else {
          switcher.switchToRelative(
            relativeId: id,
            relativeName: name,
          );
        }
        Navigator.pop(context);
      },

      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.main.withOpacity(0.10) : null,
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
                  color:
                  selected ? AppColors.mainDark : AppColors.grayMain,
                  fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
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
          child: const AddRelativePage(),
        );
      },
    );

    if (result == true) {
      context.read<RelativesCubit>().loadRelatives();
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

      debugPrint("📘 [HealthPage._onCategoryTap] opening VisitReportsPage with: "
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

class HealthLoggedOutView extends StatelessWidget {
  const HealthLoggedOutView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.main,
            AppColors.background,
          ],
          stops: [0.0, 0.8],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_rounded,
                  size: 90.sp,
                  color: Colors.white,
                ),

                SizedBox(height: 20.h),

                Text(
                  t.health_loggedOut_title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.getTitle2(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 10.h),

                Text(
                  t.health_loggedOut_description,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.getText2(context).copyWith(
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),

                SizedBox(height: 30.h),

                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: 36.w,
                      vertical: 14.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Text(
                    t.logIn,
                    style: AppTextStyles.getTitle2(context).copyWith(
                      color: AppColors.main,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    required this.category,
    required this.isArabic,
    required this.onTap,
  });

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
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

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

