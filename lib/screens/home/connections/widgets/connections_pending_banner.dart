// Soft banner shown on the home screen whenever the user has pending
// patient↔doctor link requests. Replaces the old popup-gate UX:
//
//   * Non-blocking — user can dismiss it for the session and continue
//     using the app
//   * Persistent — comes back on the next session as long as requests
//     remain pending
//   * Tap → opens [ConnectionsCenterPage] in `fromHome` entry mode
//
// Shape:
//   • 64-72.h tall, full-width, gentle teal gradient
//   • Tag pill on the left ("3" badge or "1 طلب جديد"), title + body in
//     the middle, chevron at the trailing edge
//   • Slides down from the top of the home content on first paint with
//     a subtle bounce; idle after that.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/connections/connections_center_page.dart';
import 'package:docsera/services/supabase/patient_link_requests_service.dart';

/// Self-fetching banner — caller doesn't need to know about pending
/// state. Renders nothing when there are zero pending requests.
class ConnectionsPendingBanner extends StatefulWidget {
  const ConnectionsPendingBanner({super.key});

  @override
  State<ConnectionsPendingBanner> createState() =>
      _ConnectionsPendingBannerState();
}

class _ConnectionsPendingBannerState extends State<ConnectionsPendingBanner> {
  Future<int>? _pendingCountFuture;

  @override
  void initState() {
    super.initState();
    _pendingCountFuture = _fetchCount();
  }

  Future<int> _fetchCount() async {
    try {
      final pending = await PatientLinkRequestsService().fetchPending();
      return pending.length;
    } catch (_) {
      return 0;
    }
  }

  void _refresh() {
    setState(() {
      _pendingCountFuture = _fetchCount();
    });
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConnectionsCenterPage(
          entry: ConnectionsCenterEntry.fromHome,
          onComplete: () => Navigator.of(context).pop(),
        ),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _pendingCountFuture,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 4.h),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 460),
            curve: Curves.easeOutCubic,
            builder: (_, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * -10),
                child: child,
              ),
            ),
            child: _BannerCard(count: count, onTap: _open),
          ),
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _BannerCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.main.withValues(alpha: 0.18),
                    AppColors.main.withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color: AppColors.main.withValues(alpha: 0.30),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.main.withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Count badge
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.main,
                          const Color(0xFF4DD0D2),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.main.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$count',
                      style: AppTextStyles.getTitle3(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          count == 1
                              ? local.connectionsBannerTitleSingular
                              : local.connectionsBannerTitlePlural(count),
                          style: AppTextStyles.getText2(context).copyWith(
                            color: AppColors.mainDark,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          local.connectionsBannerBody,
                          style: AppTextStyles.getText3(context).copyWith(
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.main,
                    size: 22.sp,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
