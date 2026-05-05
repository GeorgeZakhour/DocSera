// Reauthored from test/_pending_rewrite/documents_cubit_DISABLED.dart.
//
// The original test used outdated method signatures
// (fetchDocuments(userId), subscribeToDocuments(userId, onChange)).
// Both APIs now use named parameters.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:docsera/Business_Logic/Documents_page/documents/documents_cubit.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_service.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_state.dart';

import '_helpers/fixtures.dart';
import '_helpers/tz_init.dart';

class _MockDocumentsService extends Mock implements DocumentsService {}

void main() {
  setUpAll(initTzForTests);

  late DocumentsCubit cubit;
  late _MockDocumentsService service;

  setUp(() {
    service = _MockDocumentsService();
    cubit = DocumentsCubit(service: service);
  });

  tearDown(() => cubit.close());

  group('DocumentsCubit', () {
    test('initial state is DocumentsLoading', () {
      expect(cubit.state, isA<DocumentsLoading>());
    });

    blocTest<DocumentsCubit, DocumentsState>(
      'listenToDocuments with explicitUserId emits [Loading, Loaded]',
      build: () {
        when(() => service.subscribeToDocuments(
              userId: any(named: 'userId'),
              relativeId: any(named: 'relativeId'),
              onChange: any(named: 'onChange'),
            )).thenReturn(null);
        when(() => service.fetchDocuments(
              userId: any(named: 'userId'),
              relativeId: any(named: 'relativeId'),
            )).thenAnswer((_) async => [Fixtures.document()]);
        return cubit;
      },
      act: (c) => c.listenToDocuments(explicitUserId: 'user-1'),
      expect: () => [
        isA<DocumentsLoading>(),
        isA<DocumentsLoaded>().having(
          (s) => s.documents.length,
          'documents.length',
          1,
        ),
      ],
    );

    blocTest<DocumentsCubit, DocumentsState>(
      'listenToDocuments with no user is a no-op (no transitions)',
      build: () => cubit,
      act: (c) => c.listenToDocuments(),
      // No explicit user, no context, no relative — early return with
      // the initial Loading state untouched.
      expect: () => const <DocumentsState>[],
    );

    blocTest<DocumentsCubit, DocumentsState>(
      'deleteDocument with no user emits DocumentsError',
      build: () => cubit,
      act: (c) => c.deleteDocument(document: Fixtures.document()),
      expect: () => [isA<DocumentsError>()],
    );

    blocTest<DocumentsCubit, DocumentsState>(
      'deleteDocument with explicitUserId calls service then refetches',
      build: () {
        when(() => service.deleteDocument(any(), any()))
            .thenAnswer((_) async {});
        when(() => service.deleteFiles(any()))
            .thenAnswer((_) async {});
        when(() => service.subscribeToDocuments(
              userId: any(named: 'userId'),
              relativeId: any(named: 'relativeId'),
              onChange: any(named: 'onChange'),
            )).thenReturn(null);
        when(() => service.fetchDocuments(
              userId: any(named: 'userId'),
              relativeId: any(named: 'relativeId'),
            )).thenAnswer((_) async => const []);
        return cubit;
      },
      act: (c) => c.deleteDocument(
        document: Fixtures.document(id: 'doc-7'),
        explicitUserId: 'user-1',
      ),
      verify: (_) {
        verify(() => service.deleteDocument('doc-7', 'user-1')).called(1);
        verify(() => service.deleteFiles(['page-1'])).called(1);
        // After delete, deleteDocument calls listenToDocuments which
        // calls fetchDocuments — verify reload happened.
        verify(() => service.fetchDocuments(
              userId: any(named: 'userId'),
              relativeId: any(named: 'relativeId'),
            )).called(greaterThan(0));
      },
      expect: () => [
        isA<DocumentsLoading>(),
        isA<DocumentsLoaded>().having((s) => s.documents.isEmpty, 'empty', true),
      ],
    );
  });
}
