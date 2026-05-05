import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docsera/models/home_card_model.dart';

Map<String, dynamic> _json({
  dynamic id = 1,
  String? bg = '#FF0000',
  bool active = true,
  String actionType = 'internal',
}) =>
    {
      'id': id,
      'title': {'en': 'Card', 'ar': 'بطاقة'},
      'description': {'en': 'Body', 'ar': 'نص'},
      'button_text': {'en': 'Open', 'ar': 'افتح'},
      'image_url': 'https://x/img.png',
      'background_color': bg,
      'button_color': '#FFFFFF',
      'shape_number': 2,
      'image_shape_number': 3,
      'second_shape_number': 4,
      'shape_color': '#80FFFFFF',
      'second_shape_color': '#80AAAAAA',
      'show_second_shape': true,
      'action_type': actionType,
      'action_value': '/route',
      'is_active': active,
      'order_index': 7,
      'text_color': '#000000',
      'card_style': 'compact',
    };

void main() {
  group('HomeCardModel', () {
    test('parses canonical card', () {
      final c = HomeCardModel.fromJson(_json());
      expect(c.id, 1);
      expect(c.imagePath, 'https://x/img.png');
      expect(c.shapeNumber, 2);
      expect(c.imageShapeNumber, 3);
      expect(c.actionType, 'internal');
      expect(c.actionValue, '/route');
      expect(c.isActive, true);
      expect(c.orderIndex, 7);
      expect(c.cardStyle, 'compact');
      expect(c.showSecondShape, true);
    });

    test('id as String is coerced to int', () {
      final c = HomeCardModel.fromJson(_json(id: '42'));
      expect(c.id, 42);
    });

    test('id as non-numeric String defaults to 0', () {
      final c = HomeCardModel.fromJson(_json(id: 'abc'));
      expect(c.id, 0);
    });

    test('null background_color falls back to grey', () {
      final c = HomeCardModel.fromJson(_json(bg: null));
      expect(c.backgroundColor, Colors.grey);
    });

    test('inactive card round-trips', () {
      final c = HomeCardModel.fromJson(_json(active: false));
      expect(c.isActive, false);
    });

    test('external action type round-trips', () {
      final c = HomeCardModel.fromJson(_json(actionType: 'external'));
      expect(c.actionType, 'external');
    });

    test('localized title/description/button maps preserved', () {
      final c = HomeCardModel.fromJson(_json());
      expect(c.titleRaw?['en'], 'Card');
      expect(c.descriptionRaw?['ar'], 'نص');
      expect(c.buttonTextRaw?['en'], 'Open');
    });

    test('missing optional fields use safe defaults', () {
      final c = HomeCardModel.fromJson({'id': 99});
      expect(c.imagePath, '');
      expect(c.actionType, 'internal');
      expect(c.actionValue, '');
      expect(c.isActive, true);
      expect(c.orderIndex, 0);
      expect(c.cardStyle, 'standard');
      expect(c.shapeNumber, 1);
      expect(c.showSecondShape, false);
    });
  });
}
