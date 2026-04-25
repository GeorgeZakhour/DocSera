import 'dart:async';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/models/notes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notes_service.dart';

import 'package:docsera/utils/error_handler.dart';
import 'notes_state.dart';

class NotesCubit extends Cubit<NotesState> {
  final NotesService _service;

  NotesCubit({NotesService? service})
      : _service = service ?? NotesService(),
        super(NotesInitial());
  // ... (previous code)

  RealtimeChannel? _notesRealtimeChannel;
  String? _subscribedUserId;
  String? _currentRelativeId;

  /// Honor the Health-page patient switcher.
  /// When a relative is selected, fetch notes scoped to that relative.
  /// When the main user is selected, fetch notes with no relative_id.
  void listenToNotes(
    BuildContext context, {
    bool forceReload = false,
    String? relativeId,
  }) {
    String? userId;
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      userId = authState.user.id;
    }

    if (userId == null) return;

    // Check if the context changed (different user or different relative)
    final contextChanged = _subscribedUserId != userId || _currentRelativeId != relativeId;

    if (!forceReload && !contextChanged && state is NotesLoaded) return;
    if (!forceReload && !contextChanged && _notesRealtimeChannel != null) return;

    _notesRealtimeChannel?.unsubscribe();
    _subscribedUserId = userId;
    _currentRelativeId = relativeId;

    emit(NotesLoading());

    _notesRealtimeChannel = _service.subscribeToNotes(userId, () {
      _fetchNotes(userId!, relativeId: relativeId);
    });

    _fetchNotes(userId, relativeId: relativeId);
  }

  void _fetchNotes(String userId, {String? relativeId}) async {
    try {
      final notes = await _service.fetchNotes(userId, relativeId: relativeId);
      emit(NotesLoaded(notes));
    } catch (e) {
      if (state is NotesLoaded) {
        debugPrint("Silent notes refresh failed: $e");
      } else {
        emit(NotesError(ErrorHandler.resolve(e, defaultMessage: "فشل تحميل الملاحظات")));
      }
    }
  }

  Future<void> addNote({required String title, required List<dynamic> content, BuildContext? context, String? explicitUserId}) async {
    try {
      final userId = explicitUserId ?? _subscribedUserId;
      if (userId == null || userId.isEmpty) {
        emit(NotesError("User not authenticated"));
        return;
      }
      await _service.addNote(title, content, userId, relativeId: _currentRelativeId);
    } catch (e) {
      emit(NotesError(ErrorHandler.resolve(e, defaultMessage: "فشل إضافة الملاحظة")));
    }
  }

  Future<void> deleteNote(Note note, {BuildContext? context, String? explicitUserId}) async {
    try {
      final userId = explicitUserId ?? _subscribedUserId;
      if (userId == null || userId.isEmpty) {
        emit(NotesError("User not authenticated"));
        return;
      }
      await _service.deleteNote(note.id!, userId);
      _fetchNotes(userId, relativeId: _currentRelativeId);
    } catch (e) {
      emit(NotesError(ErrorHandler.resolve(e, defaultMessage: "فشل حذف الملاحظة")));
    }
  }

  Future<void> updateNote(Note updatedNote, {BuildContext? context, String? explicitUserId}) async {
    try {
       final userId = explicitUserId ?? _subscribedUserId;
       if (userId == null || userId.isEmpty) {
         emit(NotesError("User not authenticated"));
         return;
       }
      await _service.updateNote(updatedNote, userId);
    } catch (e) {
      emit(NotesError(ErrorHandler.resolve(e, defaultMessage: "فشل تحديث الملاحظة")));
    }
  }

  @override
  Future<void> close() {
    _notesRealtimeChannel?.unsubscribe();
    return super.close();
  }
}
