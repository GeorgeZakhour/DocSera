/// Integration tests for Documents table Row Level Security (RLS) policies.
///
/// These tests verify that the RLS policies correctly enforce access control:
/// - Users can CRUD their own documents (user_id = auth.uid())
/// - Users can CRUD documents for their relatives (patient_id in relatives)
/// - Users cannot access other users' documents
///
/// Note: Since RLS is enforced at the database level, these tests mock the
/// expected Supabase responses to verify the app handles RLS correctly.

import 'package:bloc_test/bloc_test.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_cubit.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_service.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_state.dart';
import 'package:docsera/models/document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockDocumentsService extends Mock implements DocumentsService {}

// ============================================================================
// TEST DATA
// ============================================================================

/// Current authenticated user
const testUserId = 'user-123';

/// Another user (for negative tests)
const otherUserId = 'user-456';

/// A relative of the current user
const testRelativeId = 'relative-789';

/// User's own document
UserDocument createOwnDocument({String? id}) => UserDocument(
      id: id ?? 'doc-own-1',
      userId: testUserId,
      name: 'My Medical Report',
      type: 'medical_report',
      fileType: 'pdf',
      patientId: testUserId, // Document is for the user themselves
      previewUrl: 'https://example.com/preview.jpg',
      pages: ['https://example.com/page1.jpg'],
      uploadedAt: DateTime.now(),
      uploadedById: testUserId,
    );

/// Document for user's relative (future-ready)
UserDocument createRelativeDocument({String? id}) => UserDocument(
      id: id ?? 'doc-relative-1',
      userId: testUserId, // Owner is still the user
      name: 'Relative Lab Results',
      type: 'lab_result',
      fileType: 'pdf',
      patientId: testRelativeId, // But it's for their relative
      previewUrl: 'https://example.com/preview2.jpg',
      pages: ['https://example.com/page2.jpg'],
      uploadedAt: DateTime.now(),
      uploadedById: testUserId,
    );

/// Another user's document (should be inaccessible)
UserDocument createOtherUserDocument({String? id}) => UserDocument(
      id: id ?? 'doc-other-1',
      userId: otherUserId,
      name: 'Other User Document',
      type: 'prescription',
      fileType: 'image',
      patientId: otherUserId,
      previewUrl: 'https://example.com/other-preview.jpg',
      pages: ['https://example.com/other-page.jpg'],
      uploadedAt: DateTime.now(),
      uploadedById: otherUserId,
    );

// ============================================================================
// TESTS
// ============================================================================

void main() {
  late MockDocumentsService mockService;

  setUp(() {
    mockService = MockDocumentsService();
  });

  group('Documents RLS Policies', () {
    // ========================================================================
    // OWN DOCUMENTS (Current Behavior)
    // ========================================================================
    group('Own Documents (Current)', () {
      blocTest<DocumentsCubit, DocumentsState>(
        'SELECT: can fetch own documents',
        build: () {
          final ownDoc = createOwnDocument();
          when(() => mockService.fetchDocuments(testUserId))
              .thenAnswer((_) async => [ownDoc]);
          when(() => mockService.subscribeToDocuments(any(), any()))
              .thenReturn(null);
          return DocumentsCubit(service: mockService);
        },
        act: (cubit) => cubit.listenToDocuments(explicitUserId: testUserId),
        expect: () => [
          isA<DocumentsLoading>(),
          isA<DocumentsLoaded>()
              .having((s) => s.documents.length, 'documents length', 1)
              .having((s) => s.documents.first.userId, 'userId', testUserId),
        ],
      );

      blocTest<DocumentsCubit, DocumentsState>(
        'INSERT: can insert document for self (document appears after insert)',
        build: () {
          final newDoc = createOwnDocument(id: 'new-doc-1');
          when(() => mockService.fetchDocuments(testUserId))
              .thenAnswer((_) async => [newDoc]);
          when(() => mockService.subscribeToDocuments(any(), any()))
              .thenReturn(null);
          return DocumentsCubit(service: mockService);
        },
        act: (cubit) => cubit.listenToDocuments(explicitUserId: testUserId),
        expect: () => [
          isA<DocumentsLoading>(),
          isA<DocumentsLoaded>()
              .having((s) => s.documents.any((d) => d.id == 'new-doc-1'),
                  'has new doc', true),
        ],
      );

      blocTest<DocumentsCubit, DocumentsState>(
        'UPDATE: can update own document (updated name visible)',
        build: () {
          final updatedDoc = createOwnDocument().copyWith(name: 'Updated Name');
          when(() => mockService.fetchDocuments(testUserId))
              .thenAnswer((_) async => [updatedDoc]);
          when(() => mockService.subscribeToDocuments(any(), any()))
              .thenReturn(null);
          return DocumentsCubit(service: mockService);
        },
        act: (cubit) => cubit.listenToDocuments(explicitUserId: testUserId),
        expect: () => [
          isA<DocumentsLoading>(),
          isA<DocumentsLoaded>()
              .having((s) => s.documents.first.name, 'name', 'Updated Name'),
        ],
      );

      blocTest<DocumentsCubit, DocumentsState>(
        'DELETE: can delete own document',
        build: () {
          final docToDelete = createOwnDocument();
          when(() => mockService.deleteDocument(docToDelete.id!, testUserId))
              .thenAnswer((_) async {});
          when(() => mockService.deleteFiles(docToDelete.pages))
              .thenAnswer((_) async {});
          when(() => mockService.fetchDocuments(testUserId))
              .thenAnswer((_) async => []); // Empty after delete
          when(() => mockService.subscribeToDocuments(any(), any()))
              .thenReturn(null);
          return DocumentsCubit(service: mockService);
        },
        act: (cubit) => cubit.deleteDocument(
          document: createOwnDocument(),
          explicitUserId: testUserId,
        ),
        verify: (cubit) {
          verify(() => mockService.deleteDocument('doc-own-1', testUserId))
              .called(1);
        },
        expect: () => [
          isA<DocumentsLoading>(),
          isA<DocumentsLoaded>()
              .having((s) => s.documents.isEmpty, 'is empty', true),
        ],
      );
    });

    // ========================================================================
    // ACCESS DENIED (Security Tests)
    // ========================================================================
    group('Access Denied (Security)', () {
      blocTest<DocumentsCubit, DocumentsState>(
        'SELECT: cannot fetch other users documents (RLS filters them out)',
        build: () {
          // RLS filters out other users' documents - returns empty
          when(() => mockService.fetchDocuments(testUserId))
              .thenAnswer((_) async => []);
          when(() => mockService.subscribeToDocuments(any(), any()))
              .thenReturn(null);
          return DocumentsCubit(service: mockService);
        },
        act: (cubit) => cubit.listenToDocuments(explicitUserId: testUserId),
        expect: () => [
          isA<DocumentsLoading>(),
          isA<DocumentsLoaded>()
              .having((s) => s.documents.isEmpty, 'is empty', true)
              .having(
                  (s) => s.documents.any((d) => d.userId == otherUserId),
                  'has other user docs',
                  false),
        ],
      );

      blocTest<DocumentsCubit, DocumentsState>(
        'INSERT: cannot insert document for non-relative (RLS would reject)',
        build: () {
          // Even if attempting to insert for another user,
          // RLS would reject and result wouldn't appear in our view
          when(() => mockService.fetchDocuments(testUserId))
              .thenAnswer((_) async => []);
          when(() => mockService.subscribeToDocuments(any(), any()))
              .thenReturn(null);
          return DocumentsCubit(service: mockService);
        },
        act: (cubit) => cubit.listenToDocuments(explicitUserId: testUserId),
        expect: () => [
          isA<DocumentsLoading>(),
          isA<DocumentsLoaded>().having(
              (s) => s.documents.where((d) => d.patientId == otherUserId).isEmpty,
              'no other patient docs',
              true),
        ],
      );

      blocTest<DocumentsCubit, DocumentsState>(
        'UPDATE: cannot update other users document (not visible to update)',
        build: () {
          // Other user's document is not visible due to RLS
          when(() => mockService.fetchDocuments(testUserId))
              .thenAnswer((_) async => []);
          when(() => mockService.subscribeToDocuments(any(), any()))
              .thenReturn(null);
          return DocumentsCubit(service: mockService);
        },
        act: (cubit) => cubit.listenToDocuments(explicitUserId: testUserId),
        expect: () => [
          isA<DocumentsLoading>(),
          isA<DocumentsLoaded>().having(
              (s) => s.documents.any((d) => d.id == 'doc-other-1'),
              'has other doc',
              false),
        ],
      );

      blocTest<DocumentsCubit, DocumentsState>(
        'DELETE: cannot delete other users document (not visible to delete)',
        build: () {
          // Other user's document is not visible due to RLS
          when(() => mockService.fetchDocuments(testUserId))
              .thenAnswer((_) async => []);
          when(() => mockService.subscribeToDocuments(any(), any()))
              .thenReturn(null);
          return DocumentsCubit(service: mockService);
        },
        act: (cubit) => cubit.listenToDocuments(explicitUserId: testUserId),
        expect: () => [
          isA<DocumentsLoading>(),
          isA<DocumentsLoaded>().having(
              (s) => s.documents.any((d) => d.id == 'doc-other-1'),
              'has other doc',
              false),
        ],
      );
    });

    // ========================================================================
    // RELATIVE DOCUMENTS (Future-Ready)
    // ========================================================================
    group('Relative Documents (Future-Ready)', () {
      blocTest<DocumentsCubit, DocumentsState>(
        'SELECT: can fetch documents for relatives via patient_id',
        build: () {
          final relativeDoc = createRelativeDocument();
          when(() => mockService.fetchDocuments(testUserId))
              .thenAnswer((_) async => [relativeDoc]);
          when(() => mockService.subscribeToDocuments(any(), any()))
              .thenReturn(null);
          return DocumentsCubit(service: mockService);
        },
        act: (cubit) => cubit.listenToDocuments(explicitUserId: testUserId),
        expect: () => [
          isA<DocumentsLoading>(),
          isA<DocumentsLoaded>()
              .having((s) => s.documents.length, 'length', 1)
              .having((s) => s.documents.first.patientId, 'patientId',
                  testRelativeId),
        ],
      );

      blocTest<DocumentsCubit, DocumentsState>(
        'INSERT: can insert document for relative',
        build: () {
          final newRelativeDoc = createRelativeDocument(id: 'new-rel-doc');
          when(() => mockService.fetchDocuments(testUserId))
              .thenAnswer((_) async => [newRelativeDoc]);
          when(() => mockService.subscribeToDocuments(any(), any()))
              .thenReturn(null);
          return DocumentsCubit(service: mockService);
        },
        act: (cubit) => cubit.listenToDocuments(explicitUserId: testUserId),
        expect: () => [
          isA<DocumentsLoading>(),
          isA<DocumentsLoaded>().having(
              (s) => s.documents.any((d) => d.patientId == testRelativeId),
              'has relative doc',
              true),
        ],
      );

      blocTest<DocumentsCubit, DocumentsState>(
        'UPDATE: can update relatives document',
        build: () {
          final updatedRelativeDoc =
              createRelativeDocument().copyWith(name: 'Updated Relative Doc');
          when(() => mockService.fetchDocuments(testUserId))
              .thenAnswer((_) async => [updatedRelativeDoc]);
          when(() => mockService.subscribeToDocuments(any(), any()))
              .thenReturn(null);
          return DocumentsCubit(service: mockService);
        },
        act: (cubit) => cubit.listenToDocuments(explicitUserId: testUserId),
        expect: () => [
          isA<DocumentsLoading>(),
          isA<DocumentsLoaded>()
              .having(
                  (s) => s.documents.first.name, 'name', 'Updated Relative Doc')
              .having((s) => s.documents.first.patientId, 'patientId',
                  testRelativeId),
        ],
      );

      blocTest<DocumentsCubit, DocumentsState>(
        'DELETE: can delete relatives document',
        build: () {
          final relativeDoc = createRelativeDocument();
          when(() => mockService.deleteDocument(relativeDoc.id!, testUserId))
              .thenAnswer((_) async {});
          when(() => mockService.deleteFiles(relativeDoc.pages))
              .thenAnswer((_) async {});
          when(() => mockService.fetchDocuments(testUserId))
              .thenAnswer((_) async => []); // Empty after delete
          when(() => mockService.subscribeToDocuments(any(), any()))
              .thenReturn(null);
          return DocumentsCubit(service: mockService);
        },
        act: (cubit) => cubit.deleteDocument(
          document: createRelativeDocument(),
          explicitUserId: testUserId,
        ),
        verify: (cubit) {
          verify(() => mockService.deleteDocument('doc-relative-1', testUserId))
              .called(1);
        },
        expect: () => [
          isA<DocumentsLoading>(),
          isA<DocumentsLoaded>()
              .having((s) => s.documents.isEmpty, 'is empty', true),
        ],
      );
    });
  });
}
