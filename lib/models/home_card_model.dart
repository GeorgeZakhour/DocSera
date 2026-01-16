import 'package:flutter/material.dart';

class HomeCardModel {
  final int id;
  final Widget title; // Helper to get localized title directly if needed, but model usually holds raw data
  final Map<String, dynamic>? titleRaw;
  final Map<String, dynamic>? descriptionRaw;
  final Map<String, dynamic>? buttonTextRaw;
  final String imagePath;
  final Color backgroundColor;
  final Color buttonColor;
  final int shapeNumber;
  final int imageShapeNumber;
  final int secondShapeNumber;
  final Color shapeColor;
  final Color? secondShapeColor;
  final bool showSecondShape;
  final String actionType; // 'internal' | 'external'
  final String actionValue; // Route name or URL
  final bool isActive;
  final int orderIndex;
  final Color textColor;
  final String cardStyle; // 'standard' | 'compact'

  HomeCardModel({
    required this.id,
    this.titleRaw,
    this.descriptionRaw,
    this.buttonTextRaw,
    required this.imagePath,
    required this.backgroundColor,
    required this.buttonColor,
    required this.shapeNumber,
    required this.imageShapeNumber,
    required this.secondShapeNumber,
    required this.shapeColor,
    this.secondShapeColor,
    this.showSecondShape = false,
    required this.actionType,
    required this.actionValue,
    this.isActive = true,
    required this.orderIndex,
    this.textColor = Colors.white,
    this.cardStyle = 'standard',
  }) : title = const SizedBox(); // Placeholder, actual localization logic happens in helper methods

  factory HomeCardModel.fromJson(Map<String, dynamic> json) {
    return HomeCardModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      titleRaw: json['title'],
      descriptionRaw: json['description'],
      buttonTextRaw: json['button_text'],
      imagePath: json['image_url'] ?? '',
      backgroundColor: _parseColor(json['background_color']) ?? Colors.grey,
      buttonColor: _parseColor(json['button_color']) ?? Colors.white,
      shapeNumber: json['shape_number'] ?? 1,
      imageShapeNumber: json['image_shape_number'] ?? 1,
      secondShapeNumber: json['second_shape_number'] ?? 1,
      shapeColor: _parseColor(json['shape_color']) ?? Colors.white.withOpacity(0.3),
      secondShapeColor: _parseColor(json['second_shape_color']),
      showSecondShape: json['show_second_shape'] ?? false,
      actionType: json['action_type'] ?? 'internal',
      actionValue: json['action_value'] ?? '',
      isActive: json['is_active'] ?? true,
      orderIndex: json['order_index'] ?? 0,
      textColor: _parseColor(json['text_color']) ?? Colors.white,
      cardStyle: json['card_style'] ?? 'standard',
    );
  }

  static Color? _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    try {
      hexString = hexString.replaceAll('#', '');
      if (hexString.length == 6) {
        hexString = 'FF$hexString';
      }
      return Color(int.parse(hexString, radix: 16));
    } catch (e) {
      debugPrint('Error parsing color: $hexString');
      return null;
    }
  }

  String getTitle(String langCode) {
    if (titleRaw == null) return '';
    return titleRaw![langCode] ?? titleRaw!['en'] ?? '';
  }

  String getDescription(String langCode) {
    if (descriptionRaw == null) return '';
    return descriptionRaw![langCode] ?? descriptionRaw!['en'] ?? '';
  }

  String getButtonText(String langCode) {
    if (buttonTextRaw == null) return '';
    return buttonTextRaw![langCode] ?? buttonTextRaw!['en'] ?? '';
  }
}
