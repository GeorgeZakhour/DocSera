// Connections Center — the unified surface for managing every pending
// patient↔doctor link request. Replaces the old "popup gate that pushes
// one review page" UX with a calm, full-screen list that:
//
//  * Always opens with an explanation header — "why am I seeing this?"
//    is answered before any card is shown
//  * Lists every pending request (connect / merge) at once, not just
//    the most-recent one
//  * Lets the user act on each card inline (approve / not now) so they
//    don't have to navigate into a sub-page for routine decisions
//  * Routes to the existing rich [LinkRequestReviewPage] as a "details"
//    deep-dive when the user wants the full data-flow context
//  * Handles four entry headers (post-signup / banner-tap / notification /
//    account tile) so the same surface feels intentional regardless of
//    how the user reached it
//
// Visual: continuation of the Welcome Wizard's Glass Atelier — mint
// gradient backdrop + glass cards in teal. Visual cohesion makes the
// signup→wizard→connections flow feel like one elegant arrival, not
// three disconnected screens.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/Business_Logic/Connections/connections_center_cubit.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/connections/widgets/connections_request_card.dart';
import 'package:docsera/services/supabase/patient_link_requests_service.dart';

/// Why the page was opened — affects the header copy + whether a "skip
/// to home" footer is shown. Doesn't change the cards themselves.
enum ConnectionsCenterEntry {
  /// Post-signup, immediately after the wizard's "All set" screen.
  postSignup,

  /// User tapped the "you have N pending requests" banner on home.
  fromHome,

  /// User tapped a notification deep-link.
  fromNotification,

  /// User opened the page from the account-page tile.
  fromAccount,
}

class ConnectionsCenterPage extends StatelessWidget {
  final ConnectionsCenterEntry entry;

  /// What to do when the user taps "Continue to home" or finishes the
  /// last request. For post-signup this typically tears down the
  /// auth-stack and pushes the home shell; for in-app entries it's
  /// usually `Navigator.pop(context)`.
  final VoidCallback? onComplete;

  /// Pre-focus a specific request id (e.g. when arriving from a
  /// notification tap). The list still shows everything, but this row
  /// scrolls into view and gets a brief highlight halo.
  final String? focusedRequestId;

  const ConnectionsCenterPage({
    super.key,
    required this.entry,
    this.onComplete,
    this.focusedRequestId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConnectionsCenterCubit()..load(),
      child: _ConnectionsCenterView(
        entry: entry,
        onComplete: onComplete,
        focusedRequestId: focusedRequestId,
      ),
    );
  }
}

class _ConnectionsCenterView extends StatefulWidget {
  final ConnectionsCenterEntry entry;
  final VoidCallback? onComplete;
  final String? focusedRequestId;

  const _ConnectionsCenterView({
    required this.entry,
    required this.onComplete,
    required this.focusedRequestId,
  });

  @override
  State<_ConnectionsCenterView> createState() => _ConnectionsCenterViewState();
}

class _ConnectionsCenterViewState extends State<_ConnectionsCenterView> {
  /// Set to true once the list has gone from non-empty to empty during
  /// this session — drives the "all caught up" celebratory state.
  /// Without this, a user opening the page when the list is already
  /// empty (e.g. via the account tile) would also see the celebratory
  /// state, which is the wrong tone for that context.
  bool _completedAtLeastOne = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectionsCenterCubit, ConnectionsCenterState>(
      listener: (context, state) {
        if (state is ConnectionsCenterLoaded && state.lastResolved != null) {
          _completedAtLeastOne = true;
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFFF1FBF8),
          body: Stack(
            children: [
              const _MintBackdrop(),
              SafeArea(
                child: switch (state) {
                  ConnectionsCenterLoading() => const _LoadingView(),
                  ConnectionsCenterError(:final message) =>
                    _ErrorView(message: message),
                  ConnectionsCenterLoaded() => _LoadedView(
                      state: state,
                      entry: widget.entry,
                      onComplete: widget.onComplete,
                      focusedRequestId: widget.focusedRequestId,
                      completedAtLeastOne: _completedAtLeastOne,
                      onErrorToast: (msg) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: Colors.red.shade700,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  _ => const _LoadingView(),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Backdrop: mint gradient + two soft drifting orbs. Same visual language as
// the Welcome Wizard so the post-signup flow feels like one experience.
// ---------------------------------------------------------------------------

class _MintBackdrop extends StatefulWidget {
  const _MintBackdrop();

  @override
  State<_MintBackdrop> createState() => _MintBackdropState();
}

class _MintBackdropState extends State<_MintBackdrop>
    with TickerProviderStateMixin {
  late final AnimationController _slow;
  late final AnimationController _fast;

  @override
  void initState() {
    super.initState();
    _slow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
    _fast = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _slow.dispose();
    _fast.dispose();
    super.dispose();
  }

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
                colors: [Color(0xFFF1FBF8), Color(0xFFE0F4F0)],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _slow,
            builder: (_, __) {
              final t = _slow.value * 2 * math.pi;
              return Positioned(
                top: 60.h + 14 * (1 + 0.3 * math.sin(t)),
                right: -60.w + 18 * (1 + 0.3 * math.cos(t)),
                child: _Orb(size: 240.w, alpha: 0.30),
              );
            },
          ),
          AnimatedBuilder(
            animation: _fast,
            builder: (_, __) {
              final t = _fast.value * 2 * math.pi;
              return Positioned(
                bottom: 100.h + 22 * (1 + 0.3 * math.cos(t)),
                left: -80.w + 14 * (1 + 0.3 * math.sin(t)),
                child: _Orb(size: 280.w, alpha: 0.22),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final double alpha;
  const _Orb({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.main.withValues(alpha: alpha),
            AppColors.main.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading + error states
// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.main),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 56.sp, color: Colors.grey.shade400),
          SizedBox(height: 16.h),
          Text(
            local.connectionsCenterErrorTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.getTitle3(context).copyWith(
              color: AppColors.mainDark,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            local.connectionsCenterErrorBody,
            textAlign: TextAlign.center,
            style: AppTextStyles.getText2(context).copyWith(
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: () =>
                context.read<ConnectionsCenterCubit>().load(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.main,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 12.h),
            ),
            child: Text(
              local.connectionsCenterRetry,
              style: AppTextStyles.getText1(context).copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loaded view: header + cards + footer
// ---------------------------------------------------------------------------

class _LoadedView extends StatelessWidget {
  final ConnectionsCenterLoaded state;
  final ConnectionsCenterEntry entry;
  final VoidCallback? onComplete;
  final String? focusedRequestId;
  final bool completedAtLeastOne;
  final void Function(String message) onErrorToast;

  const _LoadedView({
    required this.state,
    required this.entry,
    required this.onComplete,
    required this.focusedRequestId,
    required this.completedAtLeastOne,
    required this.onErrorToast,
  });

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    if (state.isEmpty) {
      return _AllClearView(
        celebratory: completedAtLeastOne,
        onComplete: onComplete,
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderBlock(entry: entry),
          SizedBox(height: 24.h),
          const _IntroExplainer(),
          SizedBox(height: 20.h),
          for (final req in state.requests)
            Padding(
              padding: EdgeInsets.only(bottom: 14.h),
              child: ConnectionsRequestCard(
                request: req,
                isActing: state.actingOnId == req.id,
                resolved: state.lastResolved?.requestId == req.id
                    ? state.lastResolved
                    : null,
                isFocused:
                    focusedRequestId != null && req.id == focusedRequestId,
                onApprove: () => _respond(context, req, true),
                onDecline: () => _respond(context, req, false),
              ),
            ),
          SizedBox(height: 8.h),
          _FooterButton(
            label: local.connectionsCenterCtaReviewLater,
            onTap: onComplete ?? () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    PatientLinkRequest req,
    bool approve,
  ) async {
    final local = AppLocalizations.of(context)!;
    final cubit = context.read<ConnectionsCenterCubit>();

    if (!approve) {
      final choice = await showDialog<_DeclineChoice>(
        context: context,
        builder: (ctx) => _DeclineDialog(doctorName: req.nameWithoutTitle),
      );
      if (choice == null || choice == _DeclineChoice.cancel) return;
      if (choice == _DeclineChoice.notNow) return; // leave pending
      // declinePermanent → fall through to server call
    }

    try {
      await cubit.respond(requestId: req.id, approve: approve);
    } catch (_) {
      onErrorToast(local.connectionsCenterErrorToast);
    }
  }
}

// ---------------------------------------------------------------------------
// Header — contextual title
// ---------------------------------------------------------------------------

class _HeaderBlock extends StatelessWidget {
  final ConnectionsCenterEntry entry;
  const _HeaderBlock({required this.entry});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final title = switch (entry) {
      ConnectionsCenterEntry.postSignup =>
        local.connectionsCenterTitlePostSignup,
      ConnectionsCenterEntry.fromHome => local.connectionsCenterTitleHome,
      ConnectionsCenterEntry.fromNotification =>
        local.connectionsCenterTitleNotification,
      ConnectionsCenterEntry.fromAccount =>
        local.connectionsCenterTitleAccount,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56.w,
          height: 56.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.main.withValues(alpha: 0.95),
                const Color(0xFF4DD0D2),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.main.withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.handshake_rounded,
            color: Colors.white,
            size: 28.sp,
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          title,
          style: AppTextStyles.getTitle1(context).copyWith(
            color: AppColors.mainDark,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _IntroExplainer extends StatelessWidget {
  const _IntroExplainer();

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.main, size: 16.sp),
                  SizedBox(width: 8.w),
                  Text(
                    local.connectionsCenterExplainerHeader,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: AppColors.main,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                local.connectionsCenterExplainerBody,
                style: AppTextStyles.getText2(context).copyWith(
                  color: Colors.grey.shade800,
                  height: 1.55,
                ),
              ),
              SizedBox(height: 10.h),
              _ReassurancePill(
                icon: Icons.shield_outlined,
                text: local.connectionsCenterReassureNothingAuto,
              ),
              SizedBox(height: 6.h),
              _ReassurancePill(
                icon: Icons.access_time_rounded,
                text: local.connectionsCenterReassureCanReviewLater,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReassurancePill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ReassurancePill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14.sp, color: Colors.grey.shade600),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.getText3(context).copyWith(
              color: Colors.grey.shade700,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Footer button + "all clear" celebratory state
// ---------------------------------------------------------------------------

class _FooterButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.main,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.getText1(context).copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _AllClearView extends StatelessWidget {
  final bool celebratory;
  final VoidCallback? onComplete;

  const _AllClearView({
    required this.celebratory,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    final title = celebratory
        ? local.connectionsCenterAllCaughtUpTitle
        : local.connectionsCenterEmptyTitle;
    final body = celebratory
        ? local.connectionsCenterAllCaughtUpBody
        : local.connectionsCenterEmptyBody;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, t, child) => Opacity(
              opacity: ((t - 0.85) / 0.15).clamp(0.0, 1.0),
              child: Transform.scale(scale: t, child: child),
            ),
            child: Container(
              width: 110.w,
              height: 110.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.main.withValues(alpha: 0.95),
                    const Color(0xFF4DD0D2),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.main.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Icon(
                celebratory ? Icons.check_rounded : Icons.spa_outlined,
                color: Colors.white,
                size: 56.sp,
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.getTitle2(context).copyWith(
              color: AppColors.mainDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTextStyles.getText2(context).copyWith(
              color: Colors.grey.shade700,
              height: 1.55,
            ),
          ),
          SizedBox(height: 32.h),
          _FooterButton(
            label: local.connectionsCenterCtaContinue,
            onTap: onComplete ?? () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Decline confirmation dialog — three choices: cancel / not now / decline
// ---------------------------------------------------------------------------

enum _DeclineChoice { cancel, notNow, declinePermanent }

class _DeclineDialog extends StatelessWidget {
  final String doctorName;
  const _DeclineDialog({required this.doctorName});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 16.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppColors.main.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.access_time_rounded,
                    color: AppColors.main,
                    size: 28.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  local.connectionsDeclineDialogTitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.getTitle3(context).copyWith(
                    color: AppColors.mainDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  local.connectionsDeclineDialogBody(doctorName),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.getText2(context).copyWith(
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 22.h),
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_DeclineChoice.notNow),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.main,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      local.connectionsDeclineDialogNotNow,
                      style: AppTextStyles.getText1(context).copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: TextButton(
                    onPressed: () => Navigator.of(context)
                        .pop(_DeclineChoice.declinePermanent),
                    child: Text(
                      local.connectionsDeclineDialogDecline,
                      style: AppTextStyles.getText2(context).copyWith(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_DeclineChoice.cancel),
                  child: Text(
                    local.cancel,
                    style: AppTextStyles.getText3(context).copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
