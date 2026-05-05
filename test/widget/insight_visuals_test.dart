// InsightVisuals is the single source of truth for icon/color/label
// used by gift cards, insights cards, and analytics dashboards. The
// switch arms here must stay in sync with the backend `color_hex`
// column on the insight registry — these tests pin both sides of that
// contract so a backend rename is caught at compile-time-ish here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docsera/widgets/insight_visuals.dart';

void main() {
  group('InsightVisuals.iconFor', () {
    test('birthday → cake', () {
      expect(InsightVisuals.iconFor('birthday'), Icons.cake_rounded);
    });
    test('patient_anniversary → celebration', () {
      expect(InsightVisuals.iconFor('patient_anniversary'),
          Icons.celebration_rounded);
    });
    test('visit_milestone → workspace_premium', () {
      expect(InsightVisuals.iconFor('visit_milestone'),
          Icons.workspace_premium_rounded);
    });
    test('welcome → volunteer_activism', () {
      expect(InsightVisuals.iconFor('welcome'),
          Icons.volunteer_activism_rounded);
    });
    test('lapsed → history', () {
      expect(InsightVisuals.iconFor('lapsed'), Icons.history_rounded);
    });
    test('vip → star', () {
      expect(InsightVisuals.iconFor('vip'), Icons.star_rounded);
    });
    test('cultural_occasion → auto_awesome', () {
      expect(InsightVisuals.iconFor('cultural_occasion'),
          Icons.auto_awesome_rounded);
    });
    test('unknown insight type → fallback tune icon', () {
      expect(InsightVisuals.iconFor('made_up_one'), Icons.tune_rounded);
      expect(InsightVisuals.iconFor(''), Icons.tune_rounded);
    });
  });

  group('InsightVisuals.colorFor', () {
    test('each canonical insight type has a unique color', () {
      final colors = {
        'birthday': InsightVisuals.colorFor('birthday'),
        'patient_anniversary': InsightVisuals.colorFor('patient_anniversary'),
        'visit_milestone': InsightVisuals.colorFor('visit_milestone'),
        'welcome': InsightVisuals.colorFor('welcome'),
        'lapsed': InsightVisuals.colorFor('lapsed'),
        'vip': InsightVisuals.colorFor('vip'),
      };
      // Ensure each canonical type has a distinct color (no accidental
      // duplicates that would make UI cards indistinguishable).
      expect(colors.values.toSet().length, colors.length);
    });

    test('unknown insight type falls back to teal (matches default brand)',
        () {
      final fallback = InsightVisuals.colorFor('unknown');
      expect(fallback, const Color(0xFF14B8A6));
    });
  });

  group('InsightVisuals.labelFor', () {
    test('canonical types resolve to a human-readable label', () {
      expect(InsightVisuals.labelFor('birthday'), 'Birthday');
      expect(InsightVisuals.labelFor('vip'), 'VIP');
      expect(InsightVisuals.labelFor('lapsed'), 'Lapsed');
    });

    test('unknown type returns the raw insight type as fallback', () {
      expect(InsightVisuals.labelFor('experimental_new'), 'experimental_new');
    });
  });
}
