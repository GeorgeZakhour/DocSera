import 'package:docsera/models/notes.dart';

abstract class NotesState {}

class NotesLoading extends NotesState {}

class NotesNotLogged extends NotesState {}

class NotesLoaded extends NotesState {
  final List<Note> notes;

  NotesLoaded(this.notes);
}

class NotesError extends NotesState {
  final String message;

  NotesError(this.message);
}
