// Integration test: DocumentsCubit honors RLS-bounded service responses.
//
// IMPORTANT — what this test does and does NOT verify:
//   ✅ Verifies the Cubit correctly handles a service that returns only
//      the rows the current user is authorized to see (i.e. that the
//      app doesn't leak rows to UI when RLS quietly returns an empty
//      list, or when RLS returns only the user's own rows).
//   ❌ Does NOT verify the actual RLS policy in PostgreSQL — that
//      protection is enforced server-side and is outside Flutter's
//      reach. It is verified at migration time on the VPS and re-checked
//      manually as part of the security review (see
//      docs/launch/05-security-review.md).
//
// This split is deliberate: testing the actual RLS would require a
// throwaway test schema and live DB connection, which is brittle in CI.
// Mocking the service edge gives us reliable coverage of the *Flutter
// half* of the contract, which is where bugs in our hands live.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:docsera/Business_Logic/Documents_page/documents/documents_cubit.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_service.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_state.dart';

import '../_helpers/fixtures.dart';
import '../_helpers/tz_init.dart';

class _MockDocumentsService extends Mock implements DocumentsService {}

void main() {
  setUpAll(initTzForTests);

  late DocumentsCubit cubit;
  late _MockDocumentsService service;

  setUp(() {
    service = _MockDocumentsService();
    cubit = DocumentsCubit(service: service);

    // Default: subscribeToDocuments is a no-op for these tests.
    when(() => service.subscribeToDocuments(
          userId: any(named: 'userId'),
          relativeId: any(named: 'relativeId'),
          onChange: any(named: 'onChange'),
        )).thenReturn(null);
  });

  tearDown(() => cubit.close());

  group('DocumentsCubit + RLS contract', () {
    blocTest<DocumentsCubit, DocumentsState>(
      'when service returns only user-A rows, cubit exposes only user-A rows',
      build: () {
        when(() => service.fetchDocuments(
              userId: 'user-a',
              relativeId: any(named: 'relativeId'),
            )).thenAnswer((_) async => [
              Fixtures.document(id: 'doc-1', userId: 'user-a'),
              Fixtures.document(id: 'doc-2', userId: 'user-a'),
            ]);
        return cubit;
      },
      act: (c) => c.listenToDocuments(explicitUserId: 'user-a'),
      expect: () => [
        isA<DocumentsLoading>(),
        isA<DocumentsLoaded>().having(
          (s) => s.documents.every((d) => d.userId == 'user-a'),
          'every doc belongs to user-a',
          true,
        ),
      ],
    );

    blocTest<DocumentsCubit, DocumentsState>(
      'when RLS denies access (empty result), cubit shows empty Loaded state',
      build: () {
        // Simulating: user-b queries, but RLS denies → empty result.
        when(() => service.fetchDocuments(
              userId: 'user-b',
              relativeId: any(named: 'relativeId'),
            )).thenAnswer((_) async => const []);
        return cubit;
      },
      act: (c) => c.listenToDocuments(explicitUserId: 'user-b'),
      expect: () => [
        isA<DocumentsLoading>(),
        isA<DocumentsLoaded>().having(
          (s) => s.documents.isEmpty,
          'documents.isEmpty',
          true,
        ),
      ],
    );

    blocTest<DocumentsCubit, DocumentsState>(
      'relative-scoped query passes relativeId through to service',
      build: () {
        when(() => service.fetchDocuments(
              userId: any(named: 'userId'),
              relativeId: 'relative-x',
            )).thenAnswer((_) async => [
              Fixtures.document(id: 'rel-doc-1', patientId: 'relative-x'),
            ]);
        return cubit;
      },
      act: (c) => c.listenToDocuments(
        explicitUserId: 'user-a',
        relativeId: 'relative-x',
      ),
      verify: (_) {
        verify(() => service.fetchDocuments(
              userId: any(named: 'userId'),
              relativeId: 'relative-x',
            )).called(greaterThan(0));
      },
      expect: () => [
        isA<DocumentsLoading>(),
        isA<DocumentsLoaded>(),
      ],
    );
  });
}
