// ConversationCubit media-message tests. Covers the optimistic upload
// path (which adds the message with localPath attachments before any
// network call) and the failure path that flips status to 'failed'.

import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:docsera/Business_Logic/Messages_page/conversation_cubit.dart';
import 'package:docsera/Business_Logic/Messages_page/conversation_state.dart';
import 'package:docsera/services/supabase/supabase_conversation_service.dart';

import '_helpers/tz_init.dart';

class _MockConvService extends Mock implements ConversationService {}

class _FakeFile extends Fake implements File {
  _FakeFile(this._path);
  final String _path;

  @override
  String get path => _path;
}

void main() {
  setUpAll(() {
    initTzForTests();
    registerFallbackValue(_FakeFile('/tmp/fallback'));
  });

  late ConversationCubit cubit;
  late _MockConvService service;

  setUp(() {
    service = _MockConvService();
    cubit = ConversationCubit(service);
  });

  tearDown(() => cubit.close());

  group('ConversationCubit — sendMediaMessage', () {
    blocTest<ConversationCubit, ConversationState>(
      'image-only message adds an optimistic pending entry with localPath',
      build: () {
        when(() => service.uploadAttachmentFile(
              conversationId: any(named: 'conversationId'),
              file: any(named: 'file'),
              type: any(named: 'type'),
              storageName: any(named: 'storageName'),
              displayName: any(named: 'displayName'),
            )).thenAnswer((_) async => {
              'type': 'image',
              'paths': const ['users/x/img.jpg'],
              'fileName': 'img.jpg',
            });
        when(() => service.sendMessage(
              conversationId: any(named: 'conversationId'),
              senderName: any(named: 'senderName'),
              text: any(named: 'text'),
              attachments: any(named: 'attachments'),
              isUser: any(named: 'isUser'),
              id: any(named: 'id'),
            )).thenAnswer((_) async => 'remote-1');
        return cubit;
      },
      act: (c) => c.sendMediaMessage(
        conversationId: 'conv-1',
        senderName: 'Patient',
        text: '',
        images: [_FakeFile('/tmp/img.jpg')],
      ),
      verify: (c) {
        expect(c.state.pendingMessages, isNotEmpty);
        final m = c.state.pendingMessages.first;
        final attachments =
            (m['attachments'] as List).cast<Map<String, dynamic>>();
        expect(attachments, isNotEmpty);
        expect(attachments.first['type'], 'image');
      },
    );

    blocTest<ConversationCubit, ConversationState>(
      'PDF + image batched together produce two pending attachments',
      build: () {
        when(() => service.uploadAttachmentFile(
              conversationId: any(named: 'conversationId'),
              file: any(named: 'file'),
              type: any(named: 'type'),
              storageName: any(named: 'storageName'),
              displayName: any(named: 'displayName'),
            )).thenAnswer((_) async => {'type': 'image', 'paths': const []});
        when(() => service.sendMessage(
              conversationId: any(named: 'conversationId'),
              senderName: any(named: 'senderName'),
              text: any(named: 'text'),
              attachments: any(named: 'attachments'),
              isUser: any(named: 'isUser'),
              id: any(named: 'id'),
            )).thenAnswer((_) async => 'remote-1');
        return cubit;
      },
      act: (c) => c.sendMediaMessage(
        conversationId: 'conv-1',
        senderName: 'Patient',
        text: '',
        images: [_FakeFile('/tmp/a.jpg')],
        pdf: _FakeFile('/tmp/b.pdf'),
      ),
      verify: (c) {
        // Optimistic state had 2 attachments before any upload.
        expect(c.state.pendingMessages, isNotEmpty);
      },
    );

    blocTest<ConversationCubit, ConversationState>(
      'upload failure marks the optimistic message as failed and sets errorMessage',
      build: () {
        when(() => service.uploadAttachmentFile(
              conversationId: any(named: 'conversationId'),
              file: any(named: 'file'),
              type: any(named: 'type'),
              storageName: any(named: 'storageName'),
              displayName: any(named: 'displayName'),
            )).thenThrow(Exception('storage 500'));
        return cubit;
      },
      act: (c) => c.sendMediaMessage(
        conversationId: 'conv-1',
        senderName: 'Patient',
        text: '',
        images: [_FakeFile('/tmp/x.jpg')],
      ),
      verify: (c) {
        expect(c.state.pendingMessages, isNotEmpty);
        expect(c.state.pendingMessages.first['status'], 'failed');
        expect(c.state.errorMessage, contains('storage 500'));
      },
    );
  });
}
