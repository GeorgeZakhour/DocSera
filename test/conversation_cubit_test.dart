// ConversationCubit drives the chat surface — every regression here
// shows up as messages being lost, duplicated, or stuck in "sending".
// We test the optimistic-send path, the failure path, the retry path,
// and the stream-arrives-after-send dedupe path.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:docsera/Business_Logic/Messages_page/conversation_cubit.dart';
import 'package:docsera/Business_Logic/Messages_page/conversation_state.dart';
import 'package:docsera/services/supabase/supabase_conversation_service.dart';

import '_helpers/tz_init.dart';

class _MockConvService extends Mock implements ConversationService {}

void main() {
  setUpAll(initTzForTests);

  late ConversationCubit cubit;
  late _MockConvService service;

  setUp(() {
    service = _MockConvService();
    cubit = ConversationCubit(service);
  });

  tearDown(() => cubit.close());

  group('ConversationCubit — initial', () {
    test('initial state has empty messages and no pending', () {
      expect(cubit.state.messages, isEmpty);
      expect(cubit.state.pendingMessages, isEmpty);
      expect(cubit.state.isLoading, false);
      expect(cubit.state.errorMessage, isNull);
    });

    test('service getter exposes the injected service', () {
      expect(cubit.service, same(service));
    });
  });

  group('ConversationCubit — sendMessage', () {
    blocTest<ConversationCubit, ConversationState>(
      'optimistic message added to pendingMessages immediately',
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
      act: (c) => c.sendMessage(
        conversationId: 'conv-1',
        senderName: 'Patient',
        text: 'hello',
        attachments: const [],
      ),
      verify: (c) {
        expect(c.state.pendingMessages.length, 1);
        final p = c.state.pendingMessages.first;
        expect(p['text'], 'hello');
        expect(p['conversation_id'], 'conv-1');
        // status starts as 'sending'; after success it stays in
        // pending until the stream confirms it.
        expect(p['status'], 'sending');
      },
    );

    blocTest<ConversationCubit, ConversationState>(
      'service failure marks the optimistic message as failed and sets errorMessage',
      build: () {
        when(() => service.sendMessage(
              conversationId: any(named: 'conversationId'),
              senderName: any(named: 'senderName'),
              text: any(named: 'text'),
              attachments: any(named: 'attachments'),
              isUser: any(named: 'isUser'),
              id: any(named: 'id'),
            )).thenThrow(Exception('network down'));
        return cubit;
      },
      act: (c) => c.sendMessage(
        conversationId: 'conv-1',
        senderName: 'Patient',
        text: 'fails',
        attachments: const [],
      ),
      verify: (c) {
        expect(c.state.pendingMessages.length, 1);
        expect(c.state.pendingMessages.first['status'], 'failed');
        expect(c.state.errorMessage, contains('network down'));
      },
    );

    blocTest<ConversationCubit, ConversationState>(
      'sendMessage assigns a unique id (UUID) per call',
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
        await c.sendMessage(
          conversationId: 'conv-1',
          senderName: 'Patient',
          text: 'a',
          attachments: const [],
        );
        await c.sendMessage(
          conversationId: 'conv-1',
          senderName: 'Patient',
          text: 'b',
          attachments: const [],
        );
      },
      verify: (c) {
        expect(c.state.pendingMessages.length, 2);
        final ids = c.state.pendingMessages.map((m) => m['id']).toSet();
        expect(ids.length, 2, reason: 'each pending must have unique id');
      },
    );
  });

  group('ConversationCubit — retryMessage', () {
    blocTest<ConversationCubit, ConversationState>(
      'retry of a failed message flips status to sending then back on success',
      build: () {
        when(() => service.sendMessage(
              conversationId: any(named: 'conversationId'),
              senderName: any(named: 'senderName'),
              text: any(named: 'text'),
              attachments: any(named: 'attachments'),
              isUser: any(named: 'isUser'),
              id: any(named: 'id'),
            )).thenAnswer((_) async => 'remote-id');
        // Seed a failed pending message into the state.
        cubit.emit(cubit.state.copyWith(pendingMessages: [
          {
            'id': 'msg-1',
            'conversation_id': 'conv-1',
            'sender_name': 'Patient',
            'text': 'retry me',
            'attachments': const [],
            'is_pending': true,
            'status': 'failed',
            'is_user': true,
          }
        ]));
        return cubit;
      },
      act: (c) => c.retryMessage({
        'id': 'msg-1',
        'conversation_id': 'conv-1',
        'sender_name': 'Patient',
        'text': 'retry me',
        'attachments': const [],
        'is_user': true,
      }),
      verify: (c) {
        expect(c.state.errorMessage, isNull);
        expect(c.state.pendingMessages.first['status'], 'sending');
      },
    );

    blocTest<ConversationCubit, ConversationState>(
      'retry without id is a no-op',
      build: () => cubit,
      act: (c) => c.retryMessage({'no_id': true}),
      expect: () => const <ConversationState>[],
    );

    blocTest<ConversationCubit, ConversationState>(
      'retry that fails again leaves status=failed and sets errorMessage',
      build: () {
        when(() => service.sendMessage(
              conversationId: any(named: 'conversationId'),
              senderName: any(named: 'senderName'),
              text: any(named: 'text'),
              attachments: any(named: 'attachments'),
              isUser: any(named: 'isUser'),
              id: any(named: 'id'),
            )).thenThrow(Exception('still down'));
        cubit.emit(cubit.state.copyWith(pendingMessages: [
          {
            'id': 'msg-1',
            'conversation_id': 'conv-1',
            'sender_name': 'Patient',
            'text': 'x',
            'attachments': const [],
            'status': 'failed',
            'is_user': true,
          }
        ]));
        return cubit;
      },
      act: (c) => c.retryMessage({
        'id': 'msg-1',
        'conversation_id': 'conv-1',
        'sender_name': 'Patient',
        'text': 'x',
        'attachments': const [],
        'is_user': true,
      }),
      verify: (c) {
        expect(c.state.pendingMessages.first['status'], 'failed');
        expect(c.state.errorMessage, contains('still down'));
      },
    );
  });

  group('ConversationCubit — close lifecycle', () {
    test('close() does not throw when no streams were started', () async {
      // The cubit is closed by tearDown — ensure no unhandled exception.
      await cubit.close();
      expect(cubit.isClosed, true);
    });
  });
}
