import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'messages_state.dart';
import '../Authentication/auth_cubit.dart';
import '../Authentication/auth_state.dart';
import '../../models/conversation.dart';
import 'dart:convert';
import 'package:docsera/utils/error_handler.dart';
import 'package:docsera/utils/time_utils.dart';
class MessagesCubit extends Cubit<MessagesState> {
  final SupabaseClient _supabase;

  MessagesCubit({SupabaseClient? supabase}) 
      : _supabase = supabase ?? Supabase.instance.client,
        super(MessagesLoading());

  RealtimeChannel? _realtimeChannel;

  /// تحميل المحادثات
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

  // ---------------------------------------------------------------------------
  // 🔹 استخراج نص آخر رسالة (نص أو مرفق)
  // ---------------------------------------------------------------------------
  String _resolveLastMessage(Map<String, dynamic> msg) {
    final text = msg['text']?.toString().trim();

    // لو في نص نرجعه
    if (text != null && text.isNotEmpty) {
      return text;
    }

    // attachments قد تأتي JSON أو String أو null
    dynamic attachments = msg['attachments'];

    // إذا كانت String → حلّلها
    if (attachments is String) {
      try {
        attachments = jsonDecode(attachments);
      } catch (_) {
        return "📎 ملف مرفق";
      }
    }

    if (attachments is List && attachments.isNotEmpty) {
      final type = attachments.first['type'];

      if (type == 'image') return "📷 صورة";
      if (type == 'pdf') return "📄 ملف PDF";
      return "📎 ملف مرفق";
    }

    return "";
  }

  // ---------------------------------------------------------------------------
  // جلب جميع المحادثات
  // ---------------------------------------------------------------------------
  void _fetchConversations(String userId) async {
    emit(MessagesLoading());

    try {
      final isDoctor = await _supabase
          .from('doctors')
          .select('id')
          .eq('id', userId)
          .maybeSingle() !=
          null;

      final query = isDoctor
          ? _supabase
          .from('conversations')
          .select() // ✅ OPTIMIZED: No more nested relations
          .eq('doctor_id', userId)
          : _supabase
          .from('conversations')
          .select() // ✅ OPTIMIZED: No more nested relations
          .contains('participants', [userId]);

      final response =
      await query.order('updated_at', ascending: false).limit(20);

      final List<Conversation> conversations = [];

      for (final convo in response) {
        final base = Conversation.fromMap(convo['id'], convo);

        final unread = convo['unread_count_for_user'] ?? 0;

        // ------------------------------
        // ✅ OPTIMIZED: Use native columns directly
        // ------------------------------
        String lastMsgText = convo['last_message'] ?? "";
        
        // Construct a virtual "last message" object for UI compatibility
        final messages = <Map<String, dynamic>>[];
        if (lastMsgText.isNotEmpty) {
           messages.add({
             'text': lastMsgText,
      'timestamp': DocSeraTime.tryParseToSyria(convo['updated_at'] ?? ''),
             'isUser': convo['last_sender_id'] == userId, // Heuristic: we might need exact boolean if crucial
           });
        }

        conversations.add(
          base.copyWith(
            unreadCountForUser: unread,
            messages: messages, // UI uses this list to show preview
            lastMessage: lastMsgText, 
          ),
        );
      }

      emit(MessagesLoaded(conversations));
    } catch (e) {
      emit(MessagesError(ErrorHandler.resolve(e, defaultMessage: "فشل تحميل الرسائل")));
    }
  }

  // ---------------------------------------------------------------------------
  // 🔥 Real-time listener
  // ---------------------------------------------------------------------------
  void _startRealtimeListener(String userId) {
    _realtimeChannel?.unsubscribe();

    _realtimeChannel = _supabase
        .channel('public:conversations:$userId') // Unique channel per user
        .onPostgresChanges(
      event: PostgresChangeEvent.all, // Listen to INSERT (new chat) and UPDATE (new msg)
      schema: 'public',
      table: 'conversations',
      // We rely on RLS to filter events, which is the secure and correct way.
      callback: (payload) {
        _fetchConversations(userId);
      },
    ).subscribe();
  }

  // ---------------------------------------------------------------------------
  // إغلاق الكيوبت
  // ---------------------------------------------------------------------------
  @override
  Future<void> close() {
    _realtimeChannel?.unsubscribe();
    return super.close();
  }

  // ---------------------------------------------------------------------------
  // إنشاء محادثة جديدة (لا تغيير عليها الآن)
  // ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// إنشاء أو إعادة استخدام محادثة صحيحة
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// إنشاء أو إعادة استخدام محادثة (تشمل المحادثات المغلقة)
// ---------------------------------------------------------------------------
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
      final now = DocSeraTime.nowUtc();
      final accountHolderId = _supabase.auth.currentUser?.id;

      if (accountHolderId == null) throw Exception("لا يوجد مستخدم.");

      final bool isRelative = accountHolderId != patientId;
      final String? relativeId = isRelative ? patientId : null;

      // --------------------------------------------------------------
      // 1) البحث عن المحادثة سواء كانت مفتوحة أو مغلقة
      // --------------------------------------------------------------
      final query = _supabase
          .from('conversations')
          .select()
          .eq('doctor_id', doctorId)
          .eq('patient_id', patientId);

      if (isRelative) {
        query.eq('relative_id', patientId);
      } else {
        query.filter('relative_id', 'is', null);
      }

      final List existingList = await query.order('updated_at').limit(1);
      Map<String, dynamic>? existing;

      if (existingList.isNotEmpty) {
        existing = existingList.first;
      }

      // --------------------------------------------------------------
      // 2) إذا وجدنا محادثة (مغلقة أو مفتوحة) → نستخدمها ولا ننشئ واحدة جديدة
      // --------------------------------------------------------------
      if (existing != null) {
        final convoId = existing['id'] as String;

        // ⚠️ إذا كانت المحادثة مغلقة → افتحها من جديد
        if (existing['is_closed'] == true) {
          await _supabase.from('conversations').update({
            'is_closed': false,
            'has_doctor_responded': false,
          }).eq('id', convoId);
        }

        // أضف الرسالة الجديدة
        await _supabase.from('messages').insert({
          'conversation_id': convoId,
          'sender_name': patientName,
          'text': message,
          'is_user': true,
          'timestamp': now.toIso8601String(),
        });

        // تحديث آخر رسالة
        await _supabase.from('conversations').update({
          'last_message': message,
          'last_sender_id': accountHolderId,
          'updated_at': now.toIso8601String(),
        }).eq('id', convoId);

        return convoId;
      }

      // --------------------------------------------------------------
      // 3) لم نجد أي محادثة → إنشاء محادثة جديدة
      // --------------------------------------------------------------
      final newConversation = {
        'doctor_id': doctorId,
        'patient_id': patientId,
        'relative_id': isRelative ? patientId : null,
        'participants': isRelative
            ? [accountHolderId, patientId, doctorId]
            : [accountHolderId, doctorId],
        'last_message': message,
        'last_sender_id': accountHolderId,
        'updated_at': now.toIso8601String(),
        'doctor_name': doctorName,
        'doctor_specialty': doctorSpecialty,
        'doctor_image': doctorImage,
        'patient_name': patientName,
        'account_holder_name': accountHolderName,
        'selected_reason': selectedReason,
        'is_closed': false,
        'has_doctor_responded': false,
      };

      final insert = await _supabase
          .from('conversations')
          .insert(newConversation)
          .select('id')
          .single();

      final convoId = insert['id'];

      // إضافة الرسالة الأولى
      await _supabase.from('messages').insert({
        'conversation_id': convoId,
        'sender_name': patientName,
        'text': message,
        'is_user': true,
        'timestamp': now.toIso8601String(),
      });

      return convoId;

    } catch (e) {
      emit(MessagesError(ErrorHandler.resolve(e, defaultMessage: "حدث خطأ أثناء بدء المحادثة")));
      return null;
    }
  }
}
