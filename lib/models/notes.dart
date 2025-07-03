class Note {
  final String id;
  final String title;
  final List<dynamic> content; // ✅ تعديل النوع
  final DateTime createdAt;
  final String userId;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.userId,
  });

  factory Note.fromMap(Map<String, dynamic> data) {
    return Note(
      id: data['id'].toString(),
      title: data['title'] ?? '',
      content: data['content'] ?? [],
      createdAt: DateTime.parse(data['created_at']),
      userId: data['user_id'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
    };
  }

  Note copyWith({
    String? title,
    List<dynamic>? content,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      userId: userId,
    );
  }
}
