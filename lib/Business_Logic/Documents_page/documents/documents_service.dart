import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/models/document.dart';

class DocumentsService {
  final SupabaseClient _client;

  DocumentsService({SupabaseClient? client}) 
      : _client = client ?? Supabase.instance.client;

  Future<List<UserDocument>> fetchDocuments(String userId) async {
    final response = await _client
        .from('documents')
        .select()
        .eq('user_id', userId)
        .order('uploaded_at', ascending: false);

    return (response as List).map((e) => UserDocument.fromMap(e)).toList();
  }

  Future<void> deleteDocument(String documentId, String userId) async {
    await _client
        .from('documents')
        .delete()
        .eq('id', documentId)
        .eq('user_id', userId);
  }

  Future<void> deleteFiles(List<String> urls) async {
    for (final url in urls) {
      try {
        final path = Uri.parse(url).path.split('/storage/v1/object/public/documents/').last;
        await _client.storage.from('documents').remove([path]);
      } catch (e) {
        // Log error
      }
    }
  }

  RealtimeChannel? subscribeToDocuments(String userId, Function() onChange) {
    return _client
        .channel('public:documents')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'documents',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        onChange();
      },
    )
    .subscribe();
  }
}
