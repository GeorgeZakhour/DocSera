import 'package:equatable/equatable.dart';

class ConversationState extends Equatable {
  final bool isLoading;
  final List<Map<String, dynamic>> messages;
  final String? errorMessage;

  final bool isConversationClosed;
  final bool isBlocked;

  /// جديد: هل رد الطبيب على الطلب ولو مرة واحدة؟
  final bool hasDoctorResponded;

  /// جديد (مفيد لو حابب تستعمله لاحقاً في الـ UI)
  final String? selectedReason;

  const ConversationState({
    this.isLoading = false,
    this.messages = const [],
    this.errorMessage,
    this.isConversationClosed = false,
    this.isBlocked = false,
    this.hasDoctorResponded = false,
    this.selectedReason,
  });

  ConversationState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? messages,
    String? errorMessage,
    bool? isConversationClosed,
    bool? isBlocked,
    bool? hasDoctorResponded,
    String? selectedReason,
  }) {
    return ConversationState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      errorMessage: errorMessage ?? this.errorMessage,
      isConversationClosed: isConversationClosed ?? this.isConversationClosed,
      isBlocked: isBlocked ?? this.isBlocked,
      hasDoctorResponded: hasDoctorResponded ?? this.hasDoctorResponded,
      selectedReason: selectedReason ?? this.selectedReason,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    messages,
    errorMessage,
    isConversationClosed,
    isBlocked,
    hasDoctorResponded,
    selectedReason,
  ];
}
