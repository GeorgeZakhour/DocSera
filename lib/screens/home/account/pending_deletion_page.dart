// Account-pending-deletion screen — shown when the user has called
// rpc_request_account_deletion. They have a 30-day cancellation window;
// this page lets them check the days remaining and cancel.
//
// Reached three ways:
//   - Tapping a deletion-warning notification (deep_link: account_deletion:pending)
//   - Login flow detects pending state and routes here (Phase 1.2)
//   - Account → Confidentiality → "Cancel pending deletion" (Phase 1.2)

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:docsera/Business_Logic/Account_page/user_cubit.dart';
import 'package:docsera/services/notifications/notification_service.dart';
import 'package:docsera/services/supabase/user/account_danger_service.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingDeletionPage extends StatefulWidget {
  const PendingDeletionPage({super.key});

  @override
  State<PendingDeletionPage> createState() => _PendingDeletionPageState();
}

class _PendingDeletionPageState extends State<PendingDeletionPage> {
  final _service = AccountDangerService();
  bool _loading = true;
  bool _cancelling = false;
  Map<String, dynamic>? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Pre-flight: if the cached auth.currentUser is null (or expired and
      // the SDK hasn't refreshed yet), the RPC will throw NOT_AUTHENTICATED
      // — short-circuit to login.
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        await _bounceToLogin();
        return;
      }

      final s = await _service.getDeletionStatus();
      if (!mounted) return;

      // The page may have been opened from a stale entry point (login-flow
      // grace-window check using a snapshot from before the user cancelled,
      // or a deletion-warning notification tapped after the deletion was
      // cancelled). If there's no pending deletion server-side, bounce to
      // home so the user doesn't see a stale screen with a broken cancel
      // button.
      final requestedAt = s?['deletion_requested_at'];
      if (requestedAt == null || requestedAt.toString().isEmpty) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          fadePageRoute(CustomBottomNavigationBar()),
          (_) => false,
        );
        return;
      }

      setState(() {
        _status = s;
        _loading = false;
      });
    } catch (e) {
      // NOT_AUTHENTICATED means the access token expired and the auto
      // refresh hasn't kicked in. Sign out and route to login — keeps the
      // user out of a wedged state.
      if (e.toString().contains('NOT_AUTHENTICATED')) {
        await _bounceToLogin();
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _bounceToLogin() async {
    // Drop this device's user_devices row before tearing down the
    // session — RLS needs the JWT to scope the delete to the current
    // user's rows.
    try { await NotificationService.instance.deleteToken(); } catch (_) {}
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _cancel() async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.pendingDeletionConfirmTitle),
        content: Text(loc.pendingDeletionConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.main),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.pendingDeletionCancelCta),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _cancelling = true);
    try {
      await _service.cancelPermanentDeletion();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pendingDeletionCancelledToast),
          backgroundColor: AppColors.main,
        ),
      );
      // Reload user data so cubits see the now-true is_active state, then
      // push the home shell. PendingDeletionPage was reached via
      // pushAndRemoveUntil so popping does nothing — we replace it
      // explicitly.
      // ignore: use_build_context_synchronously
      context.read<UserCubit>().loadUserData(context: context);
      // ignore: use_build_context_synchronously
      Navigator.pushAndRemoveUntil(
        context,
        fadePageRoute(CustomBottomNavigationBar()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      // NOT_AUTHENTICATED → session is stale, bounce to login.
      // no_pending_deletion → server has no pending row, bounce to home.
      final msg = e.toString();
      if (msg.contains('NOT_AUTHENTICATED')) {
        await _bounceToLogin();
        return;
      }
      if (msg.contains('no_pending_deletion')) {
        Navigator.pushAndRemoveUntil(
          context,
          fadePageRoute(CustomBottomNavigationBar()),
          (_) => false,
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.red),
      );
    }
  }

  int? _daysRemaining() {
    final until = _status?['cancellable_until'];
    if (until == null) return null;
    final dt = DateTime.tryParse(until.toString());
    if (dt == null) return null;
    final diff = dt.difference(DateTime.now()).inHours / 24.0;
    return diff.ceil().clamp(0, 30);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    // Block both the AppBar back arrow and the Android system back
    // gesture: this page is the only route on the stack (reached via
    // pushAndRemoveUntil), so popping leads to a black screen. Force
    // the user through one of the explicit exits: Cancel (→ home) or
    // Sign out (→ login).
    return PopScope(
      canPop: false,
      child: BaseScaffold(
      title: Text(
        loc.pendingDeletionTitle,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
      ),
      showBackArrow: false,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.main))
          : _error != null
              ? Center(child: Text(_error!))
              : _status == null || _status!['status'] == 'not_pending'
                  ? _buildNotPending(loc)
                  : _buildPending(loc),
      ),
    );
  }

  Widget _buildNotPending(AppLocalizations loc) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.main, size: 56.sp),
            SizedBox(height: 16.h),
            Text(
              loc.pendingDeletionNoneTitle,
              style: AppTextStyles.getTitle3(context),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              loc.pendingDeletionNoneBody,
              style: AppTextStyles.getText3(context)
                  .copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPending(AppLocalizations loc) {
    final daysLeft = _daysRemaining() ?? 0;
    final isUrgent = daysLeft <= 7;
    final accent = isUrgent ? AppColors.red : AppColors.giftAccent;

    return ListView(
      padding: EdgeInsets.all(20.w),
      children: [
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.10),
                accent.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: accent.withValues(alpha: 0.30),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.18),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.warning_amber_rounded,
                        color: accent, size: 22.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      loc.pendingDeletionHeadline,
                      style: AppTextStyles.getTitle3(context).copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Text(
                loc.pendingDeletionDaysRemaining(daysLeft),
                style: AppTextStyles.getText1(context)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8.h),
              Text(
                loc.pendingDeletionBody,
                style: AppTextStyles.getText3(context)
                    .copyWith(color: Colors.grey.shade800, height: 1.5),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
        FilledButton.icon(
          onPressed: _cancelling ? null : _cancel,
          icon: _cancelling
              ? SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.shield_rounded),
          // Wrap label in a Text-with-explicit-style so the Cairo/Montserrat
          // family from AppTextStyles is applied. FilledButton.styleFrom's
          // textStyle param doesn't pick up the locale-aware font.
          label: Text(
            loc.pendingDeletionCancelCta,
            style: AppTextStyles.getText2(context).copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.main,
            minimumSize: Size(double.infinity, 50.h),
          ),
        ),
        SizedBox(height: 16.h),
        Center(
          child: Text(
            loc.pendingDeletionFootnote,
            style: AppTextStyles.getText4(context)
                .copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 24.h),
        // Explicit sign-out: the user reached this page either right after
        // requesting deletion (still signed in, by design — see the
        // BlocConsumer in DeleteAccountSheet) or via the login flow's
        // grace-window detection. Either way, when they're done reading
        // and don't want to cancel, this button is the polite exit.
        OutlinedButton.icon(
          onPressed: _cancelling ? null : _signOutFromHere,
          icon: Icon(Icons.logout_rounded,
              size: 18.sp, color: Colors.grey.shade700),
          label: Text(
            loc.pendingDeletionSignOutCta,
            style: AppTextStyles.getText3(context).copyWith(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: Size(double.infinity, 46.h),
            side: BorderSide(color: Colors.grey.shade400, width: 0.6),
          ),
        ),
      ],
    );
  }

  Future<void> _signOutFromHere() async {
    try { await NotificationService.instance.deleteToken(); } catch (_) {}
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }
}
