import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_cubit.dart';
import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_state.dart';
import 'package:docsera/app/const.dart';
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
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.grayMain,
                    fontSize: 14.sp,
                  ),
                ),
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
            leading: IconButton(
              onPressed: s.stepIndex == 0
                  ? () => Navigator.of(context).pop()
                  : cubit.back,
              icon: Icon(
                s.stepIndex == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
                color: AppColors.mainDark,
              ),
            ),
            title: Text(
              t.healthProfile_wizard_title,
              style: TextStyle(
                color: AppColors.mainDark,
                fontWeight: FontWeight.w600,
                fontSize: 15.sp,
              ),
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
