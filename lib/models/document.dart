class UserDocument {
  final String? id;
  final String userId;
  final String name;
  final String type;
  final String fileType;
  final String patientId;
  final String previewUrl;
  final List<String> pages;
  final DateTime uploadedAt;
  final String uploadedById;
  final bool cameFromConversation;
  final String? conversationDoctorName;

  UserDocument({
    this.id,
    required this.userId,
    required this.name,
    required this.type, 
    required this.fileType,
    required this.patientId,
    required this.previewUrl,
    required this.pages,
    required this.uploadedAt,
    required this.uploadedById,
    this.cameFromConversation = false,
    this.conversationDoctorName,
  });

  factory UserDocument.fromMap(Map<String, dynamic> data) {
    return UserDocument(
      id: data['id']?.toString(),
      userId: data['user_id'] ?? '',
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      fileType: data['file_type'] ?? '',
      patientId: data['patient_id'] ?? '',
      previewUrl: data['preview_url'] ?? '',
      pages: List<String>.from(data['pages'] ?? []),
      uploadedAt: DateTime.parse(data['uploaded_at']),
      uploadedById: data['uploaded_by_id'] ?? '',
      cameFromConversation: data['came_from_conversation'] ?? false,
      conversationDoctorName: data['conversation_doctor_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'type': type,
      'file_type': fileType,
      'patient_id': patientId,
      'preview_url': previewUrl,
      'pages': pages,
      'uploaded_at': uploadedAt.toIso8601String(),
      'uploaded_by_id': uploadedById,
      'came_from_conversation': cameFromConversation,
      if (conversationDoctorName != null)
        'conversation_doctor_name': conversationDoctorName,
    };
  }

  UserDocument copyWith({
    String? name,
    String? type,
    String? previewUrl,
    List<String>? pages,
    bool? cameFromConversation,
    String? conversationDoctorName,
  }) {
    return UserDocument(
      id: id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      fileType: fileType,
      patientId: patientId,
      previewUrl: previewUrl ?? this.previewUrl,
      pages: pages ?? this.pages,
      uploadedAt: uploadedAt,
      uploadedById: uploadedById,
      cameFromConversation: cameFromConversation ?? this.cameFromConversation,
      conversationDoctorName: conversationDoctorName ?? this.conversationDoctorName,
    );
  }
}
