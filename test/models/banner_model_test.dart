import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/models/banner_model.dart';

void main() {
  group('BannerModel', () {
    Map<String, dynamic> json({
      bool isActive = true,
      bool isSponsored = false,
      String? start,
      String? end,
    }) =>
        {
          'id': 'b1',
          'title': {'en': 'Welcome', 'ar': 'مرحبا'},
          'text': {'en': 'Body', 'ar': 'نص'},
          'image_path': 'https://x/img.png',
          'logo_path': 'https://x/logo.png',
          'is_active': isActive,
          'start_time': start,
          'end_time': end,
          'is_sponsored': isSponsored,
          'logo_container_color': '#ffffff',
          'order_index': 5,
          'content_sections': {'sections': []},
          'show_title': true,
        };

    test('parses canonical active banner', () {
      final b = BannerModel.fromJson(json());
      expect(b.id, 'b1');
      expect(b.imagePath, 'https://x/img.png');
      expect(b.isActive, true);
      expect(b.orderIndex, 5);
      expect(b.title?['en'], 'Welcome');
      expect(b.title?['ar'], 'مرحبا');
    });

    test('parses start/end times when provided', () {
      final b = BannerModel.fromJson(json(
        start: '2026-01-01T00:00:00Z',
        end: '2026-12-31T00:00:00Z',
      ));
      expect(b.startTime, isNotNull);
      expect(b.endTime, isNotNull);
      expect(b.startTime!.year, 2026);
    });

    test('null start/end time fields stay null', () {
      final b = BannerModel.fromJson(json());
      expect(b.startTime, isNull);
      expect(b.endTime, isNull);
    });

    test('invalid date string falls back to null (no crash)', () {
      final b = BannerModel.fromJson(json(start: 'not-a-date'));
      expect(b.startTime, isNull);
    });

    test('isSponsored flag round-trips', () {
      final b = BannerModel.fromJson(json(isSponsored: true));
      expect(b.isSponsored, true);
    });

    test('inactive banner round-trips', () {
      final b = BannerModel.fromJson(json(isActive: false));
      expect(b.isActive, false);
    });

    test('missing fields use defaults', () {
      final b = BannerModel.fromJson({'id': 'x', 'image_path': ''});
      expect(b.isActive, true);
      expect(b.isSponsored, false);
      expect(b.orderIndex, 0);
      expect(b.showTitle, true);
    });
  });

  group('BannerContentSection', () {
    test('parses canonical text section', () {
      final s = BannerContentSection.fromJson({
        'type': 'text',
        'title': 'Heading',
        'body': 'Body text',
      });
      expect(s.type, 'text');
      expect(s.title, 'Heading');
      expect(s.body, 'Body text');
    });

    test('items list is parsed when present', () {
      final s = BannerContentSection.fromJson({
        'type': 'list',
        'items': ['a', 'b', 'c'],
      });
      expect(s.items, ['a', 'b', 'c']);
    });

    test('missing type defaults to text', () {
      final s = BannerContentSection.fromJson({});
      expect(s.type, 'text');
    });
  });
}
