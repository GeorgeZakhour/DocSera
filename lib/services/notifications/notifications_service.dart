// Data layer for the patient notifications inbox.
//
// Reads from public.notifications (RLS-scoped to auth.uid()), subscribes
// to realtime INSERT/UPDATE events for live badge updates, and exposes
// the mark-read / archive / record-click RPCs.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/models/app_notification.dart';

class NotificationsService {
  NotificationsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Fetch the inbox for the current user.
  /// Returns the most-recent rows first, archived rows hidden.
  Future<List<AppNotification>> fetchInbox({int limit = 100}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .filter('archived_at', 'is', null)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((row) => AppNotification.fromMap(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Count of unread, unarchived notifications. Cheap because of the
  /// partial index on (user_id) WHERE read_at IS NULL AND archived_at IS NULL.
  Future<int> fetchUnreadCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final response = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .filter('read_at', 'is', null)
        .filter('archived_at', 'is', null);

    return (response as List).length;
  }

  /// Mark by filter — see rpc_mark_notifications_read for accepted shapes.
  ///   {"all": true}                          all unread
  ///   {"category": "messages"}               by category
  ///   {"event_code": "appointment.booked"}   by event
  ///   {"ids": [<uuid>, ...]}                 specific rows
  Future<int> markRead(Map<String, dynamic> filter) async {
    final response = await _client.rpc(
      'rpc_mark_notifications_read',
      params: {'p_filter': filter},
    );
    return (response as int?) ?? 0;
  }

  Future<int> markAllRead() => markRead({'all': true});

  Future<void> archive(String notificationId) async {
    await _client.rpc(
      'rpc_archive_notification',
      params: {'p_id': notificationId},
    );
  }

  /// Records a click event and stamps clicked_at + read_at if not already set.
  /// Called from the deep-link tap handler so the admin-panel analytics
  /// dashboard later has accurate engagement data.
  Future<void> recordClick(String notificationId) async {
    await _client.rpc(
      'rpc_record_notification_click',
      params: {'p_id': notificationId},
    );
  }

  /// Subscribe to inbox changes for the current user. The callback fires
  /// on INSERT (new notification arrived) and UPDATE (read/archived
  /// flipped from another device). One filter only — RLS already restricts
  /// rows to the calling user, but we filter explicitly for efficiency.
  RealtimeChannel? subscribe(void Function() onChange) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    return _client
        .channel('public:notifications:user:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }
}
