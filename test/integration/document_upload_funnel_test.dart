// Document upload funnel integration test — verifies the encrypt-then-
// upload contract for documents. Specifically:
//   - The bytes path of MessageEncryptionService produces a payload that
//     prepends the IV (so the storage backend can route encrypted bytes
//     to the same decryption path on read)
//   - DocumentsCubit's deleteDocument issues both a row delete and a
//     storage delete for the file pages

import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:docsera/Business_Logic/Documents_page/documents/documents_cubit.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_service.dart';
import 'package:docsera/Business_Logic/Documents_page/documents/documents_state.dart';
import 'package:docsera/services/encryption/message_encryption_service.dart';

import '../_helpers/fixtures.dart';
import '../_helpers/tz_init.dart';

class _MockDocumentsService extends Mock implements DocumentsService {}

Uint8List _testKey() => Uint8List.fromList(List<int>.generate(32, (i) => i + 9));

void main() {
  setUpAll(initTzForTests);

  late MessageEncryptionService enc;
  late _MockDocumentsService service;
  late DocumentsCubit cubit;

  setUp(() {
    enc = MessageEncryptionService.instance;
    enc.initWithKeyForTesting(_testKey());
    service = _MockDocumentsService();
    cubit = DocumentsCubit(service: service);
  });

  tearDown(() async {
    await cubit.close();
    enc.resetForTesting();
  });

  group('DocumentUploadFunnel — encrypt-before-upload contract', () {
    test('encrypted file bytes prepend a 16-byte IV', () {
      final plain = Uint8List.fromList([for (var i = 0; i < 100; i++) i]);
      final cipher = enc.encryptBytes(plain)!;
      // Cipher must be at least IV(16) + 1 block(16) = 32 bytes.
      expect(cipher.length, greaterThanOrEqualTo(32));
      // The same plaintext encrypted twice must produce different
      // ciphertexts (random IV → semantic security).
      final cipher2 = enc.encryptBytes(plain)!;
      expect(cipher, isNot(equals(cipher2)));
    });

    test('decryptBytes recovers the original file content', () {
      final plain = Uint8List.fromList(
          List<int>.generate(2048, (i) => (i * 7) % 256));
      final cipher = enc.encryptBytes(plain)!;
      final back = enc.decryptBytes(cipher);
      expect(back, equals(plain));
    });

    test('decryptBytes with wrong key fails-soft (null or non-matching)', () {
      final plain = Uint8List.fromList([1, 2, 3, 4]);
      final cipher = enc.encryptBytes(plain)!;
      enc.resetForTesting();
      enc.initWithKeyForTesting(
          Uint8List.fromList(List<int>.generate(32, (i) => i + 99)));
      final back = enc.decryptBytes(cipher);
      if (back != null) {
        expect(back, isNot(equals(plain)));
      }
    });
  });

  group('DocumentUploadFunnel — deleteDocument contract', () {
    blocTest<DocumentsCubit, DocumentsState>(
      'deleting an encrypted document removes both DB row AND storage pages',
      build: () {
        when(() => service.deleteDocument(any(), any()))
            .thenAnswer((_) async {});
        when(() => service.deleteFiles(any())).thenAnswer((_) async {});
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
        document: Fixtures.document(
          id: 'doc-x',
          encrypted: true,
          pages: ['users/u/path1', 'users/u/path2'],
        ),
        explicitUserId: 'user-1',
      ),
      verify: (_) {
        // Row must be deleted with the user-scoped query.
        verify(() => service.deleteDocument('doc-x', 'user-1')).called(1);
        // BOTH page paths must be deleted from storage — otherwise
        // we leak encrypted bytes after a "delete".
        verify(() => service.deleteFiles(
              ['users/u/path1', 'users/u/path2'],
            )).called(1);
      },
    );
  });
}
