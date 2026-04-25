import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_cubit.dart';
import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_state.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_single_select_list.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_step_scaffold.dart';

class LifestyleSmokingStep extends StatelessWidget {
  const LifestyleSmokingStep({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return BlocBuilder<HealthProfileWizardCubit, HealthProfileWizardState>(
      builder: (context, state) {
        final selected =
            (state is WizardActive) ? state.answers.smokingStatus : null;
        final cubit = context.read<HealthProfileWizardCubit>();
        return WizardStepScaffold(
          lottieAssetName: 'lifestyle_smoking',
          title: t.healthProfile_step_smoking_title,
          subtitle: t.healthProfile_step_smoking_subtitle,
          body: WizardSingleSelectList<String>(
            selected: selected,
            onChanged: cubit.setSmoking,
            options: [
              SingleSelectOption(
                value: 'never',
                label: t.healthProfile_smoking_never,
              ),
              SingleSelectOption(
                value: 'former',
                label: t.healthProfile_smoking_former,
              ),
              SingleSelectOption(
                value: 'occasional',
                label: t.healthProfile_smoking_occasional,
              ),
              SingleSelectOption(
                value: 'daily',
                label: t.healthProfile_smoking_daily,
              ),
            ],
          ),
          onSkip: () {
            cubit.setSmoking(null);
            cubit.skip();
          },
          onNext: selected == null ? null : () => cubit.next(),
          nextEnabled: selected != null,
        );
      },
    );
  }
}
