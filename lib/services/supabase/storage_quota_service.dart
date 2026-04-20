import 'package:supabase_flutter/supabase_flutter.dart';

/// Result from `check_upload_allowed` RPC (called with fileSize=0 for usage-only).
class StorageQuotaResult {
  final bool allowed;
  final int usedBytes;
  final int maxBytes;
  final double usedPercentage;
  final int remainingBytes;
  final int fileCount;
  final bool warning70Shown;
  final bool warning90Shown;

  const StorageQuotaResult({
    required this.allowed,
    required this.usedBytes,
    required this.maxBytes,
    required this.usedPercentage,
    required this.remainingBytes,
    required this.fileCount,
    required this.warning70Shown,
    required this.warning90Shown,
  });

  factory StorageQuotaResult.fromMap(Map<String, dynamic> map) {
    final used = (map['used_bytes'] as num?)?.toInt() ?? 0;
    final max = (map['max_bytes'] as num?)?.toInt() ?? 0;
    final remaining = (map['remaining_bytes'] as num?)?.toInt() ?? 0;
    final pct = max > 0 ? (used / max * 100.0) : 0.0;

    return StorageQuotaResult(
      allowed: map['allowed'] as bool? ?? false,
      usedBytes: used,
      maxBytes: max,
      usedPercentage: pct,
      remainingBytes: remaining,
      fileCount: (map['file_count'] as num?)?.toInt() ?? 0,
      warning70Shown: map['warning_70_shown'] as bool? ?? false,
      warning90Shown: map['warning_90_shown'] as bool? ?? false,
    );
  }

  String get usedFormatted => StorageQuotaService.formatBytes(usedBytes);
  String get maxFormatted => StorageQuotaService.formatBytes(maxBytes);
  String get remainingFormatted => StorageQuotaService.formatBytes(remainingBytes);

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    int unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final formatted = value == value.truncate()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$formatted ${units[unitIndex]}';
  }
}

/// Service that wraps all storage-quota-related Supabase RPC calls.
class StorageQuotaService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Checks whether a file of [fileSize] bytes can be uploaded.
  /// Pass `fileSize = 0` to retrieve current usage without testing a file.
  Future<StorageQuotaResult> checkUploadAllowed(int fileSize) async {
    final dynamic response = await _client
        .rpc('check_upload_allowed', params: {'p_file_size': fileSize});
    return StorageQuotaResult.fromMap(Map<String, dynamic>.from(response as Map));
  }

  /// Convenience wrapper — returns current storage usage without simulating an upload.
  Future<StorageQuotaResult> getStorageUsage() async {
    final dynamic response = await _client.rpc('get_storage_usage');
    return StorageQuotaResult.fromMap(Map<String, dynamic>.from(response as Map));
  }

  /// Marks a storage warning level as shown so it won't be re-shown.
  Future<void> markWarningShown(int warningLevel) async {
    await _client.rpc(
      'mark_warning_shown',
      params: {'p_warning_level': warningLevel},
    );
  }

  /// Returns a list of the patient's largest documents (for the cleanup screen).
  Future<List<Map<String, dynamic>>> getLargestDocuments() async {
    final response = await _client.rpc('get_largest_documents');
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Returns conversations that contain expiring media attachments.
  Future<List<Map<String, dynamic>>> getConversationsWithExpiringMedia() async {
    final response =
        await _client.rpc('get_conversations_with_expiring_media');
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Returns expiring media items for a specific conversation.
  Future<List<Map<String, dynamic>>> getExpiringMediaForConversation(
    String conversationId,
  ) async {
    final response = await _client.rpc(
      'get_expiring_media_for_conversation',
      params: {'p_conversation_id': conversationId},
    );
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Marks a chat media item as saved to the patient's vault.
  Future<void> markChatMediaSaved(String mediaId) async {
    await _client.rpc(
      'mark_chat_media_saved',
      params: {'p_media_id': mediaId},
    );
  }

  // Expose formatBytes statically for use in StorageQuotaResult getters.
  static String formatBytes(int bytes) => StorageQuotaResult.formatBytes(bytes);
}
