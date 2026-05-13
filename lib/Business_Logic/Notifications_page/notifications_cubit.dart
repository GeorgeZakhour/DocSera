// Holds the in-app notifications inbox state for the patient app.
// Subscribes to Supabase realtime so the bell badge updates live when a
// new push arrives or another device marks something as read.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/models/app_notification.dart';
import 'package:docsera/services/notifications/notification_service.dart';
import 'package:docsera/services/notifications/notifications_service.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({NotificationsService? service})
      : _service = service ?? NotificationsService(),
        super(const NotificationsInitial());

  final NotificationsService _service;
  RealtimeChannel? _channel;
  String? _subscribedUserId;

  /// Initial load + realtime subscribe. Idempotent for the same user.
  /// When the signed-in user changes (logout + new login without an app
  /// restart), the previous user's channel is torn down and a fresh
  /// channel is subscribed for the new user — otherwise the old
  /// `user_id=<previous>` filter would keep firing and the next user's
  /// inbox / banner pipeline would never refresh.
  Future<void> start() async {
    await refresh();
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      // No session — drop any leftover channel so the next login
      // starts clean. _service.subscribe returns null without a user
      // anyway, so there's nothing to subscribe right now.
      if (_channel != null) {
        await _channel?.unsubscribe();
        _channel = null;
        _subscribedUserId = null;
      }
      return;
    }
    if (_channel != null && _subscribedUserId == currentUserId) {
      // Already subscribed for this user — nothing to do.
      return;
    }
    // Either no channel yet, or the previous channel was bound to a
    // different user_id. Tear down and resubscribe.
    if (_channel != null) {
      await _channel?.unsubscribe();
      _channel = null;
    }
    _channel = _service.subscribe(_onRealtimeChange);
    _subscribedUserId = _channel != null ? currentUserId : null;
  }

  Future<void> refresh() async {
    if (state is! NotificationsLoaded) {
      emit(const NotificationsLoading());
    }
    try {
      final items = await _service.fetchInbox();
      final unread = items.where((n) => n.isUnread).length;
      emit(NotificationsLoaded(items, unread));
    } catch (e) {
      emit(NotificationsError('Failed to load notifications: $e'));
    }
  }

  void _onRealtimeChange(PostgresChangePayload payload) {
    // Refresh the inbox state regardless of event type — read/archived
    // flips from another device need to update too.
    refresh();
    // For freshly-INSERTED rows, also show the foreground in-app banner
    // (NotificationService.showInAppBannerNow no-ops on Android and when
    // the app is not foregrounded). This is the path that lets messages,
    // gifts, and every other server-pushed notification appear over the
    // app instead of being silently swallowed by Pushy in foreground.
    if (payload.eventType == PostgresChangeEvent.insert) {
      try {
        final row = AppNotification.fromMap(payload.newRecord);
        // Ignore stale events (e.g. realtime catch-up after reconnect):
        // only show if the row arrived in the last 15 seconds.
        final age = DateTime.now().difference(row.createdAt);
        if (age.inSeconds <= 15) {
          NotificationService.instance.showInAppBannerNow(
            title: row.title,
            body: row.body,
            payload: row.deepLink,
          );
        }
      } catch (_) {
        // Bad payload — skip silently; refresh() already handled state.
      }
    }
  }

  /// Optimistically mark a single row read, then sync server-side.
  Future<void> markOneRead(String id) async {
    final current = state;
    if (current is NotificationsLoaded) {
      final updated = current.items.map((n) {
        if (n.id == id && n.readAt == null) {
          return n.copyWith(readAt: DateTime.now().toUtc());
        }
        return n;
      }).toList();
      final unread = updated.where((n) => n.isUnread).length;
      emit(NotificationsLoaded(updated, unread));
    }
    try {
      await _service.markRead({'ids': [id]});
    } catch (_) {
      // Realtime will reconcile on next event; non-fatal.
    }
  }

  Future<void> markAllRead() async {
    final current = state;
    if (current is NotificationsLoaded) {
      final now = DateTime.now().toUtc();
      final updated = current.items
          .map((n) => n.readAt == null ? n.copyWith(readAt: now) : n)
          .toList();
      emit(NotificationsLoaded(updated, 0));
    }
    try {
      await _service.markAllRead();
    } catch (_) {/* realtime reconciles */}
  }

  /// Mark every notification matching `eventCode` as read. Used when the
  /// user navigates into a screen that's the natural "destination" for an
  /// event (e.g. opens the conversation list → mark every message.new
  /// notification read).
  Future<void> markEventRead(String eventCode) async {
    try {
      await _service.markRead({'event_code': eventCode});
    } catch (_) {/* realtime reconciles */}
  }

  /// Mark every notification in `category` as read. Used when the user
  /// navigates into a category-aligned screen (e.g. the appointments tab).
  Future<void> markCategoryRead(String category) async {
    try {
      await _service.markRead({'category': category});
    } catch (_) {/* realtime reconciles */}
  }

  Future<void> archive(String id) async {
    final current = state;
    if (current is NotificationsLoaded) {
      final updated = current.items.where((n) => n.id != id).toList();
      final unread = updated.where((n) => n.isUnread).length;
      emit(NotificationsLoaded(updated, unread));
    }
    try {
      await _service.archive(id);
    } catch (_) {/* realtime reconciles */}
  }

  /// Records click + read for analytics. Called from the deep-link tap
  /// handler before the navigation runs so the row is marked even if
  /// the navigation surface throws.
  Future<void> recordClick(String id) async {
    await markOneRead(id);
    try {
      await _service.recordClick(id);
    } catch (_) {/* non-fatal */}
  }

  /// Stop realtime when the user signs out so the channel doesn't leak
  /// into the next session.
  Future<void> stop() async {
    await _channel?.unsubscribe();
    _channel = null;
    _subscribedUserId = null;
    emit(const NotificationsInitial());
  }

  @override
  Future<void> close() async {
    await _channel?.unsubscribe();
    _channel = null;
    _subscribedUserId = null;
    return super.close();
  }
}
