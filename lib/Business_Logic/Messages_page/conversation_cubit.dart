import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:docsera/services/supabase/supabase_conversation_service.dart';

import 'conversation_state.dart';

class ConversationCubit extends Cubit<ConversationState> {
  final ConversationService _service;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  StreamSubscription<Map<String, dynamic>>? _conversationSub;

  ConversationCubit(this._service) : super(const ConversationState());

  /// نستخدم هذا في صفحة المحادثة للوصول للـ service (لرفع الملفات)
  ConversationService get service => _service;

  /// 🟢 بدء الاستماع للمحادثة
  void start(String conversationId) {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    _sub?.cancel();
    _conversationSub?.cancel();

    // 1) STREAM الرسائل
    _sub = _service.watchMessages(conversationId).listen((messages) async {
      messages.sort((a, b) {
        final tsA = DateTime.tryParse((a['timestamp'] ?? '').toString());
        final tsB = DateTime.tryParse((b['timestamp'] ?? '').toString());
        if (tsA == null || tsB == null) return 0;
        return tsA.compareTo(tsB);
      });

      emit(state.copyWith(isLoading: false, messages: messages));

      await _service.markMessagesAsRead(
        conversationId: conversationId,
        messages: messages,
      );
    });

    // 2) STREAM حالة المحادثة
    _conversationSub = _service.watchConversation(conversationId).listen(
          (convo) {
        final isClosed = convo['is_closed'] == true;
        final isBlocked = convo['is_blocked'] == true;

        final hasDoctorResponded = convo['has_doctor_responded'] == true;
        final selectedReason = convo['selected_reason']?.toString();

        emit(state.copyWith(
          isConversationClosed: isClosed,
          isBlocked: isBlocked,
          hasDoctorResponded: hasDoctorResponded,
          selectedReason: selectedReason,
        ));
      },
    );
  }

  /// 🟢 إرسال رسالة (النص + المرفقات الجاهزة من الواجهة)
  Future<void> sendMessage({
    required String conversationId,
    required String senderName,
    required String text,
    required List<Map<String, dynamic>> attachments,
    bool isUser = true,
  }) async {
    try {
      await _service.sendMessage(
        conversationId: conversationId,
        senderName: senderName,
        text: text,
        attachments: attachments,
        isUser: isUser,
      );
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: e.toString(),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _conversationSub?.cancel();   // ← مهم جداً
    return super.close();
  }

}
