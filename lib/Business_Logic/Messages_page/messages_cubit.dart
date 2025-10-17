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

    print("👤 MessagesCubit - Current userId: $userId");

    _fetchConversations(userId);
    _startRealtimeListener(userId);
  }

  Future<String?> startConversation({
    required String patientId, // ممكن يكون ID المستخدم أو ID القريب
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
      final now = DateTime.now().toUtc();

      // ✅ الحصول على userId (صاحب الحساب الأساسي)
      final accountHolderId = _supabase.auth.currentUser?.id;
      if (accountHolderId == null) {
        throw Exception("❌ لا يوجد مستخدم مسجل حالياً.");
      }

// ✅ تحديد ما إذا كان هذا المريض الرئيسي أم أحد أقاربه
      final bool isRelative = accountHolderId != patientId;

// ✅ relativeId هو ID القريب الحقيقي إن وجد
      final String? relativeId = isRelative ? patientId : null;

// ✅ نتحقق إن كان هناك محادثة مفتوحة لنفس الطبيب ولنفس الحساب ولنفس القريب (أو null)
      final query = _supabase
          .from('conversations')
          .select()
          .eq('doctor_id', doctorId)
          .eq('patient_id', accountHolderId)
          .eq('is_closed', false);

      if (relativeId != null) {
        query.eq('relative_id', relativeId);
      } else {
        query.filter('relative_id', 'is', null);
      }

      final List existingList = await query.limit(1);

      Map<String, dynamic>? existing;

      if (existingList.isNotEmpty) {
        final item = existingList.first;
        final existingRel = item['relative_id'];
        // ⚡ تحقق يدوي: لو الـ relative_id لا يطابق الحالة الحالية، اعتبرها محادثة جديدة
        if ((relativeId == null && existingRel != null) ||
            (relativeId != null && existingRel != relativeId)) {
          existing = null;
        } else {
          existing = item;
        }
      } else {
        existing = null;
      }



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
          'last_sender_id': accountHolderId,
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

        return convoId;
      }

      // ✅ جلب بيانات الطبيب
      final doctor = await _supabase
          .from('doctors')
          .select('title, gender')
          .eq('id', doctorId)
          .maybeSingle();

      final doctorTitle = doctor?['title'] ?? '';
      final doctorGender = (doctor?['gender'] == 'Male') ? 'ذكر' : 'أنثى';

      // ✅ إنشاء محادثة جديدة
      final newConversation = {
        'doctor_id': doctorId,
        'patient_id': accountHolderId, // صاحب الحساب الأساسي دائمًا
        'relative_id': relativeId,            // ✅ فقط لو القريب موجود
        'participants': relativeId != null
            ? [accountHolderId, relativeId, doctorId]
            : [accountHolderId, doctorId],
        'last_message': message,
        'last_sender_id': accountHolderId,
        'updated_at': now.toIso8601String(),
        'doctor_name': doctorName,
        'doctor_specialty': doctorSpecialty,
        'doctor_image': doctorImage,
        'doctor_title': doctorTitle,
        'doctor_gender': doctorGender,
        'is_closed': false,
        'patient_name': patientName,
        'account_holder_name': accountHolderName,
        'selected_reason': selectedReason,
        'unread_count_for_doctor': 1,
        'source': isRelative ? 'relative' : 'user',
      };

      final convoInsert = await _supabase
          .from('conversations')
          .insert(newConversation)
          .select('id')
          .single();

      final convoId = convoInsert['id'] as String;

      // ✅ أول رسالة
      await _supabase.from('messages').insert({
        'conversation_id': convoId,
        'sender_name': patientName,
        'text': message,
        'is_user': true,
        'timestamp': now.toIso8601String(),
      });

      return convoId;
    } catch (e) {
      print("❌ Failed to start conversation: $e");
      emit(MessagesError("حدث خطأ أثناء إرسال الرسالة"));
      return null;
    }
  }



  void _fetchConversations(String userId) async {
    emit(MessagesLoading());

    try {
      // ✅ تحديد إذا المستخدم دكتور أو لا
      final isDoctor = await _supabase
          .from('doctors')
          .select('id')
          .eq('id', userId)
          .maybeSingle() != null;

      final query = isDoctor
          ? _supabase
          .from('conversations')
          .select('*, messages!messages_conversation_id_fkey(*)')
          .eq('doctor_id', userId)
          : _supabase
          .from('conversations')
          .select('*, messages!messages_conversation_id_fkey(*)')
          .contains('participants', [userId]);

      final response = await query.order('updated_at', ascending: false);

      final List<Conversation> conversations = [];

      for (final convo in response) {
        final base = Conversation.fromMap(convo['id'], convo);
        final unread = convo['unread_count_for_user'] ?? 0;

        final List messagesList = (convo['messages'] ?? [])..sort(
              (a, b) => DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])),
        );

        final messages = <Map<String, dynamic>>[];

        if (messagesList.isNotEmpty) {
          final latest = messagesList.first;

          messages.insert(0, {
            'id': latest['id'],
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
