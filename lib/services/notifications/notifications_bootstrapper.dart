import 'package:docsera/services/notifications/notification_service.dart';
import 'package:flutter/material.dart';

class NotificationsBootstrapper extends StatefulWidget {
  final Widget child;
  const NotificationsBootstrapper({super.key, required this.child});

  @override
  State<NotificationsBootstrapper> createState() => _NotificationsBootstrapperState();
}

class _NotificationsBootstrapperState extends State<NotificationsBootstrapper> {
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inited) {
      _inited = true;
      // استدعي خدمة الإشعارات مرة واحدة
      NotificationService.instance.init(context: context);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
