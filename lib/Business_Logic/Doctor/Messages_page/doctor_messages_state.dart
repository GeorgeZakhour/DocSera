import '../../../models/conversation.dart';

abstract class DoctorMessagesState {}

class DoctorMessagesLoading extends DoctorMessagesState {}

class DoctorMessagesNotLogged extends DoctorMessagesState {}

class DoctorMessagesLoaded extends DoctorMessagesState {
  final List<Conversation> conversations;
  DoctorMessagesLoaded(this.conversations);
}

class DoctorMessagesError extends DoctorMessagesState {
  final String message;
  DoctorMessagesError(this.message);
}
