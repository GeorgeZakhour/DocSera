import 'package:flutter/material.dart';

/// Single source of truth for each insight type's icon + color +
/// label. Mirrors the registry's `color_hex` column.
/// Add new insight types here when the registry grows.
class InsightVisuals {
  static IconData iconFor(String insightType) {
    switch (insightType) {
      case 'birthday':            return Icons.cake_rounded;
      case 'patient_anniversary': return Icons.celebration_rounded;
      case 'visit_milestone':     return Icons.workspace_premium_rounded;
      case 'welcome':             return Icons.volunteer_activism_rounded;
      case 'lapsed':              return Icons.history_rounded;
      case 'vip':                 return Icons.star_rounded;
      case 'cultural_occasion':   return Icons.auto_awesome_rounded;
      default:                    return Icons.tune_rounded;
    }
  }

  static Color colorFor(String insightType) {
    switch (insightType) {
      case 'birthday':            return const Color(0xFFF59E0B);
      case 'patient_anniversary': return const Color(0xFF8B5CF6);
      case 'visit_milestone':     return const Color(0xFF0EA5E9);
      case 'welcome':             return const Color(0xFF22C55E);
      case 'lapsed':              return const Color(0xFFEF4444);
      case 'vip':                 return const Color(0xFFEAB308);
      case 'cultural_occasion':   return const Color(0xFF14B8A6);
      default:                    return const Color(0xFF14B8A6);
    }
  }

  static String labelFor(String insightType) {
    switch (insightType) {
      case 'birthday':            return 'Birthday';
      case 'patient_anniversary': return 'Patient anniversary';
      case 'visit_milestone':     return 'Visit milestone';
      case 'welcome':             return 'Welcome';
      case 'lapsed':              return 'Lapsed';
      case 'vip':                 return 'VIP';
      case 'cultural_occasion':   return 'Cultural occasion';
      default:                    return insightType;
    }
  }
}
