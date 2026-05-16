// Reauthored from test/_pending_rewrite/notes_cubit_DISABLED.dart.
//
// The original test called listenToNotes(null, explicitUserId: ...) — that
// signature no longer exists. listenToNotes now takes a BuildContext and
// reads the user from AuthCubit.state, which makes it unsuitable for
// pure-unit testing without a widget tree.
//
// What we DO unit-test here:
//   - initial state
//   - addNote / deleteNote / updateNote behavior (these still accept
//     explicitUserId, so they can run without a widget tree)
//   - error handling: no user, service throws
//
// listenToNotes is exercised in test/integration/, which builds a
// real widget tree with a mocked AuthCubit.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:docsera/Business_Logic/Documents_page/notes/notes_cubit.dart';
import 'package:docsera/Business_Logic/Documents_page/notes/notes_service.dart';
import 'package:docsera/Business_Logic/Documents_page/notes/notes_state.dart';

import '_helpers/fixtures.dart';
import '_helpers/tz_init.dart';

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

  group('NotesCubit', () {
    test('initial state is NotesInitial (no fetch until listenToNotes)', () {
      expect(cubit.state, isA<NotesInitial>());
    });

    blocTest<NotesCubit, NotesState>(
      'addNote with no user emits NotesError',
      build: () => cubit,
      act: (c) => c.addNote(title: 't', content: const []),
      expect: () => [isA<NotesError>()],
    );

    blocTest<NotesCubit, NotesState>(
      'addNote with explicitUserId delegates to service',
      build: () {
        when(() => service.addNote(any(), any(), any(),
            relativeId: any(named: 'relativeId'))).thenAnswer((_) async {});
        return cubit;
      },
      act: (c) =>
          c.addNote(title: 'New', content: const [], explicitUserId: 'user-1'),
      verify: (_) {
        verify(() => service.addNote('New', const [], 'user-1',
            relativeId: any(named: 'relativeId'))).called(1);
      },
    );

    blocTest<NotesCubit, NotesState>(
      'addNote service failure emits NotesError',
      build: () {
        when(() => service.addNote(any(), any(), any(),
                relativeId: any(named: 'relativeId')))
            .thenThrow(Exception('insert failed'));
        return cubit;
      },
      act: (c) =>
          c.addNote(title: 'New', content: const [], explicitUserId: 'user-1'),
      expect: () => [isA<NotesError>()],
    );

    blocTest<NotesCubit, NotesState>(
      'deleteNote with no user emits NotesError',
      build: () => cubit,
      act: (c) => c.deleteNote(Fixtures.note()),
      expect: () => [isA<NotesError>()],
    );

    blocTest<NotesCubit, NotesState>(
      'deleteNote service failure emits NotesError',
      build: () {
        when(() => service.deleteNote(any(), any()))
            .thenThrow(Exception('delete failed'));
        return cubit;
      },
      act: (c) => c.deleteNote(Fixtures.note(), explicitUserId: 'user-1'),
      expect: () => [isA<NotesError>()],
    );

    blocTest<NotesCubit, NotesState>(
      'updateNote service failure emits NotesError',
      build: () {
        when(() => service.updateNote(any(), any()))
            .thenThrow(Exception('update failed'));
        return cubit;
      },
      act: (c) => c.updateNote(Fixtures.note(), explicitUserId: 'user-1'),
      expect: () => [isA<NotesError>()],
    );
  });
}
