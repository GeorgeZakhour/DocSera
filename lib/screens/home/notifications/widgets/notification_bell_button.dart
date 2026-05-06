// Bell icon with unread badge for the home screen TopSection.
// Subscribes to NotificationsCubit so the badge updates live without
// the home tab needing to re-render.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/Business_Logic/Notifications_page/notifications_cubit.dart';
import 'package:docsera/Business_Logic/Notifications_page/notifications_state.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/notifications/notifications_inbox_page.dart';
import 'package:docsera/utils/page_transitions.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        final int unread =
            state is NotificationsLoaded ? state.unreadCount : 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: loc.notifications,
              icon: Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 24.sp,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  fadePageRoute(const NotificationsInboxPage()),
                );
              },
            ),
            if (unread > 0)
              Positioned(
                top: 6.h,
                right: 6.w,
                child: IgnorePointer(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: unread > 9 ? 5.w : 0,
                      vertical: 1.h,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16.w,
                      minHeight: 16.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.giftAccent,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: AppColors.main, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
