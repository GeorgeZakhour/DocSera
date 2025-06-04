import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final String patientId;
  final String doctorId;
  final List<String> participants;
  final String lastMessage;
  final String lastSenderId;
  final DateTime updatedAt;

  final String? doctorName;
  final String? doctorSpecialty;
  final String? doctorImage;
  final bool isClosed;

  final String? patientName;
  final String? accountHolderName;
  final String? selectedReason;

  final List<Map<String, dynamic>> messages;

  // ✅ الحقل الجديد
  final int? unreadCountForUser;
  final int? unreadCountForDoctor;


  Conversation({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.participants,
    required this.lastMessage,
    required this.lastSenderId,
    required this.updatedAt,
    this.doctorName,
    this.doctorSpecialty,
    this.doctorImage,
    this.isClosed = false,
    this.patientName,
    this.accountHolderName,
    this.selectedReason,
    this.messages = const [],
    this.unreadCountForUser,
    this.unreadCountForDoctor,
  });

  factory Conversation.fromMap(String id, Map<String, dynamic> data) {
    return Conversation(
      id: id,
      patientId: data['patientId'] ?? '',
      doctorId: data['doctorId'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastSenderId: data['lastSenderId'] ?? '',
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      doctorName: data['doctorName'],
      doctorSpecialty: data['doctorSpecialty'],
      doctorImage: data['doctorImage'],
      isClosed: data['isClosed'] ?? false,
      patientName: data['patientName'],
      accountHolderName: data['accountHolderName'],
      selectedReason: data['selectedReason'],
      unreadCountForUser: data['unreadCountForUser'],
      unreadCountForDoctor: data['unreadCountForDoctor'],
      messages: [],
    );
  }

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    return Conversation.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastSenderId': lastSenderId,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'doctorName': doctorName,
      'doctorSpecialty': doctorSpecialty,
      'doctorImage': doctorImage,
      'isClosed': isClosed,
      'patientName': patientName,
      'accountHolderName': accountHolderName,
      'selectedReason': selectedReason,
      'unreadCountForUser': unreadCountForUser,
      'unreadCountForDoctor': unreadCountForDoctor,
    };
  }

  Conversation copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    List<String>? participants,
    String? lastMessage,
    String? lastSenderId,
    DateTime? updatedAt,
    String? doctorName,
    String? doctorSpecialty,
    String? doctorImage,
    bool? isClosed,
    String? patientName,
    String? accountHolderName,
    String? selectedReason,
    List<Map<String, dynamic>>? messages,
    int? unreadCountForUser,
    int? unreadCountForDoctor,
  }) {
    return Conversation(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      updatedAt: updatedAt ?? this.updatedAt,
      doctorName: doctorName ?? this.doctorName,
      doctorSpecialty: doctorSpecialty ?? this.doctorSpecialty,
      doctorImage: doctorImage ?? this.doctorImage,
      isClosed: isClosed ?? this.isClosed,
      patientName: patientName ?? this.patientName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      selectedReason: selectedReason ?? this.selectedReason,
      messages: messages ?? this.messages,
      unreadCountForUser: unreadCountForUser ?? this.unreadCountForUser,
      unreadCountForDoctor: unreadCountForDoctor ?? this.unreadCountForDoctor,
    );
  }
}
