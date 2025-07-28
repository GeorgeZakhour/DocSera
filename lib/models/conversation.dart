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
  final String? doctorGender; // ✅ جديد
  final String? doctorTitle;  // ✅ جديد
  final bool isClosed;

  final String? patientName;
  final String? accountHolderName;
  final String? selectedReason;

  final List<Map<String, dynamic>> messages;

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
    this.doctorGender,
    this.doctorTitle,
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
      patientId: data['patient_id'] ?? '',
      doctorId: data['doctor_id'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['last_message'] ?? '',
      lastSenderId: data['last_sender_id'] ?? '',
      updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
      doctorName: data['doctor_name'],
      doctorSpecialty: data['doctor_specialty'],
      doctorImage: data['doctor_image'],
      doctorGender: data['doctor_gender'], // ✅ جديد
      doctorTitle: data['doctor_title'],   // ✅ جديد
      isClosed: data['is_closed'] ?? false,
      patientName: data['patient_name'],
      accountHolderName: data['account_holder_name'],
      selectedReason: data['selected_reason'],
      unreadCountForUser: data['unread_count_for_user'],
      unreadCountForDoctor: data['unread_count_for_doctor'],
      messages: [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patient_id': patientId,
      'doctor_id': doctorId,
      'participants': participants,
      'last_message': lastMessage,
      'last_sender_id': lastSenderId,
      'updated_at': updatedAt.toIso8601String(),
      'doctor_name': doctorName,
      'doctor_specialty': doctorSpecialty,
      'doctor_image': doctorImage,
      'doctor_gender': doctorGender, // ✅ جديد
      'doctor_title': doctorTitle,   // ✅ جديد
      'is_closed': isClosed,
      'patient_name': patientName,
      'account_holder_name': accountHolderName,
      'selected_reason': selectedReason,
      'unread_count_for_user': unreadCountForUser,
      'unread_count_for_doctor': unreadCountForDoctor,
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
    String? doctorGender, // ✅ جديد
    String? doctorTitle,  // ✅ جديد
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
      doctorGender: doctorGender ?? this.doctorGender, // ✅ جديد
      doctorTitle: doctorTitle ?? this.doctorTitle,   // ✅ جديد
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
