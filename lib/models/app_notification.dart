// One row from public.notifications. Read-only from the patient's
// perspective except for read_at / archived_at, which the client can
// flip via dedicated RPCs.

class AppNotification {
  final String id;
  final String userId;
  final String recipientApp;
  final String eventCode;
  final String category;
  final String? templateId;
  final String locale;
  final String title;
  final String body;
  final String? deepLink;
  final Map<String, dynamic> data;
  final String importance;
  final String? dedupKey;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? archivedAt;
  final DateTime? deliveredPushAt;
  final DateTime? clickedAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.recipientApp,
    required this.eventCode,
    required this.category,
    required this.templateId,
    required this.locale,
    required this.title,
    required this.body,
    required this.deepLink,
    required this.data,
    required this.importance,
    required this.dedupKey,
    required this.createdAt,
    required this.readAt,
    required this.archivedAt,
    required this.deliveredPushAt,
    required this.clickedAt,
  });

  bool get isUnread => readAt == null;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      recipientApp: (map['recipient_app'] as String?) ?? 'docsera',
      eventCode: (map['event_code'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'system',
      templateId: map['template_id'] as String?,
      locale: (map['locale'] as String?) ?? 'ar',
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      deepLink: map['deep_link'] as String?,
      data: _coerceMap(map['data']),
      importance: (map['importance'] as String?) ?? 'default',
      dedupKey: map['dedup_key'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
      readAt: _parseDate(map['read_at']),
      archivedAt: _parseDate(map['archived_at']),
      deliveredPushAt: _parseDate(map['delivered_push_at']),
      clickedAt: _parseDate(map['clicked_at']),
    );
  }

  AppNotification copyWith({
    DateTime? readAt,
    DateTime? archivedAt,
    DateTime? clickedAt,
  }) {
    return AppNotification(
      id: id,
      userId: userId,
      recipientApp: recipientApp,
      eventCode: eventCode,
      category: category,
      templateId: templateId,
      locale: locale,
      title: title,
      body: body,
      deepLink: deepLink,
      data: data,
      importance: importance,
      dedupKey: dedupKey,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      archivedAt: archivedAt ?? this.archivedAt,
      deliveredPushAt: deliveredPushAt,
      clickedAt: clickedAt ?? this.clickedAt,
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    return DateTime.parse(raw.toString()).toUtc();
  }

  static Map<String, dynamic> _coerceMap(Object? raw) {
    if (raw == null) return const {};
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
    return const {};
  }
}
