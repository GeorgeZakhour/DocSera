import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/Business_Logic/Authentication/auth_cubit.dart';
import 'package:docsera/Business_Logic/Authentication/auth_state.dart';
import 'package:docsera/models/notes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'notes_state.dart';

class NotesCubit extends Cubit<NotesState> {
  NotesCubit() : super(NotesLoading());

  StreamSubscription? _notesSubscription;

  void listenToNotes(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      emit(NotesNotLogged());
      return;
    }

    final userId = authState.user.uid;

    _notesSubscription?.cancel();
    emit(NotesLoading());

    _notesSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final notes = snapshot.docs.map((doc) => Note.fromFirestore(doc)).toList();
      print("📡 Stream Update Received: ${notes.length} notes");
      emit(NotesLoaded(notes));
    }, onError: (e) {
      emit(NotesError("Listen error: $e"));
    });
  }

  Future<void> addNote(String title, List<dynamic> content) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "User not authenticated";

      final userId = user.uid;
      final noteRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notes')
          .doc();

      final newNote = Note(
        id: noteRef.id,
        title: title,
        content: content,
        createdAt: DateTime.now(),
        userId: userId,
      );

      await noteRef.set(newNote.toMap());
    } catch (e) {
      emit(NotesError("Add failed: $e"));
    }
  }

  Future<void> deleteNote(Note note) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw "User not authenticated";

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notes')
          .doc(note.id)
          .delete();
    } catch (e) {
      emit(NotesError("Delete failed: $e"));
    }
  }

  Future<void> updateNote(Note updatedNote) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw "User not authenticated";

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notes')
          .doc(updatedNote.id)
          .update(updatedNote.toMap());
    } catch (e) {
      emit(NotesError("Update failed: $e"));
    }
  }


  @override
  Future<void> close() {
    _notesSubscription?.cancel();
    return super.close();
  }
}
