// Messaging funnel — exercises the send/encrypt/store/decrypt journey
// through ConversationCubit with the encryption service injected with a
// test key. Verifies:
//   1. ConversationCubit sends through the service (transport)
//   2. Encrypted text round-trips through MessageEncryptionService
//   3. Tampered ciphertext does NOT decrypt to the original plaintext

import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:docsera/Business_Logic/Messages_page/conversation_cubit.dart';
import 'package:docsera/Business_Logic/Messages_page/conversation_state.dart';
import 'package:docsera/services/encryption/message_encryption_service.dart';
import 'package:docsera/services/supabase/supabase_conversation_service.dart';

import '../_helpers/tz_init.dart';

class _MockConvService extends Mock implements ConversationService {}

Uint8List _testKey() => Uint8List.fromList(List<int>.generate(32, (i) => i + 5));

void main() {
  setUpAll(initTzForTests);

  late MessageEncryptionService enc;
  late _MockConvService service;
  late ConversationCubit cubit;

  setUp(() {
    enc = MessageEncryptionService.instance;
    enc.initWithKeyForTesting(_testKey());
    service = _MockConvService();
    cubit = ConversationCubit(service);
  });

  tearDown(() async {
    await cubit.close();
    enc.resetForTesting();
  });

  group('MessagingFunnel — encrypted text round-trips', () {
    test('sender encrypts → recipient decrypts → matches original', () {
      const original = 'I have a fever and my chest hurts';
      final cipher = enc.encryptText(original);
      expect(cipher, startsWith('ENC:'));
      // Recipient decrypts with same key.
      expect(enc.decryptText(cipher), original);
    });

    test('Arabic message round-trips end-to-end', () {
      const original = 'لدي ألم في الصدر منذ يومين';
      final cipher = enc.encryptText(original);
      expect(enc.decryptText(cipher), original);
    });

    test('tampered ciphertext does not yield original plaintext', () {
      final cipher = enc.encryptText('confidential');
      // Flip a character in the base64 payload.
      final mid = cipher.length ~/ 2;
      final tampered =
          '${cipher.substring(0, mid)}X${cipher.substring(mid + 1)}';
      final decrypted = enc.decryptText(tampered);
      expect(decrypted, isNot(equals('confidential')));
    });
  });

  group('MessagingFunnel — transport via ConversationCubit', () {
    blocTest<ConversationCubit, ConversationState>(
      'sendMessage with encrypted ciphertext is delegated to the service',
      build: () {
        when(() => service.sendMessage(
              conversationId: any(named: 'conversationId'),
              senderName: any(named: 'senderName'),
              text: any(named: 'text'),
              attachments: any(named: 'attachments'),
              isUser: any(named: 'isUser'),
              id: any(named: 'id'),
            )).thenAnswer((_) async => 'remote-id');
        return cubit;
      },
      act: (c) async {
        const plain = 'patient message';
        final cipher = enc.encryptText(plain);
        await c.sendMessage(
          conversationId: 'conv-1',
          senderName: 'Patient',
          text: cipher,
          attachments: const [],
        );
      },
      verify: (_) {
        // Service must have been called with text starting with ENC:
        final captured = verify(() => service.sendMessage(
              conversationId: any(named: 'conversationId'),
              senderName: any(named: 'senderName'),
              text: captureAny(named: 'text'),
              attachments: any(named: 'attachments'),
              isUser: any(named: 'isUser'),
              id: any(named: 'id'),
            )).captured;
        expect(captured.first, startsWith('ENC:'));
      },
    );
  });
}
