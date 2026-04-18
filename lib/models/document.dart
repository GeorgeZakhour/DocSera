import 'package:docsera/utils/time_utils.dart';
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
  final bool encrypted; // ✅ Phase 2C: Whether file bytes are encrypted
  final String source; // 'patient', 'doctor_added', 'report'
  final String? sourceDoctorId;
  final String? sourceDoctorName;
  /// Storage bucket the file lives in.  Defaults to 'documents' (the patient
  /// vault bucket).  Report attachments synthesised from `reports.sections`
  /// live in `chat.attachments` and must set this explicitly so the preview
  /// resolver can sign URLs from the right bucket.
  final String bucket;

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
    this.encrypted = false,
    this.source = 'patient',
    this.sourceDoctorId,
    this.sourceDoctorName,
    this.bucket = 'documents',
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
      uploadedAt: DocSeraTime.tryParseToSyria(data['uploaded_at'].toString()) ?? DocSeraTime.nowSyria(),
      uploadedById: data['uploaded_by_id'] ?? '',
      cameFromConversation: data['came_from_conversation'] ?? false,
      conversationDoctorName: data['conversation_doctor_name'],
      encrypted: data['encrypted'] == true,
      source: data['source']?.toString() ?? 'patient',
      sourceDoctorId: data['source_doctor_id']?.toString(),
      sourceDoctorName: data['source_doctor_name']?.toString(),
      bucket: data['bucket']?.toString() ?? 'documents',
    );
  }

  /// ✅ Phase 2B: Check if a page URL is a storage path (not a full URL)
  bool isStoragePath(String page) {
    return !page.startsWith('http://') && !page.startsWith('https://');
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
      'uploaded_at': DocSeraTime.toUtc(uploadedAt).toIso8601String(),
      'uploaded_by_id': uploadedById,
      'came_from_conversation': cameFromConversation,
      if (conversationDoctorName != null)
        'conversation_doctor_name': conversationDoctorName,
      if (encrypted) 'encrypted': true,
      'source': source,
      if (sourceDoctorId != null) 'source_doctor_id': sourceDoctorId,
    };
  }

  UserDocument copyWith({
    String? name,
    String? type,
    String? previewUrl,
    List<String>? pages,
    bool? cameFromConversation,
    String? conversationDoctorName,
    bool? encrypted,
    String? source,
    String? sourceDoctorId,
    String? sourceDoctorName,
  }) {
    return UserDocument(
      id: id,
      userId: userId,
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
      encrypted: encrypted ?? this.encrypted,
      source: source ?? this.source,
      sourceDoctorId: sourceDoctorId ?? this.sourceDoctorId,
      sourceDoctorName: sourceDoctorName ?? this.sourceDoctorName,
    );
  }
}
