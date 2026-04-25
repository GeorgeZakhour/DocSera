import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_cubit.dart';
import 'package:docsera/Business_Logic/Health_page/wizard/health_profile_wizard_state.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/wizard/widgets/wizard_step_scaffold.dart';

class VitalsWeightStep extends StatefulWidget {
  const VitalsWeightStep({super.key});
  @override
  State<VitalsWeightStep> createState() => _VitalsWeightStepState();
}

class _VitalsWeightStepState extends State<VitalsWeightStep> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final s = context.read<HealthProfileWizardCubit>().state;
    final initial = s is WizardActive ? s.answers.weightKg?.toString() : null;
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
      lottieAssetName: 'vitals_weight',
      title: t.healthProfile_step_weight_title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.healthProfile_step_weight_input,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: _ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) => cubit.setWeight(int.tryParse(v)),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
      onSkip: () {
        cubit.setWeight(null);
        cubit.skip();
      },
      onNext: () => cubit.next(),
    );
  }
}
