import 'package:docsera/models/notes.dart';
import 'package:docsera/utils/time_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class NotesService {
  final SupabaseClient _client;

  NotesService({SupabaseClient? client}) 
      : _client = client ?? Supabase.instance.client;

  /// Fetch notes for a user OR a relative.
  /// When [relativeId] is provided, filter by relative_id.
  /// When null, fetch only notes with no relative_id (main user's own notes).
  Future<List<Note>> fetchNotes(String userId, {String? relativeId}) async {
    var query = _client
        .from('notes')
        .select()
        .eq('user_id', userId);

    if (relativeId != null) {
      query = query.eq('relative_id', relativeId);
    } else {
      query = query.isFilter('relative_id', null);
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List).map((e) => Note.fromMap(e)).toList();
  }

  Future<void> addNote(String title, List<dynamic> content, String userId, {String? relativeId}) async {
    final noteId = const Uuid().v4();
    final createdAt = DocSeraTime.nowUtc();

    final noteData = {
      'id': noteId,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
      if (relativeId != null) 'relative_id': relativeId,
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

  /// Subscribe to realtime note changes for the current patient context.
  /// Uses user_id filter — Supabase realtime only supports one filter,
  /// so we do client-side filtering for relative_id in the cubit.
  RealtimeChannel? subscribeToNotes(String userId, Function() onChange) {
    return _client
        .channel('public:notes:user_id:$userId')
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
