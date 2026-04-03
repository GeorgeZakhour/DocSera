import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/utils/time_utils.dart';
import 'package:docsera/services/encryption/message_encryption_service.dart';

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
        .asyncMap((rows) async {
      final enc = MessageEncryptionService.instance;
      await enc.ensureReady(); // ✅ Defensive: ensure key is loaded
      return rows.map<Map<String, dynamic>>((row) {
        final m = Map<String, dynamic>.from(row);
        // ✅ Decrypt message text (legacy plain text passes through)
        if (m['text'] != null && m['text'] is String) {
          m['text'] = enc.decryptText(m['text'] as String);
        }
        return m;
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
        .asyncMap((rows) async {
      if (rows.isEmpty) return <String, dynamic>{};
      final m = Map<String, dynamic>.from(rows.first);
      // ✅ Decrypt last_message preview
      final enc = MessageEncryptionService.instance;
      await enc.ensureReady(); // ✅ Defensive: ensure key is loaded
      if (m['last_message'] != null && m['last_message'] is String) {
        m['last_message'] = enc.decryptText(m['last_message'] as String);
      }
      return m;
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
    // Check if there are any unread messages from the doctor
    final hasUnread = messages.any((msg) => 
        msg['is_user'] == false && msg['read_by_user'] != true
    );

    if (!hasUnread) return;

    try {
      await _client.rpc('rpc_mark_messages_read', params: {
        'conversation_uuid': conversationId,
      });
    } catch (e) {
      debugPrint("❌ Error calling rpc_mark_messages_read: $e");
    }
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
    String? id, // ✅ NEW: Optional ID for optimistic updates
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
    // ✅ Encrypt message text before storing
    final enc = MessageEncryptionService.instance;
    final encryptedText = enc.encryptText(text);

    await _client.from('messages').insert({
      if (id != null) 'id': id, // ✅ Insert with pre-generated UUID
      'conversation_id': conversationId,
      'text': encryptedText,
      'is_user': isUser,
      'sender_name': senderName,
      'timestamp': now.toIso8601String(),

      // قراءة الرسائل
      'read_by_doctor': false,
      'read_by_user': isUser,
      'read_by_doctor_at': null,
      'read_by_user_at': isUser ? now.toIso8601String() : null,

      if (attachments.isNotEmpty) 'attachments': attachments,
    });

    // ----------------------------------------------------------
    // 3) توليد معاينة آخر رسالة (تظهر في MessagesPage)
    // ----------------------------------------------------------
    // ----------------------------------------------------------
    // 3) توليد معاينة آخر رسالة (تظهر في MessagesPage)
    // ----------------------------------------------------------
    String lastMessagePreview = '';
    
    if (text.isNotEmpty) {
      lastMessagePreview = text;
    } else if (attachments.isNotEmpty) {
      final type = attachments.first['type'] ?? attachments.first['file_type'];
      if (type == 'pdf') {
        lastMessagePreview = '📄 PDF';
      } else if (type == 'audio' || type == 'voice') {
        final durationSec = attachments.first['duration'];
        if (durationSec != null) {
          final m = (durationSec / 60).floor().toString().padLeft(2, '0');
          final s = (durationSec % 60).toString().padLeft(2, '0');
          lastMessagePreview = '🎤 Voice Note ($m:$s)';
        } else {
          lastMessagePreview = '🎤 Voice Note';
        }
      } else {
        lastMessagePreview = '🖼️ Image';
      }
    }

    // ----------------------------------------------------------
    // 4) تحديث المحادثة
    //
    // ⚠️ لا نعدل has_doctor_responded — لأن هذا وظيفة DocSera Pro
    // ----------------------------------------------------------
    // ✅ Encrypt last_message preview
    final encryptedPreview = lastMessagePreview.isNotEmpty
        ? enc.encryptText(lastMessagePreview)
        : '';

    await _client
        .from('conversations')
        .update({
      'last_message': encryptedPreview,
      'last_sender_id': isUser ? 'user' : 'doctor',
      'updated_at': now.toIso8601String(),
      'last_message_read_by_user': isUser,
      'last_message_read_by_doctor': false,
    })
        .eq('id', conversationId);

    // ----------------------------------------------------------
    // 5) عداد الرسائل يتم تحديثه تلقائياً بواسطة Database Trigger 
    // (fix_unread_trigger.sql)
    // ----------------------------------------------------------
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
    var bytes = await file.readAsBytes();

    // ✅ Phase 2C: Encrypt file bytes before upload
    bool isEncrypted = false;
    final enc = MessageEncryptionService.instance;
    if (enc.isReady) {
      final encrypted = enc.encryptBytes(Uint8List.fromList(bytes));
      if (encrypted != null) {
        bytes = encrypted;
        isEncrypted = true;
      }
    }

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
      'type': type,
      'bucket': 'chat.attachments',
      'paths': [storagePath],
      'fileName': storageName,
      'fileUrl': null,
      if (isEncrypted) 'encrypted': true,
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
    final signedUrl =
        await storageRef.createSignedUrl(path, duration.inSeconds);
    return signedUrl;
  }
}
