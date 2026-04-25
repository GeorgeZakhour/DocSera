import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_cubit.dart';
import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_state.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_single_select_list.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_step_scaffold.dart';

class LifestyleAlcoholStep extends StatelessWidget {
  const LifestyleAlcoholStep({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return BlocBuilder<HealthProfileWizardCubit, HealthProfileWizardState>(
      builder: (context, state) {
        final selected =
            (state is WizardActive) ? state.answers.alcoholFrequency : null;
        final cubit = context.read<HealthProfileWizardCubit>();
        return WizardStepScaffold(
          lottieAssetName: 'lifestyle_alcohol',
          title: t.healthProfile_step_alcohol_title,
          subtitle: t.healthProfile_step_alcohol_subtitle,
          body: WizardSingleSelectList<String>(
            selected: selected,
            onChanged: cubit.setAlcohol,
            options: [
              SingleSelectOption(
                value: 'never',
                label: t.healthProfile_freq_never,
              ),
              SingleSelectOption(
                value: 'less_than_weekly',
                label: t.healthProfile_freq_lt_weekly,
              ),
              SingleSelectOption(
                value: '1_2',
                label: t.healthProfile_freq_1_2,
              ),
              SingleSelectOption(
                value: '3_4',
                label: t.healthProfile_freq_3_4,
              ),
              SingleSelectOption(
                value: '5_plus',
                label: t.healthProfile_freq_5_plus,
              ),
            ],
          ),
          onSkip: () {
            cubit.setAlcohol(null);
            cubit.skip();
          },
          onNext: selected == null ? null : () => cubit.next(),
          nextEnabled: selected != null,
        );
      },
    );
  }
}
