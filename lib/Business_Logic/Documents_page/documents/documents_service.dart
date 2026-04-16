import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/models/document.dart';

class DocumentsService {
  final SupabaseClient _client;

  DocumentsService({SupabaseClient? client}) 
      : _client = client ?? Supabase.instance.client;

  Future<List<UserDocument>> fetchDocuments(String userId) async {
    final response = await _client
        .from('documents')
        .select('*, source_doctor:doctors!documents_source_doctor_id_fkey(first_name, last_name, title)')
        .eq('user_id', userId)
        .order('uploaded_at', ascending: false);

    return (response as List).map((e) {
      final map = Map<String, dynamic>.from(e);
      // Flatten joined doctor name
      final doctorData = map['source_doctor'];
      if (doctorData is Map) {
        final title = doctorData['title'] ?? '';
        final first = doctorData['first_name'] ?? '';
        final last = doctorData['last_name'] ?? '';
        map['source_doctor_name'] = '$title $first $last'.trim();
      }
      map.remove('source_doctor');
      return UserDocument.fromMap(map);
    }).toList();
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
