import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/widgets/health_primary_button.dart';

class FamilyAgeStep extends StatefulWidget {

  final int? age;
  final void Function(int?) onChanged;
  final VoidCallback onNext;

  const FamilyAgeStep({
    super.key,
    required this.age,
    required this.onChanged,
    required this.onNext,
  });

  @override
  State<FamilyAgeStep> createState() => _FamilyAgeStepState();
}

class _FamilyAgeStepState extends State<FamilyAgeStep> {
  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.age != null) controller.text = widget.age.toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10.h),

        Text(
          t.addFamily_step3_title,
          style: AppTextStyles.getTitle1(context).copyWith(
            fontSize: 12.sp,
            color: AppColors.mainDark,
          ),
        ),

        SizedBox(height: 8.h),

        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: t.addFamily_step3_fieldHint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          onChanged: (v) {
            final age = int.tryParse(v);
            widget.onChanged(age);
          },
        ),

        Spacer(),

        HealthPrimaryButton(
          text: t.next,
          onTap: widget.onNext,
        ),

        SizedBox(height: 15.h)
      ],
    );
  }
}
