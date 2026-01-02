import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/utils/time_utils.dart';

class ConversationService {
  final SupabaseClient _client;

  ConversationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // 1) STREAM الرسائل
  // ---------------------------------------------------------------------------

  /// 🔹 Stream لرسائل محادثة معيّنة (بدون أي JOIN)
  ///
  /// يعيد List<Map<String, dynamic>> بها نفس الحقول الموجودة في جدول messages:
  /// id, conversation_id, text, is_user, sender_name, timestamp,
  /// read_by_user, read_by_user_at, read_by_doctor, read_by_doctor_at, attachments
  Stream<List<Map<String, dynamic>>> watchMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('timestamp', ascending: true)
        .execute()
        .map((rows) {
      // تأكد أن النوع List<Map<String,dynamic>> ثابت
      return rows.map<Map<String, dynamic>>((row) {
        return Map<String, dynamic>.from(row);
      }).toList();
    });
  }

  Stream<Map<String, dynamic>> watchConversation(String conversationId) {
    return _client
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('id', conversationId)
        .limit(1)
        .execute()
        .map((rows) {
      if (rows.isEmpty) return {};
      return Map<String, dynamic>.from(rows.first);
    });
  }


  // ---------------------------------------------------------------------------
  // 2) تعليم رسائل الدكتور كمقروءة من جهة المريض
  // ---------------------------------------------------------------------------

  /// 🔹 يتم استدعاؤها من ConversationCubit بعد استلام الرسائل
  ///
  /// - تعلّم كل رسالة doctor→user غير مقروءة بـ read_by_user = true
  /// - تضبط read_by_user_at
  /// - تصفر unread_count_for_user في conversations
  Future<void> markMessagesAsRead({
    required String conversationId,
    required List<Map<String, dynamic>> messages,
  }) async {
    // رسائل كتبها الدكتور وغير مقروءة من المستخدم
    final unreadMessages = messages.where((msg) {
      final isDoctorMessage = msg['is_user'] == false;
      final notReadYet = msg['read_by_user'] != true;
      return isDoctorMessage && notReadYet && msg['id'] != null;
    }).toList();

    if (unreadMessages.isEmpty) {
      return;
    }

    final now = DocSeraTime.nowUtc().toIso8601String();

    // تحديث كل رسالة على حدة (آمن مع triggers)
    await Future.wait(
      unreadMessages.map((msg) async {
        final id = msg['id'];
        if (id == null) return;

        await _client
            .from('messages')
            .update({
          'read_by_user': true,
          'read_by_user_at': now,
        })
            .eq('id', id);
      }),
    );

    // تحديث المحادثة: تصفير عدد الرسائل غير المقروءة للمستخدم
    await _client
        .from('conversations')
        .update({
      'last_message_read_by_user': true,
      'unread_count_for_user': 0,
    })
        .eq('id', conversationId);
  }

  // ---------------------------------------------------------------------------
  // 3) إرسال رسالة نص + مرفقات (بعد رفع المرفقات في الواجهة)
  // ---------------------------------------------------------------------------

  /// 🔹 إرسال رسالة واحدة في محادثة معيّنة
  ///
  /// - text يمكن أن يكون فارغ إذا كانت رسالة مرفقات فقط
  /// - attachments هي قائمة JSON جاهزة (type, bucket, paths, fileName, fileUrl…)
  /// - isUser=true تعني أن المرسل هو المريض (تطبيق DocSera)
  // ---------------------------------------------------------------------------
  // 3) إرسال رسالة نص + مرفقات (بعد رفع المرفقات في الواجهة)
  // ---------------------------------------------------------------------------

  Future<void> sendMessage({
    required String conversationId,
    required String senderName,
    required String text,
    required List<Map<String, dynamic>> attachments,
    bool isUser = true,
  }) async {
    final now = DocSeraTime.nowUtc();

    // ----------------------------------------------------------
    // 1) فحص حالة المحادثة (مغلقة أو محظورة)
    // ----------------------------------------------------------
    final convo = await _client
        .from('conversations')
        .select('is_closed, is_blocked')
        .eq('id', conversationId)
        .maybeSingle();

    if (convo == null) {
      throw Exception("المحادثة غير موجودة.");
    }

    if (convo['is_closed'] == true) {
      throw Exception("لا يمكن إرسال رسائل — المحادثة مغلقة.");
    }

    if (convo['is_blocked'] == true) {
      throw Exception("لا يمكن إرسال رسائل — تم حظر التواصل في هذه المحادثة.");
    }

    // ----------------------------------------------------------
    // 2) إدخال الرسالة في جدول messages
    // ----------------------------------------------------------
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'text': text,
      'is_user': isUser,
      'sender_name': senderName,
      'timestamp': now.toIso8601String(),

      // قراءة الرسائل
      'read_by_doctor': false,
      'read_by_user': isUser,                      // المرسل يعتبر الرسالة مقروءة فوراً
      'read_by_doctor_at': null,
      'read_by_user_at': isUser ? now.toIso8601String() : null,

      if (attachments.isNotEmpty) 'attachments': attachments,
    });

    // ----------------------------------------------------------
    // 3) توليد معاينة آخر رسالة (تظهر في MessagesPage)
    // ----------------------------------------------------------
    final lastMessagePreview = text.isNotEmpty
        ? text
        : attachments.isEmpty
        ? ''
        : (attachments.first['type'] == 'pdf'
        ? '📄 PDF'
        : '🖼️ Image');

    // ----------------------------------------------------------
    // 4) تحديث المحادثة
    //
    // ⚠️ لا نعدل has_doctor_responded — لأن هذا وظيفة DocSera Pro
    // ----------------------------------------------------------
    await _client
        .from('conversations')
        .update({
      'last_message': lastMessagePreview,
      'last_sender_id': isUser ? 'user' : 'doctor',
      'updated_at': now.toIso8601String(),
      'last_message_read_by_user': isUser,
      'last_message_read_by_doctor': false,
    })
        .eq('id', conversationId);

    // ----------------------------------------------------------
    // 5) زيادة عداد الرسائل غير المقروءة للطبيب
    //
    // فقط إذا المرسل = المريض
    // ----------------------------------------------------------
    if (isUser) {
      try {
        await _client.rpc(
          'increment_unread_for_doctor',
          params: {'conversation_id': conversationId},
        );
      } catch (_) {
        // تجاهل أي خطأ (اختياري)
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 4) رفع ملف واحد إلى bucket chat.attachments
  // ---------------------------------------------------------------------------

  /// 🔹 يرفع ملف واحد (صورة أو PDF) إلى bucket `chat.attachments`
  ///
  /// - conversationId يستخدم كجزء من الـ path
  /// - storageName هو اسم الملف في التخزين (تقوم الواجهة بتكوينه)
  /// - يعيد Map جاهزة لتخزينها في حقل attachments في جدول messages
  Future<Map<String, dynamic>> uploadAttachmentFile({
    required String conversationId,
    required File file,
    required String type, // 'image' أو 'pdf'
    required String storageName,
  }) async {
    final storagePath = '$conversationId/$storageName';
    final bytes = await file.readAsBytes();

    await _client.storage
        .from('chat.attachments')
        .uploadBinary(
      storagePath,
      bytes,
      fileOptions: const FileOptions(
        upsert: true,
        cacheControl: '3600',
      ),
    );

    return {
      'type': type, // 'image' أو 'pdf'
      'bucket': 'chat.attachments',
      'paths': [storagePath],
      'fileName': storageName,
      'fileUrl': null, // مثل الـ schema المستخدم في DocSera Pro
    };
  }

  // ---------------------------------------------------------------------------
  // 5) Signed URL لمشاهدة الملفات
  // ---------------------------------------------------------------------------

  /// 🔹 الحصول على Signed URL من bucket + path
  ///
  /// يستخدم في `ChatAttachmentsService.resolveImageUrls`
  /// إذا فشل (مثلاً bucket public) يرجع publicUrl كـ fallback.
  Future<String> getSignedUrl({
    required String bucket,
    required String path,
    Duration duration = const Duration(days: 7),
  }) async {
    final storageRef = _client.storage.from(bucket);

    try {
      final signedUrl =
      await storageRef.createSignedUrl(path, duration.inSeconds);
      return signedUrl;
    } catch (_) {
      return storageRef.getPublicUrl(path);
    }
  }
}
