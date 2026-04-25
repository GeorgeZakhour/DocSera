import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_cubit.dart';
import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_state.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_numeric_field.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_step_scaffold.dart';

class VitalsHeightStep extends StatefulWidget {
  const VitalsHeightStep({super.key});
  @override
  State<VitalsHeightStep> createState() => _VitalsHeightStepState();
}

class _VitalsHeightStepState extends State<VitalsHeightStep> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final s = context.read<HealthProfileWizardCubit>().state;
    final initial = s is WizardActive ? s.answers.heightCm?.toString() : null;
    _ctrl = TextEditingController(text: initial ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cubit = context.read<HealthProfileWizardCubit>();
    return WizardStepScaffold(
      lottieAssetName: 'vitals_height',
      title: t.healthProfile_step_height_title,
      body: Center(
        child: WizardNumericField(
          controller: _ctrl,
          label: t.healthProfile_step_height_input,
          onChanged: cubit.setHeight,
        ),
      ),
      onSkip: () {
        cubit.setHeight(null);
        cubit.skip();
      },
      onNext: () => cubit.next(),
    );
  }
}
