import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/models/popup_banner_model.dart';

Map<String, dynamic> _json({
  String type = 'info',
  bool dismissible = true,
  bool showOnce = true,
  String? starts,
  String? ends,
  String? minVer,
  String? maxVer,
}) =>
    {
      'id': 'pb1',
      'title': {'en': 'Hello', 'ar': 'مرحبا'},
      'description': {'en': 'Body', 'ar': 'نص'},
      'button_text': {'en': 'OK', 'ar': 'موافق'},
      'image_url': 'https://x/img.png',
      'action_type': 'route',
      'action_value': '/home',
      'type': type,
      'is_dismissible': dismissible,
      'show_once': showOnce,
      'priority': 5,
      'target_app': 'patient',
      'starts_at': starts,
      'ends_at': ends,
      'min_app_version': minVer,
      'max_app_version': maxVer,
    };

void main() {
  group('PopupBannerModel', () {
    test('parses canonical info banner', () {
      final b = PopupBannerModel.fromJson(_json());
      expect(b.id, 'pb1');
      expect(b.title['en'], 'Hello');
      expect(b.type, 'info');
      expect(b.isDismissible, true);
      expect(b.priority, 5);
    });

    test('parses each banner type variant', () {
      for (final t in ['maintenance', 'update', 'info', 'policy', 'feature']) {
        final b = PopupBannerModel.fromJson(_json(type: t));
        expect(b.type, t);
      }
    });

    test('non-dismissible flag round-trips', () {
      final b = PopupBannerModel.fromJson(_json(dismissible: false));
      expect(b.isDismissible, false);
    });

    test('show_once=false round-trips', () {
      final b = PopupBannerModel.fromJson(_json(showOnce: false));
      expect(b.showOnce, false);
    });

    test('JSON-string title field is decoded', () {
      // Older payloads send title as a JSON-encoded string.
      final j = _json();
      j['title'] = '{"en":"FromString","ar":"من سلسلة"}';
      final b = PopupBannerModel.fromJson(j);
      expect(b.title['en'], 'FromString');
    });

    test('missing dismissible/show_once fields use safe defaults', () {
      final j = _json();
      j.remove('is_dismissible');
      j.remove('show_once');
      final b = PopupBannerModel.fromJson(j);
      expect(b.isDismissible, true);
      expect(b.showOnce, true);
    });

    test('missing priority defaults to 0', () {
      final j = _json();
      j.remove('priority');
      final b = PopupBannerModel.fromJson(j);
      expect(b.priority, 0);
    });
  });
}
