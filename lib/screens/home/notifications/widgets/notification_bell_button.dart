// Bell icon with unread badge. Sits in the home tab's top bar (right
// side, mirroring the language button on the left). Sized to match the
// surrounding top-bar icon dimensions — keep these magic numbers in sync
// with custom_bottom_navigation_bar.dart's language button if styling
// there changes.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
        return Tooltip(
          message: loc.notifications,
          child: InkResponse(
            onTap: () {
              Navigator.of(context).push(
                fadePageRoute(const NotificationsInboxPage()),
              );
            },
            radius: 22,
            child: SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.whiteText,
                    size: 22,
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 11,
                      right: 11,
                      child: IgnorePointer(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: unread > 9 ? 4 : 0,
                            vertical: 0,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.giftAccent,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: AppColors.main,
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
