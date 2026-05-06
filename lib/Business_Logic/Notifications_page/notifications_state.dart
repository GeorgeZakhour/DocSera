import 'package:docsera/models/app_notification.dart';

abstract class NotificationsState {
  const NotificationsState();
}

class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

class NotificationsLoaded extends NotificationsState {
  final List<AppNotification> items;
  final int unreadCount;

  const NotificationsLoaded(this.items, this.unreadCount);
}

class NotificationsError extends NotificationsState {
  final String message;

  const NotificationsError(this.message);
}
