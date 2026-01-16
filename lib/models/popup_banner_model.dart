import 'dart:convert';
import 'package:flutter/material.dart';


class PopupBannerModel {
  final String id;
  final Map<String, dynamic> title;
  final Map<String, dynamic> description;
  final Map<String, dynamic> buttonText;
  final String? imageUrl;
  final String? actionType;
  final String? actionValue;
  final String type; // 'maintenance', 'update', 'info'
  final bool isDismissible;
  final bool showOnce;
  final int priority;

  PopupBannerModel({
    required this.id,
    required this.title,
    required this.description,
    required this.buttonText,
    this.imageUrl,
    this.actionType,
    this.actionValue,
    this.type = 'info',
    this.isDismissible = true,
    this.showOnce = true,
    this.priority = 0,
  });

  factory PopupBannerModel.fromJson(Map<String, dynamic> json) {
    return PopupBannerModel(
      id: json['id'],
      title: json['title'] is String ? jsonDecode(json['title']) : json['title'] ?? {},
      description: json['description'] is String ? jsonDecode(json['description']) : json['description'] ?? {},
      buttonText: json['button_text'] is String ? jsonDecode(json['button_text']) : json['button_text'] ?? {},
      imageUrl: json['image_url'],
      actionType: json['action_type'],
      actionValue: json['action_value'],
      type: json['type'] ?? 'info',
      isDismissible: json['is_dismissible'] ?? true,
      showOnce: json['show_once'] ?? true,
      priority: json['priority'] ?? 0,
    );
  }

  String getTitle(String langCode) => title[langCode] ?? title['en'] ?? '';
  String getDescription(String langCode) => description[langCode] ?? description['en'] ?? '';
  String getButtonText(String langCode) => buttonText[langCode] ?? buttonText['en'] ?? '';
}
