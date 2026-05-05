// Canonical model factories for tests.
//
// Every test that needs a model instance constructs it from here, never
// inline. If a model field is added/renamed, only this file changes —
// individual tests stay stable.
//
// All factories accept named overrides for the fields a test actually
// cares about; everything else gets a sensible default.

import 'package:docsera/models/appointment_details.dart';
import 'package:docsera/models/conversation.dart';
import 'package:docsera/models/document.dart';
import 'package:docsera/models/message.dart';
import 'package:docsera/models/notes.dart';

class Fixtures {
  Fixtures._();

  static final DateTime _now = DateTime.utc(2026, 5, 5, 12, 0, 0);

  static Message message({
    String id = 'msg-1',
    String senderId = 'patient-1',
    String text = 'hello',
    DateTime? timestamp,
    bool isSeen = false,
  }) {
    return Message(
      id: id,
      senderId: senderId,
      text: text,
      timestamp: timestamp ?? _now,
      isSeen: isSeen,
    );
  }

  static Map<String, dynamic> messageMap({
    String id = 'msg-1',
    String senderId = 'patient-1',
    String text = 'hello',
    String? timestamp,
    bool isSeen = false,
  }) {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp ?? _now.toIso8601String(),
      'isSeen': isSeen,
    };
  }

  static Conversation conversation({
    String id = 'conv-1',
    String patientId = 'patient-1',
    String doctorId = 'doctor-1',
    List<String>? participants,
    String lastMessage = 'hello',
    String lastSenderId = 'patient-1',
    DateTime? updatedAt,
    String? doctorName = 'Dr. Sample',
    String? doctorSpecialty = 'Cardiology',
    bool isClosed = false,
    int? unreadCountForUser = 0,
  }) {
    return Conversation(
      id: id,
      patientId: patientId,
      doctorId: doctorId,
      participants: participants ?? [patientId, doctorId],
      lastMessage: lastMessage,
      lastSenderId: lastSenderId,
      updatedAt: updatedAt ?? _now,
      doctorName: doctorName,
      doctorSpecialty: doctorSpecialty,
      isClosed: isClosed,
      messages: const [],
      unreadCountForUser: unreadCountForUser,
      unreadCountForDoctor: 0,
    );
  }

  static Map<String, dynamic> conversationMap({
    String patientId = 'patient-1',
    String doctorId = 'doctor-1',
    String lastMessage = 'hello',
    String lastSenderId = 'patient-1',
    bool isClosed = false,
    String? doctorName = 'Dr. Sample',
    String? doctorSpecialty = 'Cardiology',
  }) {
    return {
      'patient_id': patientId,
      'doctor_id': doctorId,
      'participants': [patientId, doctorId],
      'last_message': lastMessage,
      'last_sender_id': lastSenderId,
      'updated_at': _now.toIso8601String(),
      'doctor_name': doctorName,
      'doctor_specialty': doctorSpecialty,
      'is_closed': isClosed,
      'messages': [],
      'unread_count_for_user': 0,
      'unread_count_for_doctor': 0,
    };
  }

  static UserDocument document({
    String? id = 'doc-1',
    String userId = 'user-1',
    String name = 'Lab Result',
    String type = 'lab',
    String fileType = 'pdf',
    String patientId = 'patient-1',
    String previewUrl = 'https://example.com/preview.pdf',
    List<String>? pages,
    DateTime? uploadedAt,
    String uploadedById = 'user-1',
    bool encrypted = false,
    String source = 'patient',
    String bucket = 'documents',
    int fileSizeBytes = 1024,
  }) {
    return UserDocument(
      id: id,
      userId: userId,
      name: name,
      type: type,
      fileType: fileType,
      patientId: patientId,
      previewUrl: previewUrl,
      pages: pages ?? const ['page-1'],
      uploadedAt: uploadedAt ?? _now,
      uploadedById: uploadedById,
      encrypted: encrypted,
      source: source,
      bucket: bucket,
      fileSizeBytes: fileSizeBytes,
    );
  }

  static Map<String, dynamic> documentMap({
    String id = 'doc-1',
    String userId = 'user-1',
    String name = 'Lab Result',
    String type = 'lab',
    String fileType = 'pdf',
    bool encrypted = false,
    String source = 'patient',
    int fileSizeBytes = 1024,
  }) {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'type': type,
      'file_type': fileType,
      'patient_id': 'patient-1',
      'preview_url': 'https://example.com/preview.pdf',
      'pages': ['page-1'],
      'uploaded_at': _now.toIso8601String(),
      'uploaded_by_id': userId,
      'came_from_conversation': false,
      'encrypted': encrypted,
      'source': source,
      'bucket': 'documents',
      'file_size_bytes': fileSizeBytes,
    };
  }

  static Note note({
    String id = 'note-1',
    String title = 'Sample',
    List<dynamic>? content,
    DateTime? createdAt,
    String userId = 'user-1',
    String? relativeId,
  }) {
    return Note(
      id: id,
      title: title,
      content: content ?? const [{'insert': 'body\n'}],
      createdAt: createdAt ?? _now,
      userId: userId,
      relativeId: relativeId,
    );
  }

  static Map<String, dynamic> noteMap({
    String id = 'note-1',
    String title = 'Sample',
    String userId = 'user-1',
    String? relativeId,
  }) {
    return {
      'id': id,
      'title': title,
      'content': [{'insert': 'body\n'}],
      'created_at': _now.toIso8601String(),
      'user_id': userId,
      if (relativeId != null) 'relative_id': relativeId,
    };
  }

  static AppointmentDetails appointmentDetails({
    String doctorId = 'doctor-1',
    String doctorName = 'Dr. Sample',
    String specialty = 'Cardiology',
    String patientId = 'patient-1',
    String patientName = 'John Doe',
    int patientAge = 30,
    String reason = 'Consultation',
    String clinicName = 'Sample Clinic',
  }) {
    return AppointmentDetails(
      doctorId: doctorId,
      doctorName: doctorName,
      doctorGender: 'male',
      doctorTitle: 'Dr.',
      specialty: specialty,
      image: '',
      patientId: patientId,
      isRelative: false,
      patientName: patientName,
      patientGender: 'male',
      patientAge: patientAge,
      newPatient: false,
      reason: reason,
      clinicName: clinicName,
      clinicAddress: const {'street': '1 Main', 'city': 'Damascus'},
    );
  }
}
