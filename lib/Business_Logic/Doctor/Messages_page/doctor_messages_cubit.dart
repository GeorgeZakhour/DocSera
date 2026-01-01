// import 'dart:async';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import '../../../models/conversation.dart';
// import 'doctor_messages_state.dart';
//
// class DoctorMessagesCubit extends Cubit<DoctorMessagesState> {
//   final String doctorId;
//   final SupabaseClient _supabase = Supabase.instance.client;
//   RealtimeChannel? _realtimeChannel;
//
//   DoctorMessagesCubit({required this.doctorId}) : super(DoctorMessagesLoading());
//
//   void loadDoctorMessages() async {
//     emit(DoctorMessagesLoading());
//
//     try {
//       final response = await _supabase
//           .from('conversations')
//           .select('*, messages!messages_conversationId_fkey(*)')
//           .eq('doctorId', doctorId)
//           .order('updatedAt', ascending: false);
//
//       final List<Conversation> conversations = [];
//
//       for (final convo in response) {
//         final baseConvo = Conversation.fromMap(convo['id'], convo);
//         final unread = convo['unreadCountForDoctor'] ?? 0;
//
//         final List messagesList = convo['messages'] ?? [];
//         final messages = <Map<String, dynamic>>[];
//
//         if (messagesList.isNotEmpty) {
//           final latest = messagesList.first;
//           messages.add({
//             'text': latest['text'],
//             'timestamp': latest['timestamp'], // مباشرة دون tryParse
//             'senderId': latest['senderId'],
//             'readByDoctor': latest['readByDoctor'] ?? false,
//             'isUser': latest['isUser'] ?? false,
//           });
//         }
//
//         conversations.add(
//           baseConvo.copyWith(unreadCountForDoctor: unread, messages: messages),
//         );
//       }
//
//       emit(DoctorMessagesLoaded(conversations));
//     } catch (e) {
//       emit(DoctorMessagesError("فشل تحميل المحادثات: $e"));
//     }
//   }
//
//   void startRealtimeListener() {
//     _realtimeChannel?.unsubscribe();
//
//     _realtimeChannel = _supabase
//         .channel('public:messages')
//         .onPostgresChanges(
//       event: PostgresChangeEvent.insert,
//       schema: 'public',
//       table: 'messages',
//       callback: (payload) {
//         debugPrint("🔄 رسالة جديدة للطبيب");
//         loadDoctorMessages();
//       },
//     )
//         .subscribe();
//   }
//
//   @override
//   Future<void> close() {
//     _realtimeChannel?.unsubscribe();
//     return super.close();
//   }
// }


import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/conversation.dart';
import 'doctor_messages_state.dart';

class DoctorMessagesCubit extends Cubit<DoctorMessagesState> {
  final String doctorId;
  final SupabaseClient _supabase = Supabase.instance.client;
// RealtimeSubscription? _subscription;

  DoctorMessagesCubit({required this.doctorId}) : super(DoctorMessagesLoading()) {
    _initStream();
  }

  void _initStream() {
    emit(DoctorMessagesLoading());

    // _subscription?.remove();

    final stream = _supabase
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('doctor_id', doctorId)
        .order('updated_at', ascending: false)
        .limit(100)
        .map((data) async {
      final List<Conversation> convos = [];

      for (final row in data) {
        final unread = row['unreadCountForDoctor'] ?? 0;

        // جلب آخر رسالة من جدول الرسائل عبر subquery
        final latestMessages = await _supabase
            .from('messages')
            .select()
            .eq('conversation_id', row['id'])
            .order('timestamp', ascending: false)
            .limit(1);

        final messages = <Map<String, dynamic>>[];

        if (latestMessages.isNotEmpty) {
          final msg = latestMessages.first;
          messages.add({
            'text': msg['text'],
            'timestamp': DateTime.tryParse(msg['timestamp'] ?? ''),
            'senderId': msg['sender_id'],
            'readByDoctor': msg['read_by_doctor'] ?? false,
            'isUser': msg['is_user'] ?? false,
          });
        }

        convos.add(
          Conversation.fromMap(row['id'], row).copyWith(
            unreadCountForDoctor: unread,
            messages: messages,
          ),
        );
      }

      return convos;
    });

    stream.listen((eventFuture) async {
      try {
        final conversations = await eventFuture;
        emit(DoctorMessagesLoaded(conversations));
      } catch (e) {
        emit(DoctorMessagesError("خطأ أثناء تحميل المحادثات: $e"));
      }
    });
  }

  @override
  Future<void> close() {
    // _subscription?.remove();
    return super.close();
  }
}
