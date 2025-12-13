import 'package:docsera/screens/home/health/widgets/health_ghost_button.dart';
import 'package:docsera/screens/home/health/widgets/health_primary_button.dart';
import 'package:docsera/screens/home/health/widgets/health_step_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';


/// --------------------------------------------
/// MODEL: Defines each Step
/// --------------------------------------------
class AddHealthRecordStep {
  final String title;
  final Widget Function(BuildContext context) builder;

  /// Optional: If a step needs validation before going next
  final Future<bool> Function()? onNext;

  /// Optional step (skip allowed)
  final bool optional;

  AddHealthRecordStep({
    required this.title,
    required this.builder,
    this.onNext,
    this.optional = false,
  });
}

/// --------------------------------------------
/// MAIN CONTROLLER WIDGET
/// --------------------------------------------
class AddHealthRecordSheet extends StatefulWidget {
  final List<AddHealthRecordStep> steps;

  /// Called when pressing Save on last step
  final Future<void> Function() onSave;

  const AddHealthRecordSheet({
    super.key,
    required this.steps,
    required this.onSave,
  });

  @override
  State<AddHealthRecordSheet> createState() => _AddHealthRecordSheetState();
}

class _AddHealthRecordSheetState extends State<AddHealthRecordSheet>
    with TickerProviderStateMixin {
  int _step = 0;
  bool _saving = false;

  bool get isLastStep => _step == widget.steps.length - 1;

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _next() async {
    final step = widget.steps[_step];

    // If validation exists
    if (step.onNext != null) {
      final canContinue = await step.onNext!();
      if (!canContinue) return;
    }

    if (!isLastStep) {
      setState(() => _step++);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final titles = widget.steps.map((e) => e.title).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 12.h,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12.h,
          ),

          child: Column(
            children: [
              // Header
              HealthStepHeader(
                titles: titles,
                step: _step + 1,
                onBack: _back,
              ),

              SizedBox(height: 12.h),

              // Step Content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: widget.steps[_step].builder(context),
                ),
              ),

              SizedBox(height: 12.h),

              // Footer Buttons
              if (!isLastStep) ...[
                if (widget.steps[_step].optional)
                  HealthGhostButton(
                    text: "Skip",
                    onTap: _next,
                  ),
                SizedBox(height: 5.h),
                HealthPrimaryButton(
                  text: "Next",
                  onTap: _next,
                ),
              ] else ...[
                HealthPrimaryButton(
                  text: "Save",
                  loading: _saving,
                  onTap: _saving ? null : _save,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
