// Patient inbox — chronological, two sections (Today / Earlier).
// Tapping a row marks it read, records a click event, and dispatches the
// stored deep_link via the existing NotificationService handler so we
// reuse the working navigation logic from push taps.
//
// Visual language: layered glass on a soft mint-to-off-white gradient with
// a few decorative orbs. Rows render as frosted cards (real BackdropFilter
// blur) so the orbs subtly bleed through. Typography intentionally
// understated — small caps section headers, refined sizes, the title not
// shouting.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:docsera/Business_Logic/Notifications_page/notifications_cubit.dart';
import 'package:docsera/Business_Logic/Notifications_page/notifications_state.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/models/app_notification.dart';
import 'package:docsera/services/notifications/notification_service.dart';

class NotificationsInboxPage extends StatefulWidget {
  const NotificationsInboxPage({super.key});

  @override
  State<NotificationsInboxPage> createState() => _NotificationsInboxPageState();
}

class _NotificationsInboxPageState extends State<NotificationsInboxPage> {
  @override
  void initState() {
    super.initState();
    // Ensure the cubit is started — safe to call repeatedly.
    context.read<NotificationsCubit>().start();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: AppColors.background2,
      appBar: AppBar(
        backgroundColor: AppColors.main,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 48,
        centerTitle: true,
        titleSpacing: 0,
        leading: IconButton(
          // Chevron style ("<" in LTR, ">" in RTL) — Flutter mirrors
          // arrow_back_ios_new_rounded automatically based on Directionality,
          // so we don't branch manually.
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        leadingWidth: 38.w,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_rounded,
              size: 14.sp,
              color: Colors.white.withValues(alpha: 0.95),
            ),
            SizedBox(width: 6.w),
            Text(
              loc.notifications,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) {
              final hasUnread =
                  state is NotificationsLoaded && state.unreadCount > 0;
              return Padding(
                padding: EdgeInsetsDirectional.only(end: 8.w, start: 4.w),
                child: _GlassMarkAllPill(
                  enabled: hasUnread,
                  label: loc.notificationsMarkAllRead,
                  onTap: () =>
                      context.read<NotificationsCubit>().markAllRead(),
                ),
              );
            },
          ),
        ],
      ),
      body: const _GlassBackdrop(child: _Body()),
    );
  }
}

/// Mark-all-read action rendered as a frosted-glass capsule with an
/// InkWell ripple. Disabled state fades it to white-alpha.
class _GlassMarkAllPill extends StatelessWidget {
  const _GlassMarkAllPill({
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  final bool enabled;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14.r),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.white.withValues(alpha: enabled ? 0.18 : 0.10),
          child: InkWell(
            onTap: enabled ? onTap : null,
            splashColor: Colors.white.withValues(alpha: 0.20),
            highlightColor: Colors.white.withValues(alpha: 0.10),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.done_all_rounded,
                    size: 13.sp,
                    color: Colors.white
                        .withValues(alpha: enabled ? 1.0 : 0.45),
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white
                          .withValues(alpha: enabled ? 1.0 : 0.45),
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
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

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        if (state is NotificationsLoading) {
          return Center(
            child: SizedBox(
              width: 24.w,
              height: 24.w,
              child: const CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.main,
              ),
            ),
          );
        }
        if (state is NotificationsError) {
          return _ErrorState(message: state.message);
        }
        if (state is NotificationsLoaded) {
          if (state.items.isEmpty) {
            return _EmptyState(loc: AppLocalizations.of(context)!);
          }
          return _InboxList(items: state.items);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// Soft mint→off-white gradient with two faint orbs. The actual blur
/// happens at the row level — this just gives the cards something pretty
/// to filter against.
class _GlassBackdrop extends StatelessWidget {
  const _GlassBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEAF6F6), // hint of teal
                  Color(0xFFF7FBFB), // near-white
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -40.h,
          right: -30.w,
          child: _Orb(
            size: 220.w,
            color: AppColors.main.withValues(alpha: 0.14),
          ),
        ),
        Positioned(
          top: 220.h,
          left: -50.w,
          child: _Orb(
            size: 180.w,
            color: AppColors.giftAccent.withValues(alpha: 0.08),
          ),
        ),
        Positioned(
          bottom: 60.h,
          right: -40.w,
          child: _Orb(
            size: 160.w,
            color: AppColors.main.withValues(alpha: 0.07),
          ),
        ),
        child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _InboxList extends StatelessWidget {
  const _InboxList({required this.items});

  final List<AppNotification> items;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final today = <AppNotification>[];
    final earlier = <AppNotification>[];
    final now = DateTime.now();

    for (final n in items) {
      final local = n.createdAt.toLocal();
      if (local.year == now.year &&
          local.month == now.month &&
          local.day == now.day) {
        today.add(n);
      } else {
        earlier.add(n);
      }
    }

    return RefreshIndicator(
      color: AppColors.main,
      backgroundColor: Colors.white,
      strokeWidth: 2.2,
      displacement: 24,
      onRefresh: () => context.read<NotificationsCubit>().refresh(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 32.h),
        children: [
          const _RetentionBanner(),
          SizedBox(height: 6.h),
          if (today.isNotEmpty) ...[
            _SectionHeader(label: loc.notificationsTodaySection),
            ...today.map((n) => _NotificationCard(notification: n)),
          ],
          if (earlier.isNotEmpty) ...[
            SizedBox(height: 6.h),
            _SectionHeader(label: loc.notificationsEarlierSection),
            ...earlier.map((n) => _NotificationCard(notification: n)),
          ],
        ],
      ),
    );
  }
}

/// Tiny glass strip at the top of the inbox telling users notifications
/// are retained for 90 days.
class _RetentionBanner extends StatelessWidget {
  const _RetentionBanner();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(2.w, 8.h, 2.w, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.r),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: AppColors.main.withValues(alpha: 0.18),
                width: 0.6,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 13.sp,
                  color: AppColors.main.withValues(alpha: 0.75),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    loc.notificationsRetentionNote,
                    style: TextStyle(
                      color: AppColors.mainDark.withValues(alpha: 0.7),
                      fontSize: 10.sp,
                      height: 1.3,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(6.w, 14.h, 6.w, 8.h),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: AppColors.mainDark.withValues(alpha: 0.55),
          fontSize: 9.5.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final AppNotification notification;

  String get _categoryEmoji {
    switch (notification.category) {
      case 'appointments':
        return '📅';
      case 'messages':
        return '💬';
      case 'documents':
        return '📄';
      case 'reports':
        return '📝';
      case 'loyalty':
        return '🎁';
      case 'security':
        return '🔐';
      case 'marketing':
        return '📣';
      default:
        return '🔔';
    }
  }

  Color get _accentColor {
    switch (notification.category) {
      case 'appointments':
      case 'messages':
        return AppColors.main;
      case 'loyalty':
        return AppColors.giftAccent;
      case 'security':
        return Colors.blueGrey.shade400;
      default:
        return AppColors.main;
    }
  }

  String _relativeTime(BuildContext context, DateTime when) {
    final loc = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(when.toLocal());
    if (diff.inMinutes < 1) return loc.notificationsJustNow;
    if (diff.inHours < 1) return loc.notificationsMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return loc.notificationsHoursAgo(diff.inHours);
    if (diff.inDays < 7) return loc.notificationsDaysAgo(diff.inDays);
    return DateFormat.yMMMd(Localizations.localeOf(context).toString())
        .format(when.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = notification.isUnread;
    final accent = _accentColor;
    // Per-category very-light tint for unread cards; read cards revert to
    // the neutral white-with-alpha glass. Tints are deliberately faint
    // (8% alpha) so they read as a hint, not a banner.
    final unreadTint = isUnread ? accent.withValues(alpha: 0.08) : null;
    final cardSurface = unreadTint != null
        ? Color.alphaBlend(
            unreadTint, Colors.white.withValues(alpha: 0.88))
        : Colors.white.withValues(alpha: 0.66);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Dismissible(
        key: ValueKey('notif-${notification.id}'),
        direction: DismissDirection.endToStart,
        background: _buildDismissBackground(context),
        onDismissed: (_) {
          context.read<NotificationsCubit>().archive(notification.id);
        },
        child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: cardSurface,
            child: InkWell(
              splashColor: accent.withValues(alpha: 0.08),
              highlightColor: accent.withValues(alpha: 0.04),
              onTap: () async {
                final cubit = context.read<NotificationsCubit>();
                await cubit.recordClick(notification.id);
                final deepLink = notification.deepLink;
                if (deepLink == null || deepLink.isEmpty) return;
                await NotificationService.instance.handleDeepLink(deepLink);
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: isUnread
                        ? accent.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.6),
                    width: 0.7,
                  ),
                ),
                padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryAvatar(
                      emoji: _categoryEmoji,
                      accent: accent,
                      isUnread: isUnread,
                    ),
                    SizedBox(width: 11.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: AppTextStyles.getText3(context)
                                      .copyWith(
                                    fontWeight: isUnread
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: AppColors.mainDark,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                _relativeTime(
                                    context, notification.createdAt),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isUnread) ...[
                                SizedBox(width: 6.w),
                                Container(
                                  margin: EdgeInsets.only(top: 4.h),
                                  width: 7.w,
                                  height: 7.w,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            notification.body,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 10.5.sp,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  /// Red-glass background that slides into view as the user swipes left.
  /// Tapping it (or completing the swipe) archives the notification.
  Widget _buildDismissBackground(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == ui.TextDirection.rtl;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red.shade400.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(18.r),
            ),
            alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
            padding: EdgeInsets.symmetric(horizontal: 18.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white,
                  size: 20.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  loc.notificationsDeleteAction,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
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

class _CategoryAvatar extends StatelessWidget {
  const _CategoryAvatar({
    required this.emoji,
    required this.accent,
    required this.isUnread,
  });

  final String emoji;
  final Color accent;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36.w,
      height: 36.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: isUnread ? 0.18 : 0.10),
            accent.withValues(alpha: isUnread ? 0.08 : 0.04),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
          width: 0.6,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: TextStyle(fontSize: 16.sp, height: 1.0),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.loc});

  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84.w,
              height: 84.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.main.withValues(alpha: 0.15),
                    AppColors.main.withValues(alpha: 0),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.notifications_none_rounded,
                size: 38.sp,
                color: AppColors.main.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              loc.notificationsEmptyTitle,
              style: TextStyle(
                color: AppColors.mainDark,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              loc.notificationsEmptyBody,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11.sp,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppColors.red, size: 32.sp),
            SizedBox(height: 12.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade700),
            ),
            SizedBox(height: 16.h),
            FilledButton(
              onPressed: () =>
                  context.read<NotificationsCubit>().refresh(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.main,
                padding:
                    EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                textStyle:
                    TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600),
              ),
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }
}
