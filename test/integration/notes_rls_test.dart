// NotesCubit RLS-contract integration test.
//
// Same scope-disclaimer as documents_rls_test.dart: this verifies the
// Flutter half — that the Cubit honors what NotesService returns.
// Server-side RLS enforcement is verified at migration time.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:docsera/Business_Logic/Documents_page/notes/notes_cubit.dart';
import 'package:docsera/Business_Logic/Documents_page/notes/notes_service.dart';
import 'package:docsera/Business_Logic/Documents_page/notes/notes_state.dart';
import 'package:docsera/models/notes.dart';

import '../_helpers/fixtures.dart';
import '../_helpers/tz_init.dart';

class _MockNotesService extends Mock implements NotesService {}

void main() {
  setUpAll(() {
    initTzForTests();
    registerFallbackValue(Fixtures.note());
  });

  late NotesCubit cubit;
  late _MockNotesService service;

  setUp(() {
    service = _MockNotesService();
    cubit = NotesCubit(service: service);
  });

  tearDown(() => cubit.close());

  group('NotesCubit + RLS contract', () {
    blocTest<NotesCubit, NotesState>(
      'addNote with one userId, then add succeeds for that user only',
      build: () {
        when(() => service.addNote(any(), any(), 'user-a',
            relativeId: any(named: 'relativeId'))).thenAnswer((_) async {});
        return cubit;
      },
      act: (c) => c.addNote(
        title: 'Allergies',
        content: const [{'insert': 'peanuts\n'}],
        explicitUserId: 'user-a',
      ),
      verify: (_) {
        verify(() => service.addNote('Allergies', any(), 'user-a',
            relativeId: any(named: 'relativeId'))).called(1);
      },
    );

    blocTest<NotesCubit, NotesState>(
      'deleteNote calls service with the user-scoped id',
      build: () {
        when(() => service.deleteNote('note-9', 'user-a'))
            .thenAnswer((_) async {});
        return cubit;
      },
      act: (c) => c.deleteNote(
        Fixtures.note(id: 'note-9'),
        explicitUserId: 'user-a',
      ),
      verify: (_) {
        verify(() => service.deleteNote('note-9', 'user-a')).called(1);
      },
    );

    blocTest<NotesCubit, NotesState>(
      'updateNote passes through the user id (RLS enforces ownership server-side)',
      build: () {
        when(() => service.updateNote(any<Note>(), 'user-a'))
            .thenAnswer((_) async {});
        return cubit;
      },
      act: (c) => c.updateNote(
        Fixtures.note(id: 'note-1', title: 'Edited'),
        explicitUserId: 'user-a',
      ),
      verify: (_) {
        verify(() => service.updateNote(any<Note>(), 'user-a')).called(1);
      },
    );

    blocTest<NotesCubit, NotesState>(
      'attempting to act without a user id emits NotesError',
      build: () => cubit,
      act: (c) => c.addNote(title: 't', content: const []),
      expect: () => [isA<NotesError>()],
    );
  });
}
