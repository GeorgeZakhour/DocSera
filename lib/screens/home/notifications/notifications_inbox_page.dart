// Patient inbox — chronological, two sections (Today / Earlier).
// Tapping a row marks it read, records a click event, and dispatches the
// stored deep_link via the existing NotificationService handler so we
// reuse the working navigation logic from push taps.

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
      backgroundColor: AppColors.background2,
      appBar: AppBar(
        backgroundColor: AppColors.main,
        foregroundColor: Colors.white,
        title: Text(
          loc.notifications,
          style: AppTextStyles.getTitle3(context).copyWith(color: Colors.white),
        ),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) {
              final hasUnread =
                  state is NotificationsLoaded && state.unreadCount > 0;
              return TextButton(
                onPressed: hasUnread
                    ? () => context.read<NotificationsCubit>().markAllRead()
                    : null,
                child: Text(
                  loc.notificationsMarkAllRead,
                  style: TextStyle(
                    color: hasUnread
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize: 12.sp,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state is NotificationsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is NotificationsError) {
            return _ErrorState(message: state.message);
          }
          if (state is NotificationsLoaded) {
            if (state.items.isEmpty) {
              return _EmptyState(loc: loc);
            }
            return _InboxList(items: state.items);
          }
          return const SizedBox.shrink();
        },
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
      onRefresh: () => context.read<NotificationsCubit>().refresh(),
      child: ListView(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        children: [
          if (today.isNotEmpty) ...[
            _SectionHeader(label: loc.notificationsTodaySection),
            ...today.map((n) => _NotificationRow(notification: n)),
          ],
          if (earlier.isNotEmpty) ...[
            _SectionHeader(label: loc.notificationsEarlierSection),
            ...earlier.map((n) => _NotificationRow(notification: n)),
          ],
          SizedBox(height: 24.h),
        ],
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
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
      child: Text(
        label,
        style: AppTextStyles.getText3(context).copyWith(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification});

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
    return InkWell(
      onTap: () async {
        final cubit = context.read<NotificationsCubit>();
        await cubit.recordClick(notification.id);
        final deepLink = notification.deepLink;
        if (deepLink == null || deepLink.isEmpty) return;
        // Reuse the existing push-tap handler so navigation rules stay
        // in one place — adding a new destination here should never be
        // needed; add it to NotificationService.handleDeepLink instead.
        await NotificationService.instance.handleDeepLink(deepLink);
      },
      child: Container(
        color: isUnread
            ? AppColors.main.withValues(alpha: 0.04)
            : Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: const BoxDecoration(
                color: AppColors.background3,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(_categoryEmoji, style: TextStyle(fontSize: 18.sp)),
            ),
            SizedBox(width: 12.w),
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
                          style: AppTextStyles.getText2(context).copyWith(
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: AppColors.mainDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          margin: EdgeInsets.only(left: 6.w, top: 6.h),
                          width: 8.w,
                          height: 8.w,
                          decoration: const BoxDecoration(
                            color: AppColors.giftAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    notification.body,
                    style: AppTextStyles.getText3(context).copyWith(
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _relativeTime(context, notification.createdAt),
                    style: AppTextStyles.getText4(context).copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            Icon(
              Icons.notifications_none,
              size: 56.sp,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16.h),
            Text(
              loc.notificationsEmptyTitle,
              style: AppTextStyles.getTitle3(context).copyWith(
                color: AppColors.mainDark,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              loc.notificationsEmptyBody,
              style: AppTextStyles.getText3(context).copyWith(
                color: Colors.grey.shade700,
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
            Icon(Icons.error_outline, color: AppColors.red, size: 40.sp),
            SizedBox(height: 12.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.getText3(context),
            ),
            SizedBox(height: 16.h),
            FilledButton(
              onPressed: () =>
                  context.read<NotificationsCubit>().refresh(),
              style: FilledButton.styleFrom(backgroundColor: AppColors.main),
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }
}
