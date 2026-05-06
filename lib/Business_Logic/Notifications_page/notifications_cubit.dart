// Holds the in-app notifications inbox state for the patient app.
// Subscribes to Supabase realtime so the bell badge updates live when a
// new push arrives or another device marks something as read.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/models/app_notification.dart';
import 'package:docsera/services/notifications/notifications_service.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({NotificationsService? service})
      : _service = service ?? NotificationsService(),
        super(const NotificationsInitial());

  final NotificationsService _service;
  RealtimeChannel? _channel;

  /// Initial load + realtime subscribe. Idempotent — calling twice does
  /// not double-subscribe.
  Future<void> start() async {
    await refresh();
    _channel ??= _service.subscribe(_onRealtimeChange);
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

  void _onRealtimeChange() {
    // Coalesce by re-fetching — simpler and avoids divergence between the
    // local state and DB state if multiple events fire in rapid succession.
    refresh();
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
    emit(const NotificationsInitial());
  }

  @override
  Future<void> close() async {
    await _channel?.unsubscribe();
    _channel = null;
    return super.close();
  }
}
