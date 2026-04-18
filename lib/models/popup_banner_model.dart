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
  final String type; // 'maintenance', 'update', 'info', 'policy', 'feature'
  final bool isDismissible;
  final bool showOnce;
  final int priority;
  final String targetApp;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? minAppVersion;
  final String? maxAppVersion;

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
    this.targetApp = 'all',
    this.startsAt,
    this.endsAt,
    this.minAppVersion,
    this.maxAppVersion,
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
      targetApp: json['target_app'] ?? 'all',
      startsAt: json['starts_at'] != null ? DateTime.tryParse(json['starts_at']) : null,
      endsAt: json['ends_at'] != null ? DateTime.tryParse(json['ends_at']) : null,
      minAppVersion: json['min_app_version'],
      maxAppVersion: json['max_app_version'],
    );
  }

  String getTitle(String langCode) => title[langCode] ?? title['en'] ?? '';
  String getDescription(String langCode) => description[langCode] ?? description['en'] ?? '';
  String getButtonText(String langCode) => buttonText[langCode] ?? buttonText['en'] ?? '';
}
