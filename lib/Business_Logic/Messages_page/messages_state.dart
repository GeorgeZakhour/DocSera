import 'package:equatable/equatable.dart';
import '../../models/conversation.dart';

/// ✅ **Base class for all messages states**
abstract class MessagesState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// 🔄 **Loading messages**
class MessagesLoading extends MessagesState {}

/// ✅ **User is NOT logged in**
class MessagesNotLogged extends MessagesState {}

/// ✅ **Messages loaded successfully**
class MessagesLoaded extends MessagesState {
  final List<Conversation> conversations;

  MessagesLoaded(this.conversations);

  int get unreadConversationsCount =>
      conversations.where((c) => (c.unreadCountForUser ?? 0) > 0).length;

  @override
  List<Object?> get props => [conversations];
}


/// ⚠️ **Error loading Messages**
class MessagesError extends MessagesState {
  final String message;

  MessagesError(this.message);

  @override
  List<Object?> get props => [message];
}
