import 'package:bloc_test/bloc_test.dart';
import 'package:docsera/Business_Logic/Documents_page/notes/notes_cubit.dart';
import 'package:docsera/Business_Logic/Documents_page/notes/notes_service.dart';
import 'package:docsera/Business_Logic/Documents_page/notes/notes_state.dart';
import 'package:docsera/models/notes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNotesService extends Mock implements NotesService {}

void main() {
  late NotesCubit notesCubit;
  late MockNotesService mockService;

  setUp(() {
    registerFallbackValue(Note(
      id: 'fallback', 
      title: '', 
      content: [], 
      createdAt: DateTime.now(), 
      userId: ''
    ));
    mockService = MockNotesService();
    notesCubit = NotesCubit(service: mockService);
  });

  tearDown(() {
    notesCubit.close();
  });

  final mockNote = Note(
    id: 'note-1',
    title: 'Test Note',
    content: [{'insert': 'Hello'}],
    createdAt: DateTime.now(),
    userId: 'user-1',
  );

  group('NotesCubit', () {
    test('initial state is NotesLoading', () {
      expect(notesCubit.state, isA<NotesLoading>());
    });

    blocTest<NotesCubit, NotesState>(
      'fetchNotes emits [NotesLoaded] with notes',
      build: () {
        when(() => mockService.fetchNotes('user-1')).thenAnswer((_) async => [mockNote]);
        when(() => mockService.subscribeToNotes(any(), any())).thenReturn(null);
        return notesCubit;
      },
      act: (cubit) => cubit.listenToNotes(null, explicitUserId: 'user-1'),
      expect: () => [
        isA<NotesLoading>(), // Emit from listenToNotes
        isA<NotesLoaded>().having((s) => s.notes.length, 'length', 1),
      ],
    );

    blocTest<NotesCubit, NotesState>(
      'addNote calls service',
      build: () {
        when(() => mockService.addNote(any(), any(), any())).thenAnswer((_) async {});
        return notesCubit;
      },
      act: (cubit) => cubit.addNote(
        title: 'New Note', 
        content: [], 
        explicitUserId: 'user-1'
      ),
      verify: (_) {
        verify(() => mockService.addNote('New Note', [], 'user-1')).called(1);
      }
    );

    blocTest<NotesCubit, NotesState>(
      'deleteNote calls service',
      build: () {
        when(() => mockService.deleteNote(any(), any())).thenAnswer((_) async {});
        return notesCubit;
      },
      act: (cubit) => cubit.deleteNote(mockNote, explicitUserId: 'user-1'),
      verify: (_) {
        verify(() => mockService.deleteNote(mockNote.id!, 'user-1')).called(1);
      }
    );

    blocTest<NotesCubit, NotesState>(
      'updateNote calls service',
      build: () {
        when(() => mockService.updateNote(any(), any())).thenAnswer((_) async {});
        return notesCubit;
      },
      act: (cubit) => cubit.updateNote(mockNote, explicitUserId: 'user-1'),
      verify: (_) {
        verify(() => mockService.updateNote(mockNote, 'user-1')).called(1);
      }
    );
  });
}
