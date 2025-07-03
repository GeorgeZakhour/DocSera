import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/models/notes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'notes_state.dart';

class NotesCubit extends Cubit<NotesState> {
  NotesCubit() : super(NotesLoading());

  RealtimeChannel? _notesRealtimeChannel;

  void listenToNotes(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      emit(NotesNotLogged());
      return;
    }

    final userId = authState.user.id;

    _notesRealtimeChannel?.unsubscribe(); // ⛔️ إلغاء الاشتراك السابق إن وجد
    emit(NotesLoading());

    // ✅ الاشتراك في التحديثات من Supabase
    _notesRealtimeChannel = Supabase.instance.client
        .channel('public:notes')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notes',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (_) => _fetchNotes(userId),
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'notes',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (_) => _fetchNotes(userId),
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'notes',
      // لا تستخدم filter
      callback: (_) => _fetchNotes(userId),
    )

        .subscribe();

    _fetchNotes(userId); // ✅ تحميل أولي
  }

  void _fetchNotes(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('notes')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final notes = response.map((e) => Note.fromMap(e)).toList();
      emit(NotesLoaded(notes));
    } catch (e) {
      emit(NotesError("فشل تحميل الملاحظات: $e"));
    }
  }


  Future<void> addNote(String title, List<dynamic> content) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw "User not authenticated";

      final userId = user.id;
      final noteId = const Uuid().v4();
      final createdAt = DateTime.now();

      final noteData = {
        'id': noteId,
        'title': title,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'user_id': userId,
      };

      await Supabase.instance.client.from('notes').insert(noteData);
    } catch (e) {
      emit(NotesError("Add failed: $e"));
    }
  }

  Future<void> deleteNote(Note note) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw "User not authenticated";

      await Supabase.instance.client
          .from('notes')
          .delete()
          .eq('id', note.id)
          .eq('user_id', userId); // للتأكد من الملكية
    } catch (e) {
      emit(NotesError("Delete failed: $e"));
    }
  }

  Future<void> updateNote(Note updatedNote) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw "User not authenticated";

      await Supabase.instance.client
          .from('notes')
          .update(updatedNote.toMap())
          .eq('id', updatedNote.id)
          .eq('user_id', userId); // تأكيد الملكية
    } catch (e) {
      emit(NotesError("Update failed: $e"));
    }
  }

  @override
  Future<void> close() {
    _notesRealtimeChannel?.unsubscribe();
    return super.close();
  }
}
