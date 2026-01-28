import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/models/document.dart';
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
  String? _loadedUserId;

  /// تحميل المحادثات
  void loadMessages(BuildContext context, {bool forceReload = false}) {
    final authState = context.read<AuthCubit>().state;

    if (authState is! AuthAuthenticated) {
      emit(MessagesNotLogged());
      return;
    }

    final userId = authState.user.id;

    // ✅ Secure Cache Check: Prevent redundant reloads unless user changed
    if (!forceReload && state is MessagesLoaded && _loadedUserId == userId) return;

    _loadedUserId = userId; // Update loaded user ID

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
          .or('participants.cs.{"$userId"},patient_id.eq.$userId'); // ✅ FIX: Check both participants and patient_id

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
    required String doctorTitle,
    required String doctorGender,
    required String accountHolderName,
    required String selectedReason,
    List<File>? initialFiles,
    UserDocument? initialDocument,
  }) async {
    try {
      final now = DocSeraTime.nowUtc();
      final accountHolderId = _supabase.auth.currentUser?.id;

      if (accountHolderId == null) throw Exception("لا يوجد بيانت للمستخدم الحالي.");

      final bool isRelative = accountHolderId != patientId;
      final String? relativeId = isRelative ? patientId : null;

      // --------------------------------------------------------------
      // 0) Prepare Attachments
      // --------------------------------------------------------------
      final List<Map<String, dynamic>> attachments = [];

      // A. Upload Local Files
      if (initialFiles != null && initialFiles.isNotEmpty) {
        for (final file in initialFiles) {
          final type = file.path.toLowerCase().endsWith('.pdf') ? 'pdf' : 'image';
          final name = "${now.millisecondsSinceEpoch}_${file.path.split('/').last}";
           // Temporary placeholder for conversationId in path. Will need to move/copy or upload with temp ID?
           // Actually we need conversationId for the path usually: '$conversationId/$storageName'
           // But we don't have conversationId yet for new convos!
           // We can use accountHolderId as prefix or just upload to a 'pending' or 'temp' folder?
           // OR: Create conversation first, then upload, then insert message.
           // -> Let's do that. We can insert conversation row first if needed.
           // However, if we reuse existing conversation, we have the ID.
        }
      }

      // --------------------------------------------------------------
      // 1) Find existing or Create Conversation
      // --------------------------------------------------------------
      // ✅ FIX: Use 'var' and assign the result for valid chaining
      var query = _supabase
          .from('conversations')
          .select()
          .eq('doctor_id', doctorId)
          .eq('patient_id', accountHolderId); 

      if (relativeId != null) {
        query = query.eq('relative_id', relativeId);
      } else {
        query = query.filter('relative_id', 'is', null);
      }

      final List existingList = await query.order('updated_at').limit(1);
      Map<String, dynamic>? existing;

      if (existingList.isNotEmpty) {
        existing = existingList.first;
      }
      
      String convoId;
      if (existing != null) {
        convoId = existing['id'] as String;
        // Re-open if closed
        if (existing['is_closed'] == true) {
          await _supabase.from('conversations').update({
            'is_closed': false,
            'has_doctor_responded': false,
          }).eq('id', convoId);
        }
      } else {
         // Create new
         final newConversation = {
          'doctor_id': doctorId,
          'patient_id': accountHolderId,
          'relative_id': relativeId,
          'participants': relativeId != null
              ? [accountHolderId, relativeId, doctorId]
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
          'doctor_title': doctorTitle,
          'doctor_gender': doctorGender,
        };

        final insert = await _supabase
            .from('conversations')
            .insert(newConversation)
            .select('id')
            .single();

        convoId = insert['id'];
      }

      // --------------------------------------------------------------
      // 2) Upload Attachments (Now that we have convoId)
      // --------------------------------------------------------------
      
      // A. Local Files
      if (initialFiles != null && initialFiles.isNotEmpty) {
        for (final file in initialFiles) {
             final ext = file.path.split('.').last.toLowerCase();
             final type = ext == 'pdf' ? 'pdf' : 'image';
             final fileName = "${now.millisecondsSinceEpoch}_${file.path.split('/').last}";
             final storagePath = '$convoId/$fileName';
             
             final bytes = await file.readAsBytes();
             await _supabase.storage.from('chat.attachments').uploadBinary(
               storagePath,
               bytes,
               fileOptions: const FileOptions(upsert: true, cacheControl: '3600'),
             );

             attachments.add({
               'type': type,
               'bucket': 'chat.attachments',
               'paths': [storagePath],
               'fileName': fileName,
               'fileUrl': null, 
             });
        }
      }

      // B. Existing UserDocument
      if (initialDocument != null) {
          // Use direct URL from the document
          // Assuming pages has at least one URL.
          if (initialDocument.pages.isNotEmpty) {
             attachments.add({
               'type': initialDocument.type, 
               'fileName': initialDocument.name,
               'fileUrl': initialDocument.pages.first, // Use the public/signed URL directly
               // bucket/paths can be omitted if fileUrl is used by service
               // But we can verify if it's a Supabase URL to be safe, but fileUrl logic handles generic URLs too.
             });
          }
      }

      // --------------------------------------------------------------
      // 3) Insert Message
      // --------------------------------------------------------------
      // Determine last message text for preview
      String lastMsgPreview = message;
      if (lastMsgPreview.isEmpty && attachments.isNotEmpty) {
          if (attachments.first['type'] == 'pdf') lastMsgPreview = '📄 PDF';
          else lastMsgPreview = '📷 Image';
      }

      await _supabase.from('messages').insert({
        'conversation_id': convoId,
        'sender_name': patientName,
        'text': message,
        'is_user': true,
        'timestamp': now.toIso8601String(),
        'read_by_user': true,
        if (attachments.isNotEmpty) 'attachments': attachments,
      });

      // Update Conversation Last Message
      await _supabase.from('conversations').update({
        'last_message': lastMsgPreview,
        'last_sender_id': accountHolderId,
        'updated_at': now.toIso8601String(),
      }).eq('id', convoId);

      return convoId;

    } catch (e) {
      emit(MessagesError(ErrorHandler.resolve(e, defaultMessage: "حدث خطأ أثناء بدء المحادثة")));
      return null;
    }
  }
}
