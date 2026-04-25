import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

/// Three-state affordance shown at the bottom of multi-select wizard sections.
///
///   - [anySelected] = true → renders nothing (the user has explicit data).
///   - [confirmed] = true → renders an animated check pill confirming
///     "no entries", with a Change action to revert.
///   - otherwise → renders the outlined "No allergy / No condition / etc."
///     button. Tapping it sets the confirmed state via [onTap].
class WizardNoDataButton extends StatelessWidget {
  final String label;
  final bool anySelected;
  final bool confirmed;
  final VoidCallback onTap;
  final VoidCallback? onChange;

  const WizardNoDataButton({
    super.key,
    required this.label,
    required this.anySelected,
    required this.onTap,
    this.confirmed = false,
    this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(anim),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(anim),
            child: child,
          ),
        ),
      ),
      child: anySelected
          ? const SizedBox.shrink(key: ValueKey('hidden'))
          : confirmed
              ? _ConfirmedPill(
                  key: const ValueKey('confirmed'),
                  onChange: onChange,
                )
              : _OutlinedButton(
                  key: const ValueKey('idle'),
                  label: label,
                  onTap: onTap,
                ),
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlinedButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppColors.main.withValues(alpha: 0.35),
          ),
          color: AppColors.main.withValues(alpha: 0.04),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.getText1(context).copyWith(
              color: AppColors.main,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmedPill extends StatefulWidget {
  final VoidCallback? onChange;
  const _ConfirmedPill({super.key, required this.onChange});

  @override
  State<_ConfirmedPill> createState() => _ConfirmedPillState();
}

class _ConfirmedPillState extends State<_ConfirmedPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _checkCtrl;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 8.w, 12.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        gradient: LinearGradient(colors: [
          AppColors.main.withValues(alpha: 0.10),
          AppColors.main.withValues(alpha: 0.04),
        ]),
        border: Border.all(
          color: AppColors.main.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _checkCtrl,
              curve: Curves.elasticOut,
            ),
            child: Container(
              width: 26.w,
              height: 26.w,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.main,
              ),
              child: Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 16.sp,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              t.healthProfile_no_entry_confirmed,
              style: AppTextStyles.getText2(context).copyWith(
                color: AppColors.mainDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (widget.onChange != null)
            TextButton(
              onPressed: widget.onChange,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: 10.w,
                  vertical: 4.h,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                t.healthProfile_change,
                style: AppTextStyles.getText3(context).copyWith(
                  color: AppColors.main,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.main.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
