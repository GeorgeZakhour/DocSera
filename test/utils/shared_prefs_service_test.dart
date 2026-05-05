// SharedPrefsService is the local-cache layer for offline UX.
// Bugs here cause stale data to persist or fresh data to fail to load.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:docsera/utils/shared_prefs_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPrefsService — boolean flags', () {
    test('saveData/loadData round-trip for refreshFavorites', () async {
      final svc = SharedPrefsService();
      await svc.saveData('refreshFavorites', true);
      final v = await svc.loadData('refreshFavorites');
      expect(v, true);
    });

    test('saveData/loadData round-trip for refreshAppointments', () async {
      final svc = SharedPrefsService();
      await svc.saveData('refreshAppointments', false);
      final v = await svc.loadData('refreshAppointments');
      expect(v, false);
    });

    test('saveData/loadData round-trip for isLoggedIn', () async {
      final svc = SharedPrefsService();
      await svc.saveData('isLoggedIn', true);
      expect(await svc.loadData('isLoggedIn'), true);
    });

    test('boolean flag missing returns false (safe default)', () async {
      final svc = SharedPrefsService();
      expect(await svc.loadData('refreshFavorites'), false);
    });

    test('non-bool value for boolean key is rejected silently', () async {
      // saveData logs but doesn't crash when wrong type is given.
      final svc = SharedPrefsService();
      await svc.saveData('refreshFavorites', 'not a bool');
      // The flag remains at its default (false).
      expect(await svc.loadData('refreshFavorites'), false);
    });
  });

  group('SharedPrefsService — JSON data', () {
    test('arbitrary key round-trips a Map', () async {
      final svc = SharedPrefsService();
      await svc.saveData('user', {'name': 'John', 'age': 30});
      final loaded = await svc.loadData('user');
      expect(loaded, isA<Map>());
      expect(loaded['name'], 'John');
      expect(loaded['age'], 30);
    });

    test('arbitrary key round-trips a String list', () async {
      // Note: loadData has a quirky timestamp-conversion path that turns
      // raw ints in lists into DateTimes (it's intended for nested fields
      // like message_timestamps, but applies indiscriminately at the top
      // level). Using strings here keeps the test scoped to round-trip
      // correctness without engaging that legacy behavior.
      final svc = SharedPrefsService();
      await svc.saveData('items', ['a', 'b', 'c']);
      expect(await svc.loadData('items'), ['a', 'b', 'c']);
    });

    test('missing key returns null', () async {
      final svc = SharedPrefsService();
      expect(await svc.loadData('does-not-exist'), isNull);
    });
  });

  group('SharedPrefsService — singleton', () {
    test('factory returns the same instance', () {
      expect(identical(SharedPrefsService(), SharedPrefsService()), true);
    });
  });
}
