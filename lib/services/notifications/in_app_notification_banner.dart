// In-app notification banner — shown when a notification (push OR local
// reminder) fires while the app is in the foreground. Pushy's iOS SDK
// installs itself as the UNUserNotificationCenterDelegate and tells iOS
// not to present banners while the app is foregrounded; it only forwards
// the data to our Flutter listener. Without this overlay, foreground
// notifications would be invisible to the user.
//
// Background flow is unaffected: iOS presents notifications natively on
// the lock screen / pull-down without going through the delegate.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/app/const.dart';
import 'package:docsera/services/notifications/notification_service.dart';

class InAppNotificationBanner {
  InAppNotificationBanner._();

  static OverlayEntry? _entry;
  static int _showCounter = 0;

  /// Show a banner sliding in from the top. Auto-dismisses after [duration].
  /// Tapping the banner runs [onTap] (default: dispatch the deep link via
  /// NotificationService.handleDeepLink). Subsequent calls replace the
  /// existing banner without flicker.
  static void show(
    BuildContext context, {
    required String title,
    required String body,
    String? payload,
    Duration duration = const Duration(seconds: 5),
  }) {
    // Resolve the overlay. Overlay.maybeOf(context) looks UP the widget
    // tree, so when called with the navigatorKey.currentContext (which
    // IS the Navigator's own BuildContext) the search misses — the
    // Navigator's Overlay is a descendant, not an ancestor. We try the
    // ancestor lookup first, then fall back to the rootNavigator's own
    // overlay state, which is what we actually want.
    OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    overlay ??= Navigator.maybeOf(context, rootNavigator: true)?.overlay;
    if (overlay == null) {
      debugPrint('InAppNotificationBanner: no overlay available — banner not shown');
      return;
    }

    _entry?.remove();
    _entry = null;

    final myCounter = ++_showCounter;
    final entry = OverlayEntry(
      builder: (ctx) => _BannerWidget(
        title: title,
        body: body,
        onTap: () {
          _dismiss();
          if (payload != null && payload.isNotEmpty) {
            NotificationService.instance.handleDeepLink(payload);
          }
        },
        onDismiss: _dismiss,
      ),
    );
    _entry = entry;
    overlay.insert(entry);

    Future.delayed(duration, () {
      // Only dismiss if no newer banner has replaced this one.
      if (_showCounter == myCounter) _dismiss();
    });
  }

  static void _dismiss() {
    _entry?.remove();
    _entry = null;
  }
}

class _BannerWidget extends StatefulWidget {
  const _BannerWidget({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 0),
              child: Material(
                color: Colors.transparent,
                child: Dismissible(
                  key: ValueKey('inAppBanner_${widget.title}_${widget.body.hashCode}'),
                  direction: DismissDirection.up,
                  onDismissed: (_) => widget.onDismiss(),
                  child: GestureDetector(
                    onTap: () async {
                      await _ctrl.reverse();
                      widget.onTap();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: AppColors.main.withValues(alpha: 0.10),
                            blurRadius: 14,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.main.withValues(alpha: 0.15),
                          width: 0.6,
                        ),
                      ),
                      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 36.w,
                            height: 36.w,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.main.withValues(alpha: 0.95),
                                  AppColors.main.withValues(alpha: 0.75),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.main.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.notifications_active_rounded,
                              color: Colors.white,
                              size: 18.sp,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    color: AppColors.mainDark,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  widget.body,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 11.sp,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Icon(
                            isRtl
                                ? Icons.chevron_left_rounded
                                : Icons.chevron_right_rounded,
                            color: Colors.grey.shade400,
                            size: 18.sp,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
