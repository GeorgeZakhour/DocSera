// MessagesCubit tests focus on the surface area that's testable
// without engaging the chained Supabase query builder. The full
// load/realtime path uses .from().select().eq() chaining and
// realtime channels, which mock poorly in unit tests; that path
// is covered by the messaging-funnel integration test through
// ConversationCubit and the encryption service.

import 'package:flutter_test/flutter_test.dart';

import 'package:docsera/Business_Logic/Messages_page/messages_state.dart';

import '_helpers/fixtures.dart';
import '_helpers/tz_init.dart';

void main() {
  setUpAll(initTzForTests);

  group('MessagesState shapes', () {
    test('MessagesLoading is distinct from other states', () {
      expect(MessagesLoading(), isA<MessagesState>());
      expect(MessagesLoading() is MessagesNotLogged, false);
    });

    test('MessagesNotLogged is distinct', () {
      expect(MessagesNotLogged(), isA<MessagesState>());
      expect(MessagesNotLogged() is MessagesLoading, false);
    });

    test('MessagesLoaded carries the conversation list', () {
      final s = MessagesLoaded([
        Fixtures.conversation(id: 'c1'),
        Fixtures.conversation(id: 'c2'),
      ]);
      expect(s.conversations.length, 2);
    });

    test('MessagesError carries an error message', () {
      final s = MessagesError('boom');
      expect(s.message, 'boom');
    });

    test('unreadConversationsCount counts only convs with unread > 0', () {
      final s = MessagesLoaded([
        Fixtures.conversation(id: 'c1', unreadCountForUser: 0),
        Fixtures.conversation(id: 'c2', unreadCountForUser: 3),
        Fixtures.conversation(id: 'c3', unreadCountForUser: 0),
        Fixtures.conversation(id: 'c4', unreadCountForUser: 1),
      ]);
      expect(s.unreadConversationsCount, 2);
    });

    test('unreadConversationsCount handles null unread counts gracefully', () {
      final s = MessagesLoaded([
        Fixtures.conversation(id: 'c1', unreadCountForUser: null),
        Fixtures.conversation(id: 'c2', unreadCountForUser: 5),
      ]);
      expect(s.unreadConversationsCount, 1);
    });

    test('Equatable equality holds for same-shape states', () {
      expect(MessagesLoading() == MessagesLoading(), true);
      expect(MessagesNotLogged() == MessagesNotLogged(), true);
    });

    test('Equatable inequality across different state types', () {
      expect(MessagesLoading() == MessagesNotLogged(), false);
    });
  });
}
