import 'package:flutter/material.dart';

/// Parses a hex color string like `#FF8F00` or `FF8F00` into a [Color].
/// Returns [fallback] for null, empty, or malformed input.
Color colorFromHex(String? hex, {Color fallback = const Color(0xFF009092)}) {
  if (hex == null || hex.isEmpty) return fallback;
  var clean = hex.trim().replaceFirst('#', '');
  if (clean.length == 6) clean = 'FF$clean';
  if (clean.length != 8) return fallback;
  final value = int.tryParse(clean, radix: 16);
  if (value == null) return fallback;
  return Color(value);
}
