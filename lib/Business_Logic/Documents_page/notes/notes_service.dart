import 'package:docsera/models/notes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class NotesService {
  final SupabaseClient _client;

  NotesService({SupabaseClient? client}) 
      : _client = client ?? Supabase.instance.client;

  Future<List<Note>> fetchNotes(String userId) async {
    final response = await _client
        .from('notes')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((e) => Note.fromMap(e)).toList();
  }

  Future<void> addNote(String title, List<dynamic> content, String userId) async {
    final noteId = const Uuid().v4();
    final createdAt = DateTime.now();

    final noteData = {
      'id': noteId,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
    };

    await _client.from('notes').insert(noteData);
  }

  Future<void> deleteNote(String noteId, String userId) async {
    await _client
        .from('notes')
        .delete()
        .eq('id', noteId)
        .eq('user_id', userId);
  }

  Future<void> updateNote(Note updatedNote, String userId) async {
    await _client
        .from('notes')
        .update(updatedNote.toMap())
        .eq('id', updatedNote.id)
        .eq('user_id', userId);
  }

  RealtimeChannel? subscribeToNotes(String userId, Function() onChange) {
    return _client
        .channel('public:notes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notes',
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
