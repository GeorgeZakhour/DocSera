import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_cubit.dart';
import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_state.dart';
import 'package:docsera/Business_Logic/Health_page/patient_switcher_cubit.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/services/supabase/repositories/health_profile_repository.dart';

import 'package:docsera/screens/home/health/wizard/steps/allergies_step.dart';
import 'package:docsera/screens/home/health/wizard/steps/conditions_step.dart';
import 'package:docsera/screens/home/health/wizard/steps/family_history_step.dart';
import 'package:docsera/screens/home/health/wizard/steps/lifestyle_alcohol_step.dart';
import 'package:docsera/screens/home/health/wizard/steps/lifestyle_smoking_step.dart';
import 'package:docsera/screens/home/health/wizard/steps/lifestyle_sport_step.dart';
import 'package:docsera/screens/home/health/wizard/steps/medications_step.dart';
import 'package:docsera/screens/home/health/wizard/steps/surgeries_step.dart';
import 'package:docsera/screens/home/health/wizard/steps/vitals_height_step.dart';
import 'package:docsera/screens/home/health/wizard/steps/vitals_weight_step.dart';

import 'package:docsera/screens/home/health/wizard/widgets/wizard_completion_screen.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_lottie_header.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_progress_bar.dart';

/// Top-level wizard page. Owns the [HealthProfileWizardCubit], renders the
/// app bar with progress bar + close/back, the per-step Lottie bubble, and
/// orchestrates step transitions via SharedAxis. On WizardCompleted it
/// swaps the whole body for the completion showpiece.
class HealthProfileWizardPage extends StatelessWidget {
  final HealthProfileRepository repo;
  final String userId;
  const HealthProfileWizardPage({
    super.key,
    required this.repo,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    // Lock the wizard's surface to a light theme so dark-mode users still
    // see the cream / white design rather than black.
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.main,
          surface: AppColors.background,
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
        child: BlocProvider(
          create: (_) =>
              HealthProfileWizardCubit(repo: repo, userId: userId)..init(),
          child: const _Body(),
        ),
      ),
    );
  }
}

const _kLottieByStep = <String>[
  'vitals_height',
  'vitals_weight',
  'lifestyle_sport',
  'lifestyle_smoking',
  'lifestyle_alcohol',
  'allergies',
  'conditions',
  'surgeries',
  'family',
  'medications',
];

/// Material icon shown in the bubble until a real Lottie is provided.
const _kIconByStep = <IconData>[
  Icons.height_rounded,
  Icons.monitor_weight_rounded,
  Icons.directions_run_rounded,
  Icons.smoking_rooms_rounded,
  Icons.local_bar_rounded,
  Icons.bubble_chart_rounded,
  Icons.medical_services_rounded,
  Icons.healing_rounded,
  Icons.family_restroom_rounded,
  Icons.medication_rounded,
];

/// Section title shown in the AppBar for each step.
String _sectionTitleForStep(AppLocalizations t, int i) {
  switch (i) {
    case 0:
    case 1:
      return t.healthProfile_section_vitals;
    case 2:
    case 3:
    case 4:
      return t.healthProfile_section_lifestyle;
    case 5:
      return t.healthProfile_section_allergies;
    case 6:
      return t.healthProfile_section_conditions;
    case 7:
      return t.healthProfile_section_surgeries;
    case 8:
      return t.healthProfile_section_family;
    case 9:
      return t.healthProfile_section_medications;
    default:
      return t.healthProfile_wizard_title;
  }
}

class _Body extends StatelessWidget {
  const _Body();

  Widget _buildStep(int i) {
    switch (i) {
      case 0: return const VitalsHeightStep();
      case 1: return const VitalsWeightStep();
      case 2: return const LifestyleSportStep();
      case 3: return const LifestyleSmokingStep();
      case 4: return const LifestyleAlcoholStep();
      case 5: return const AllergiesStep();
      case 6: return const ConditionsStep();
      case 7: return const SurgeriesStep();
      case 8: return const FamilyHistoryStep();
      case 9: return const MedicationsStep();
      default: return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return BlocBuilder<HealthProfileWizardCubit, HealthProfileWizardState>(
      builder: (context, state) {
        if (state is WizardLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is WizardError) {
          final cubit = context.read<HealthProfileWizardCubit>();
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.mainDark),
              ),
            ),
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72.w,
                    height: 72.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.main.withValues(alpha: 0.10),
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 36.sp,
                      color: AppColors.main,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    t.healthProfile_error_title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.getTitle2(context).copyWith(
                      color: AppColors.mainDark,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.getText3(context).copyWith(
                      color: AppColors.grayMain,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => cubit.init(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.main,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        t.healthProfile_error_retry,
                        style: AppTextStyles.getText2(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      t.healthProfile_error_close,
                      style: AppTextStyles.getText2(context).copyWith(
                        color: AppColors.grayMain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (state is WizardCompleted) {
          return WizardCompletionScreen(
            alreadyAwarded: state.alreadyAwarded,
            onDismiss: () => Navigator.of(context).pop(),
          );
        }

        final s = state as WizardActive;
        final cubit = context.read<HealthProfileWizardCubit>();
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 64.h,
            leading: IconButton(
              onPressed: s.stepIndex == 0
                  ? () => Navigator.of(context).pop()
                  : cubit.back,
              icon: Icon(
                s.stepIndex == 0
                    ? Icons.close_rounded
                    : Icons.arrow_back_ios_rounded,
                color: AppColors.mainDark,
                size: s.stepIndex == 0 ? 24.sp : 18.sp,
              ),
            ),
            // Two-line title: section name on top, a small name pill
            // below carrying the main user's first name + avatar dot.
            // This communicates ownership ("this is your profile") without
            // any explicit "for X" copy — just by surfacing the name.
            title: _WizardTitle(
              sectionTitle: _sectionTitleForStep(t, s.stepIndex),
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(14.h),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
                child: WizardProgressBar(
                  totalSteps: kWizardTotalInputSteps,
                  currentIndex: s.stepIndex,
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: WizardLottieHeader(
                  assetName: _kLottieByStep[s.stepIndex],
                  icon: _kIconByStep[s.stepIndex],
                ),
              ),
              Expanded(
                child: PageTransitionSwitcher(
                  transitionBuilder: (child, primary, secondary) =>
                      SharedAxisTransition(
                    animation: primary,
                    secondaryAnimation: secondary,
                    transitionType: SharedAxisTransitionType.horizontal,
                    fillColor: Colors.transparent,
                    child: child,
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(s.stepIndex),
                    child: _buildStep(s.stepIndex),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// AppBar title for the wizard. Renders the current section title and,
/// just beneath it, a small name pill for the main user — a soft signal
/// that the profile being filled belongs to the account holder, without
/// any explicit "this is for X" copy.
class _WizardTitle extends StatelessWidget {
  final String sectionTitle;
  const _WizardTitle({required this.sectionTitle});

  String _firstName(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String _initials(String full) {
    final parts =
        full.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '·';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fullName = context.select<PatientSwitcherCubit, String>(
      (c) => c.state.mainUserName,
    );
    final firstName = _firstName(fullName);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          sectionTitle,
          style: AppTextStyles.getText1(context).copyWith(
            color: AppColors.mainDark,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (firstName.isNotEmpty) ...[
          SizedBox(height: 3.h),
          Container(
            padding: EdgeInsets.fromLTRB(4.w, 2.h, 8.w, 2.h),
            decoration: BoxDecoration(
              color: AppColors.main.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: AppColors.main.withValues(alpha: 0.20),
                width: 0.6,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14.w,
                  height: 14.w,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.main, AppColors.mainDark],
                    ),
                  ),
                  child: Text(
                    _initials(fullName),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 7.5.sp,
                      height: 1,
                    ),
                  ),
                ),
                SizedBox(width: 5.w),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 140.w),
                  child: Text(
                    firstName,
                    style: TextStyle(
                      color: AppColors.mainDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 9.5.sp,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
