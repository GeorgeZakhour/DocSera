import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'messages_state.dart';
import '../Authentication/auth_cubit.dart';
import '../Authentication/auth_state.dart';
import '../../models/conversation.dart';

class MessagesCubit extends Cubit<MessagesState> {
  MessagesCubit() : super(MessagesLoading());

  RealtimeChannel? _realtimeChannel;
  final SupabaseClient _supabase = Supabase.instance.client;


  /// ✅ تحميل المحادثات من Firestore باستخدام AuthCubit
  void loadMessages(BuildContext context) {
    final authState = context.read<AuthCubit>().state;

    if (authState is! AuthAuthenticated) {
      emit(MessagesNotLogged());
      return;
    }

    final userId = authState.user.id;
    _fetchConversations(userId);
    _startRealtimeListener(userId);
  }

  Future<String?> startConversation({
    required String patientId,
    required String doctorId,
    required String message,
    required String doctorName,
    required String doctorSpecialty,
    required String doctorImage,
    required String patientName,
    required String accountHolderName,
    required String selectedReason,
  }) async {
    try {
      final existing = await _supabase
          .from('conversations')
          .select()
          .eq('patient_id', patientId)
          .eq('doctor_id', doctorId)
          .maybeSingle();

      final now = DateTime.now().toUtc();

      if (existing != null) {
        final convoId = existing['id'] as String;

        await _supabase.from('messages').insert({
          'conversation_id': convoId,
          'sender_name': patientName,
          'text': message,
          'is_user': true,
          'timestamp': now.toIso8601String(),
        });

        await _supabase.from('conversations').update({
          'last_message': message,
          'last_sender_id': patientId,
          'updated_at': now.toIso8601String(),
          'doctor_name': doctorName,
          'doctor_specialty': doctorSpecialty,
          'doctor_image': doctorImage,
          'is_closed': false,
          'patient_name': patientName,
          'account_holder_name': accountHolderName,
          'selected_reason': selectedReason,
          'unread_count_for_doctor': (existing['unread_count_for_doctor'] ?? 0) + 1,
        }).eq('id', convoId);

        return convoId; // ✅ رجّع الـ id الموجود
      } else {
        final authState = Supabase.instance.client.auth.currentUser;
        final userId = authState?.id ?? patientId;

        final convoInsert = await _supabase.from('conversations').insert({
          'doctor_id': doctorId,
          'patient_id': patientId,
          'participants': [patientId, doctorId, userId],
          'last_message': message,
          'last_sender_id': patientId,
          'updated_at': now.toIso8601String(),
          'doctor_name': doctorName,
          'doctor_specialty': doctorSpecialty,
          'doctor_image': doctorImage,
          'is_closed': false,
          'patient_name': patientName,
          'account_holder_name': accountHolderName,
          'selected_reason': selectedReason,
          'unread_count_for_doctor': 1,
        }).select('id').single();

        final convoId = convoInsert['id'] as String;

        await _supabase.from('messages').insert({
          'conversation_id': convoId,
          'sender_name': patientName,
          'text': message,
          'is_user': true,
          'timestamp': now.toIso8601String(),
        });

        return convoId; // ✅ رجّع الـ id الجديد
      }
    } catch (e) {
      print("❌ Failed to start conversation: $e");
      emit(MessagesError("حدث خطأ أثناء إرسال الرسالة"));
      return null; // لو صار خطأ
    }
  }


  void _fetchConversations(String userId) async {
    emit(MessagesLoading());

    try {
      final response = await _supabase
          .from('conversations')
          .select('*, messages!messages_conversation_id_fkey(*)')
          .contains('participants', [userId])
          .order('updated_at', ascending: false);

      final List<Conversation> conversations = [];

      for (final convo in response) {
          final base = Conversation.fromMap(convo['id'], convo);
          final unread = convo['unread_count_for_user'] ?? 0;

          final List messagesList = (convo['messages'] ?? [])..sort(
                (a, b) => DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])),
          );

          // print("📬 الرسائل بعد الترتيب:");
          // for (var msg in messagesList) {
          //   print("↪️ ${msg['text']} @ ${msg['timestamp']}");
          // }

          final messages = <Map<String, dynamic>>[];

          if (messagesList.isNotEmpty) {
            final latest = messagesList.first;
            // print("↪️ $latest");

            messages.insert(0, {
              'id': latest['id'], // ✅ أضف هذا السطر
              'text': latest['text'] ?? (latest['file_url'] != null ? '📎 ملف مرفق' : ''),
              'timestamp': DateTime.tryParse(latest['timestamp'] ?? ''),
              'senderId': latest['sender_id'],
              'readByUser': latest['read_by_user'] ?? false,
              'isUser': latest['is_user'] ?? false,
            });

          }

          conversations.add(base.copyWith(
            unreadCountForUser: unread,
            messages: messages,
            lastMessage: messages.isNotEmpty
                ? (messages.first['text'].toString().isNotEmpty
                ? messages.first['text']
                : '📎 ملف مرفق')
                : (base.lastMessage ?? ''),
          ));
      }


      emit(MessagesLoaded(conversations));
    } catch (e) {
      emit(MessagesError("فشل تحميل الرسائل: $e"));
    }
  }

  /// ✅ الاستماع إلى جميع المحادثات الخاصة بالمستخدم الحالي
  void _startRealtimeListener(String userId) {
    _realtimeChannel?.unsubscribe();

    _realtimeChannel = _supabase
        .channel('public:messages')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        print("📩 رسالة جديدة للمستخدم");
        _fetchConversations(userId); // إعادة تحميل المحادثات وتصفية محليًا
      },
    )
        .subscribe();
  }


  @override
  Future<void> close() {
    _realtimeChannel?.unsubscribe();
    return super.close();
  }
}
