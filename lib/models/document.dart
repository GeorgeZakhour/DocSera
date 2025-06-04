import 'package:cloud_firestore/cloud_firestore.dart';

class UserDocument {
  final String id;
  final String name;
  final String type;
  final String fileType; // 'pdf' أو 'image'
  final String patientId;
  final String previewUrl;
  final List<String> pages;
  final DateTime uploadedAt;
  final String uploadedById;

  UserDocument({
    required this.id,
    required this.name,
    required this.type,
    required this.fileType,
    required this.patientId,
    required this.previewUrl,
    required this.pages,
    required this.uploadedAt,
    required this.uploadedById,
  });

  factory UserDocument.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserDocument.fromMap(doc.id, data);
  }

  factory UserDocument.fromMap(String id, Map<String, dynamic> data) {
    return UserDocument(
      id: id,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      fileType: data['fileType'] ?? '',
      patientId: data['patientId'] ?? '',
      previewUrl: data['previewUrl'] ?? '',
      pages: List<String>.from(data['pages'] ?? []),
      uploadedAt: (data['uploadedAt'] is Timestamp)
          ? (data['uploadedAt'] as Timestamp).toDate()
          : DateTime.parse(data['uploadedAt']),
      uploadedById: data['uploadedById'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'fileType': fileType,
      'patientId': patientId,
      'previewUrl': previewUrl,
      'pages': pages,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'uploadedById': uploadedById,
    };
  }

  UserDocument copyWith({
    String? name,
    String? type,
    String? previewUrl,
    List<String>? pages,
  }) {
    return UserDocument(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      fileType: fileType,
      patientId: patientId,
      previewUrl: previewUrl ?? this.previewUrl,
      pages: pages ?? this.pages,
      uploadedAt: uploadedAt,
      uploadedById: uploadedById,
    );
  }
}
