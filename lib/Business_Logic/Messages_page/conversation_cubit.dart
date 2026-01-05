import 'dart:async';

import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:docsera/services/supabase/supabase_conversation_service.dart';
import 'package:uuid/uuid.dart';
import 'package:docsera/utils/time_utils.dart';

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
    _sub = _service.watchMessages(conversationId).listen((rawList) async {
      // ✅ FIX: Deduplicate messages by ID to prevent "Ghost Duplicates"
      final uniqueMap = <String, Map<String, dynamic>>{};
      for (final msg in rawList) {
        final id = msg['id']?.toString();
        if (id != null) {
          uniqueMap[id] = msg;
        }
      }
      final messages = uniqueMap.values.toList();

      messages.sort((a, b) {
        final tsA = DateTime.tryParse((a['timestamp'] ?? '').toString());
        final tsB = DateTime.tryParse((b['timestamp'] ?? '').toString());
        if (tsA == null || tsB == null) return 0;
        return tsA.compareTo(tsB);
      });

      // ✅ NEW: Remove pending messages that have arrived in the stream
      final currentPending = List<Map<String, dynamic>>.from(state.pendingMessages);
      currentPending.removeWhere((pending) {
        final pendingId = pending['id'];
        return uniqueMap.containsKey(pendingId);
      });

      emit(state.copyWith(
          isLoading: false, 
          messages: messages,
          pendingMessages: currentPending,
      ));

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
    // 1. Generate Local ID
    final localId = const Uuid().v4();
    final now = DocSeraTime.nowUtc().toIso8601String();

    // 2. Create Optimistic Message
    final optimisticMessage = {
      'id': localId,
      'conversation_id': conversationId,
      'text': text,
      'is_user': isUser,
      'sender_name': senderName,
      'timestamp': now,
      'attachments': attachments,
      'is_pending': true,      // Flag for UI
      'status': 'sending',     // 'sending', 'failed'
    };

    // 3. Add to Pending State
    final updatedPending = List<Map<String, dynamic>>.from(state.pendingMessages)
      ..add(optimisticMessage);
    
    emit(state.copyWith(pendingMessages: updatedPending));

    try {
      // 4. Send to Server
      await _service.sendMessage(
        conversationId: conversationId,
        senderName: senderName,
        text: text,
        attachments: attachments,
        isUser: isUser,
        id: localId, // Pass ID to match stream later
      );
      // NOTE: We don't remove it here. The stream listener handles removal.
      
    } catch (e) {
      // 5. On Error: Mark as Failed
      final failedPending = state.pendingMessages.map((msg) {
        if (msg['id'] == localId) {
          return {...msg, 'status': 'failed'};
        }
        return msg;
      }).toList();

      emit(state.copyWith(
        pendingMessages: failedPending,
        errorMessage: e.toString(),
      ));
    }
  }

  /// 🟢 إرسال رسالة وسائط (صور/PDF) مع تحديث فوري (True Optimistic)
  Future<void> sendMediaMessage({
    required String conversationId,
    required String senderName,
    required String text,
    List<File> images = const [],
    File? pdf,
    bool isUser = true,
  }) async {
    // 1. Generate Local ID
    final localId = const Uuid().v4();
    final now = DocSeraTime.nowUtc().toIso8601String();

    // 2. Prepare Optimistic Attachments (Local)
    final List<Map<String, dynamic>> optimisticAttachments = [];

    // Images
    for (final file in images) {
      optimisticAttachments.add({
        'type': 'image',
        'localPath': file.path,
        'bucket': 'chat.attachments',
        'paths': [],
        'fileName': file.path.split('/').last,
      });
    }

    // PDF
    if (pdf != null) {
      optimisticAttachments.add({
        'type': 'pdf',
        'localPath': pdf.path,
        'bucket': 'chat.attachments',
        'paths': [],
        'fileName': pdf.path.split('/').last,
      });
    }

    // 3. Create Optimistic Message
    final optimisticMessage = {
      'id': localId,
      'conversation_id': conversationId,
      'text': text,
      'is_user': isUser,
      'sender_name': senderName,
      'timestamp': now,
      'attachments': optimisticAttachments,
      'is_pending': true,
      'status': 'sending',
    };

    // 4. Update UI Instantly
    final updatedPending = List<Map<String, dynamic>>.from(state.pendingMessages)
      ..add(optimisticMessage);
    emit(state.copyWith(pendingMessages: updatedPending));

    try {
      final List<Map<String, dynamic>> finalAttachments = [];

      // 5. Upload Background
      // Images
      for (final file in images) {
        final name = "${DocSeraTime.nowUtc().millisecondsSinceEpoch}_${file.path.split('/').last}";
        final uploaded = await _service.uploadAttachmentFile(
          conversationId: conversationId,
          file: file,
          type: 'image',
          storageName: name,
        );
        finalAttachments.add(uploaded);
      }

      // PDF
      if (pdf != null) {
        final name = "${DocSeraTime.nowUtc().millisecondsSinceEpoch}_${pdf.path.split('/').last}";
        final uploaded = await _service.uploadAttachmentFile(
          conversationId: conversationId,
          file: pdf,
          type: 'pdf',
          storageName: name,
        );
        finalAttachments.add(uploaded);
      }

      // 6. Send to Server
      await _service.sendMessage(
        conversationId: conversationId,
        senderName: senderName,
        text: text,
        attachments: finalAttachments,
        isUser: isUser,
        id: localId,
      );

    } catch (e) {
      // 7. On Failure
      final failedPending = state.pendingMessages.map((msg) {
        if (msg['id'] == localId) {
          return {...msg, 'status': 'failed'};
        }
        return msg;
      }).toList();

      emit(state.copyWith(
        pendingMessages: failedPending,
        errorMessage: e.toString(),
      ));
    }
  }

  /// 🔄 إعادة محاولة إرسال رسالة فشلت
  Future<void> retryMessage(Map<String, dynamic> failedMsg) async {
    final id = failedMsg['id'];
    if (id == null) return;

    // Set status back to 'sending'
    final retryingList = state.pendingMessages.map((msg) {
      if (msg['id'] == id) {
        return {...msg, 'status': 'sending'};
      }
      return msg;
    }).toList();
    
    emit(state.copyWith(pendingMessages: retryingList, errorMessage: null));

    try {
      // ✅ Handle Re-upload if attachments are local
      List<Map<String, dynamic>> finalAttachments = (failedMsg['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final needsUpload = finalAttachments.any((a) => a.containsKey('localPath'));

      if (needsUpload) {
        final newAttachments = <Map<String, dynamic>>[];
        for (final att in finalAttachments) {
          if (att.containsKey('localPath') && (att['paths'] == null || (att['paths'] as List).isEmpty)) {
             final file = File(att['localPath']);
             final name = "${DocSeraTime.nowUtc().millisecondsSinceEpoch}_${file.path.split('/').last}";
             final uploaded = await _service.uploadAttachmentFile(
               conversationId: failedMsg['conversation_id'],
               file: file,
               type: att['type'] ?? 'image',
               storageName: name,
             );
             newAttachments.add(uploaded);
          } else {
             newAttachments.add(att);
          }
        }
        finalAttachments = newAttachments;
      }

      await _service.sendMessage(
        conversationId: failedMsg['conversation_id'],
        senderName: failedMsg['sender_name'],
        text: failedMsg['text'] ?? '',
        attachments: finalAttachments,
        isUser: failedMsg['is_user'] ?? true,
        id: id,
      );
    } catch (e) {
       final failedAgain = state.pendingMessages.map((msg) {
        if (msg['id'] == id) {
          return {...msg, 'status': 'failed'};
        }
        return msg;
      }).toList();

      emit(state.copyWith(
        pendingMessages: failedAgain,
        errorMessage: e.toString(),
      ));
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _conversationSub?.cancel();   // ← مهم جداً
    return super.close();
  }

}
