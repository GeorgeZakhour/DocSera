import 'dart:async';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/models/notes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notes_service.dart';

import 'notes_state.dart';

class NotesCubit extends Cubit<NotesState> {
  final NotesService _service;

  NotesCubit({NotesService? service})
      : _service = service ?? NotesService(),
        super(NotesLoading());

  RealtimeChannel? _notesRealtimeChannel;

  void listenToNotes(BuildContext? context, {String? explicitUserId}) {
    String? userId;
    if (explicitUserId != null) {
      userId = explicitUserId;
    } else if (context != null) {
      final authState = context.read<AuthCubit>().state;
      if (authState is AuthAuthenticated) {
        userId = authState.user.id;
      }
    }

    if (userId == null) {
      emit(NotesNotLogged());
      return;
    }

    _notesRealtimeChannel?.unsubscribe(); // ⛔️ إلغاء الاشتراك السابق إن وجد
    emit(NotesLoading());

    // ✅ الاشتراك في التحديثات
    _notesRealtimeChannel = _service.subscribeToNotes(userId, () => _fetchNotes(userId!));

    _fetchNotes(userId); // ✅ تحميل أولي
  }

  void _fetchNotes(String userId) async {
    try {
      final notes = await _service.fetchNotes(userId);
      emit(NotesLoaded(notes));
    } catch (e) {
      emit(NotesError("فشل تحميل الملاحظات: $e"));
    }
  }

  Future<void> addNote({required String title, required List<dynamic> content, BuildContext? context, String? explicitUserId}) async {
    try {
      String? userId;
      if (explicitUserId != null) {
        userId = explicitUserId;
      } else if (context != null) {
        final authState = context.read<AuthCubit>().state;
        if (authState is AuthAuthenticated) {
          userId = authState.user.id;
        }
      } else {
        // Fallback for production if context is missing but typically shouldn't happen without explicitId
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) userId = user.id;
      }

      if (userId == null) throw "User not authenticated";

      await _service.addNote(title, content, userId);
    } catch (e) {
      emit(NotesError("Add failed: $e"));
    }
  }

  Future<void> deleteNote(Note note, {BuildContext? context, String? explicitUserId}) async {
    try {
      String? userId;
      if (explicitUserId != null) {
        userId = explicitUserId;
      } else if (context != null) {
        final authState = context.read<AuthCubit>().state;
        if (authState is AuthAuthenticated) {
          userId = authState.user.id;
        }
      } else {
         final user = Supabase.instance.client.auth.currentUser;
         if (user != null) userId = user.id;
      }

      if (userId == null) throw "User not authenticated";

      await _service.deleteNote(note.id!, userId);
    } catch (e) {
      emit(NotesError("Delete failed: $e"));
    }
  }

  Future<void> updateNote(Note updatedNote, {BuildContext? context, String? explicitUserId}) async {
    try {
      String? userId;
      if (explicitUserId != null) {
        userId = explicitUserId;
      } else if (context != null) {
        final authState = context.read<AuthCubit>().state;
        if (authState is AuthAuthenticated) {
            userId = authState.user.id;
        }
      } else {
         final user = Supabase.instance.client.auth.currentUser;
         if (user != null) userId = user.id;
      }

      if (userId == null) throw "User not authenticated";

      await _service.updateNote(updatedNote, userId);
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
