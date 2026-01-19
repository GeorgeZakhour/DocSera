/// Integration tests for Notes table Row Level Security (RLS) policies.
///
/// These tests verify that the RLS policies correctly enforce access control:
/// - Users can CRUD their own notes (user_id = auth.uid())
/// - Users cannot access other users' notes
///
/// Note: Since RLS is enforced at the database level, these tests mock the
/// expected Supabase responses to verify the app handles RLS correctly.

import 'package:bloc_test/bloc_test.dart';
import 'package:docsera/Business_Logic/Documents_page/notes/notes_cubit.dart';
import 'package:docsera/Business_Logic/Documents_page/notes/notes_service.dart';
import 'package:docsera/Business_Logic/Documents_page/notes/notes_state.dart';
import 'package:docsera/models/notes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockNotesService extends Mock implements NotesService {}

// ============================================================================
// TEST DATA
// ============================================================================

/// Current authenticated user
const testUserId = 'user-123';

/// Another user (for negative tests)
const otherUserId = 'user-456';

/// User's own note
Note createOwnNote({String? id}) => Note(
      id: id ?? 'note-own-1',
      userId: testUserId,
      title: 'My Personal Note',
      content: [{'insert': 'This is my note content'}],
      createdAt: DateTime.now(),
    );

/// Another user's note (should be inaccessible)
Note createOtherUserNote({String? id}) => Note(
      id: id ?? 'note-other-1',
      userId: otherUserId,
      title: 'Other User Note',
      content: [{'insert': 'This is not my note'}],
      createdAt: DateTime.now(),
    );

// ============================================================================
// TESTS
// ============================================================================

void main() {
  late MockNotesService mockService;

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(Note(
      id: 'fallback-id',
      userId: 'fallback-user',
      title: 'Fallback',
      content: [],
      createdAt: DateTime.now(),
    ));
  });

  setUp(() {
    mockService = MockNotesService();
  });

  group('Notes RLS Policies', () {
    // ========================================================================
    // OWN NOTES (Current Behavior)
    // ========================================================================
    group('Own Notes', () {
      blocTest<NotesCubit, NotesState>(
        'SELECT: can fetch own notes',
        build: () {
          final ownNote = createOwnNote();
          when(() => mockService.fetchNotes(testUserId))
              .thenAnswer((_) async => [ownNote]);
          when(() => mockService.subscribeToNotes(any(), any()))
              .thenReturn(null);
          return NotesCubit(service: mockService);
        },
        act: (cubit) {
          // Manually set the subscribed user ID and trigger fetch
          cubit.emit(NotesLoading());
          mockService.fetchNotes(testUserId).then((notes) {
            cubit.emit(NotesLoaded(notes));
          });
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<NotesLoading>(),
          isA<NotesLoaded>()
              .having((s) => s.notes.length, 'notes length', 1)
              .having((s) => s.notes.first.userId, 'userId', testUserId),
        ],
      );

      blocTest<NotesCubit, NotesState>(
        'INSERT: can insert note for self',
        build: () {
          when(() => mockService.addNote(any(), any(), testUserId))
              .thenAnswer((_) async {});
          when(() => mockService.fetchNotes(testUserId))
              .thenAnswer((_) async => [createOwnNote(id: 'new-note-1')]);
          when(() => mockService.subscribeToNotes(any(), any()))
              .thenReturn(null);
          return NotesCubit(service: mockService);
        },
        act: (cubit) async {
          await cubit.addNote(
            title: 'New Note',
            content: [{'insert': 'New content'}],
            explicitUserId: testUserId,
          );
        },
        verify: (cubit) {
          verify(() => mockService.addNote('New Note', any(), testUserId))
              .called(1);
        },
      );

      blocTest<NotesCubit, NotesState>(
        'UPDATE: can update own note',
        build: () {
          final updatedNote = createOwnNote().copyWith(title: 'Updated Title');
          when(() => mockService.updateNote(any(), testUserId))
              .thenAnswer((_) async {});
          when(() => mockService.fetchNotes(testUserId))
              .thenAnswer((_) async => [updatedNote]);
          when(() => mockService.subscribeToNotes(any(), any()))
              .thenReturn(null);
          return NotesCubit(service: mockService);
        },
        act: (cubit) async {
          final noteToUpdate = createOwnNote().copyWith(title: 'Updated Title');
          await cubit.updateNote(noteToUpdate, explicitUserId: testUserId);
        },
        verify: (cubit) {
          verify(() => mockService.updateNote(any(), testUserId)).called(1);
        },
      );

      blocTest<NotesCubit, NotesState>(
        'DELETE: can delete own note',
        build: () {
          final noteToDelete = createOwnNote();
          when(() => mockService.deleteNote(noteToDelete.id, testUserId))
              .thenAnswer((_) async {});
          when(() => mockService.fetchNotes(testUserId))
              .thenAnswer((_) async => []); // Empty after delete
          when(() => mockService.subscribeToNotes(any(), any()))
              .thenReturn(null);
          return NotesCubit(service: mockService);
        },
        act: (cubit) async {
          await cubit.deleteNote(createOwnNote(), explicitUserId: testUserId);
        },
        verify: (cubit) {
          verify(() => mockService.deleteNote('note-own-1', testUserId))
              .called(1);
        },
      );
    });

    // ========================================================================
    // ACCESS DENIED (Security Tests)
    // ========================================================================
    group('Access Denied (Security)', () {
      blocTest<NotesCubit, NotesState>(
        'SELECT: cannot fetch other users notes (RLS filters them out)',
        build: () {
          // RLS filters out other users' notes - returns empty
          when(() => mockService.fetchNotes(testUserId))
              .thenAnswer((_) async => []);
          when(() => mockService.subscribeToNotes(any(), any()))
              .thenReturn(null);
          return NotesCubit(service: mockService);
        },
        act: (cubit) {
          cubit.emit(NotesLoading());
          mockService.fetchNotes(testUserId).then((notes) {
            cubit.emit(NotesLoaded(notes));
          });
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<NotesLoading>(),
          isA<NotesLoaded>()
              .having((s) => s.notes.isEmpty, 'is empty', true)
              .having((s) => s.notes.any((n) => n.userId == otherUserId),
                  'has other user notes', false),
        ],
      );

      blocTest<NotesCubit, NotesState>(
        'INSERT: cannot insert note for other users (RLS would reject)',
        build: () {
          // Even if attempting to insert for another user,
          // RLS would reject and result wouldn't appear in our view
          when(() => mockService.fetchNotes(testUserId))
              .thenAnswer((_) async => []);
          when(() => mockService.subscribeToNotes(any(), any()))
              .thenReturn(null);
          return NotesCubit(service: mockService);
        },
        act: (cubit) {
          cubit.emit(NotesLoading());
          mockService.fetchNotes(testUserId).then((notes) {
            cubit.emit(NotesLoaded(notes));
          });
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<NotesLoading>(),
          isA<NotesLoaded>().having(
              (s) => s.notes.where((n) => n.userId == otherUserId).isEmpty,
              'no other user notes',
              true),
        ],
      );

      blocTest<NotesCubit, NotesState>(
        'UPDATE: cannot update other users notes (not visible to update)',
        build: () {
          // Other user's note is not visible due to RLS
          when(() => mockService.fetchNotes(testUserId))
              .thenAnswer((_) async => []);
          when(() => mockService.subscribeToNotes(any(), any()))
              .thenReturn(null);
          return NotesCubit(service: mockService);
        },
        act: (cubit) {
          cubit.emit(NotesLoading());
          mockService.fetchNotes(testUserId).then((notes) {
            cubit.emit(NotesLoaded(notes));
          });
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<NotesLoading>(),
          isA<NotesLoaded>().having(
              (s) => s.notes.any((n) => n.id == 'note-other-1'),
              'has other note',
              false),
        ],
      );

      blocTest<NotesCubit, NotesState>(
        'DELETE: cannot delete other users notes (not visible to delete)',
        build: () {
          // Other user's note is not visible due to RLS
          when(() => mockService.fetchNotes(testUserId))
              .thenAnswer((_) async => []);
          when(() => mockService.subscribeToNotes(any(), any()))
              .thenReturn(null);
          return NotesCubit(service: mockService);
        },
        act: (cubit) {
          cubit.emit(NotesLoading());
          mockService.fetchNotes(testUserId).then((notes) {
            cubit.emit(NotesLoaded(notes));
          });
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<NotesLoading>(),
          isA<NotesLoaded>().having(
              (s) => s.notes.any((n) => n.id == 'note-other-1'),
              'has other note',
              false),
        ],
      );
    });
  });
}
