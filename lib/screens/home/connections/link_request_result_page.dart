// Animated terminal page shown after a link-request decision.
//
// Three variants driven by [LinkRequestResultKind]:
//   approved (kind='connect') → ✓ teal pulse
//   merged   (kind='merge')   → ✓ teal pulse + "merged" copy
//   rejected                  → grey ring with X
//
// All three share the same scaffolding so the post-decision UX feels
// coherent. Uses TweenAnimationBuilder for the icon — no Lottie dep.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';

enum LinkRequestResultKind { approved, merged, rejected }

class LinkRequestResultPage extends StatelessWidget {
  final LinkRequestResultKind kind;
  final String doctorName;

  const LinkRequestResultPage({
    super.key,
    required this.kind,
    required this.doctorName,
  });

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final isApproved = kind != LinkRequestResultKind.rejected;
    final isMerge = kind == LinkRequestResultKind.merged;

    final title = switch (kind) {
      LinkRequestResultKind.approved => local.linkRequestResultApprovedTitle,
      LinkRequestResultKind.merged   => local.linkRequestResultMergedTitle,
      LinkRequestResultKind.rejected => local.linkRequestResultRejectedTitle,
    };
    final body = switch (kind) {
      LinkRequestResultKind.approved => local.linkRequestResultApprovedBody(doctorName),
      LinkRequestResultKind.merged   => local.linkRequestResultMergedBody(doctorName),
      LinkRequestResultKind.rejected => local.linkRequestResultRejectedBody,
    };
    final accent = isApproved ? AppColors.main : Colors.grey.shade500;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FDFC),
      body: Stack(
        children: [
          // Soft gradient + decorative orbs (consistent with notifications inbox)
          const _BackgroundOrbs(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.topStart,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: Colors.grey.shade700),
                    ),
                  ),
                  const Spacer(),
                  _AnimatedResultIcon(
                    accent: accent,
                    success: isApproved,
                    isMerge: isMerge,
                  ),
                  SizedBox(height: 32.h),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (_, t, child) => Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * 16),
                        child: child,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.getTitle3(context).copyWith(
                            color: AppColors.mainDark,
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: 14.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          child: Text(
                            body,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.getText1(context).copyWith(
                              color: Colors.grey.shade700,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, t, child) => Opacity(opacity: t, child: child),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Merge results push the user toward the
                        // appointments tab — the freshly-migrated
                        // appointment is the most concrete proof the
                        // merge worked, and it's where they likely
                        // wanted to end up.
                        if (isMerge) ...[
                          SizedBox(
                            height: 52.h,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _navigateToTab(context, _appointmentsTabIndex),
                              icon: const Icon(Icons.event_available_rounded,
                                  color: Colors.white),
                              label: Text(
                                local.linkRequestResultMergedAppointmentsCta,
                                style: AppTextStyles.getText1(context).copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          SizedBox(
                            height: 44.h,
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                local.linkRequestResultDone,
                                style: AppTextStyles.getText2(context).copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ] else
                          SizedBox(
                            height: 52.h,
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                              ),
                              child: Text(
                                local.linkRequestResultDone,
                                style: AppTextStyles.getText1(context).copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated icon — success ✓ pulses, merge gets a circular merge glyph,
// rejected gets a grey ring with an X.
// ---------------------------------------------------------------------------

class _AnimatedResultIcon extends StatelessWidget {
  final Color accent;
  final bool success;
  final bool isMerge;
  const _AnimatedResultIcon({
    required this.accent,
    required this.success,
    required this.isMerge,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (_, t, __) {
        return SizedBox(
          width: 160.w,
          height: 160.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Soft halo
              Opacity(
                opacity: 0.15 * t,
                child: Container(
                  width: 160.w,
                  height: 160.w,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Mid ring
              Opacity(
                opacity: 0.30 * t,
                child: Container(
                  width: 124.w,
                  height: 124.w,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Solid disc with glyph
              Transform.scale(
                scale: math.max(0, t),
                child: Container(
                  width: 96.w,
                  height: 96.w,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.30),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    success
                        ? (isMerge ? Icons.merge_type_rounded : Icons.check_rounded)
                        : Icons.close_rounded,
                    color: Colors.white,
                    size: 48.sp,
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

// ---------------------------------------------------------------------------
// Decorative orbs background — soft-mint ambience matching the inbox page.
// ---------------------------------------------------------------------------

class _BackgroundOrbs extends StatelessWidget {
  const _BackgroundOrbs();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE9F8F7), Color(0xFFF7FDFC)],
              ),
            ),
          ),
          Positioned(
            top: -60.h,
            right: -40.w,
            child: Container(
              width: 220.w,
              height: 220.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.main.withValues(alpha: 0.18),
                    AppColors.main.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80.h,
            left: -30.w,
            child: Container(
              width: 260.w,
              height: 260.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.main.withValues(alpha: 0.10),
                    AppColors.main.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab indices on the bottom nav. Centralised here so the constants
/// don't drift if the bar order ever changes.
const int _appointmentsTabIndex = 1;

/// Pops back to the home root and switches the bottom-nav to the
/// requested tab. Mirrors the pattern used by notification_service tap
/// handlers.
void _navigateToTab(BuildContext context, int tabIndex) {
  Navigator.of(context).popUntil((route) => route.isFirst);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final mainScreenState = CustomBottomNavigationBar.globalKey.currentState;
    mainScreenState?.switchTab(tabIndex);
  });
}
