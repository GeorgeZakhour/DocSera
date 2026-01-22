import 'package:flutter/material.dart';

class BannerModel {
  final String id;
  final Map<String, dynamic>? title; // Changed to Map for localization
  final Map<String, dynamic>? text;  // Changed to Map for localization
  final String imagePath;
  final String? logoPath;
  final bool isActive;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isSponsored;
  final String? logoContainerColor;
  final int orderIndex;
  final Map<String, dynamic>? contentSections; // Changed to Map for localization
  final bool showTitle;

  BannerModel({
    required this.id,
    this.title,
    this.text,
    required this.imagePath,
    this.logoPath,
    this.isActive = true,
    this.startTime,
    this.endTime,
    this.isSponsored = false,
    this.logoContainerColor,
    this.orderIndex = 0,
    this.contentSections,
    this.showTitle = true,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'] ?? '',
      title: json['title'],
      text: json['text'],
      imagePath: json['image_path'] ?? '',
      logoPath: json['logo_path'],
      isActive: json['is_active'] ?? true,
      startTime: json['start_time'] != null ? DateTime.tryParse(json['start_time']) : null,
      endTime: json['end_time'] != null ? DateTime.tryParse(json['end_time']) : null,
      isSponsored: json['is_sponsored'] ?? false,
      logoContainerColor: json['logo_container_color'],
      orderIndex: json['order_index'] ?? 0,
      contentSections: json['content_sections'],
      showTitle: json['show_title'] ?? true,
    );
  }

  String getTitle(String langCode) {
    if (title == null) return '';
    return title![langCode] ?? title!['en'] ?? '';
  }

  String getText(String langCode) {
    if (text == null) return '';
    return text![langCode] ?? text!['en'] ?? '';
  }

  List<BannerContentSection> getContentSections(String langCode) {
    if (contentSections == null) return [];
    
    final sections = contentSections![langCode] ?? contentSections!['en'];
    
    if (sections is List) {
       return sections.map((e) => BannerContentSection.fromJson(e)).toList();
    }
    return [];
  }
}

class BannerContentSection {
  final String type; // 'text', 'image', 'list'
  final String? title;
  final String? body;
  final String? url;
  final List<String>? items;

  BannerContentSection({
    required this.type,
    this.title,
    this.body,
    this.url,
    this.items,
  });

  factory BannerContentSection.fromJson(Map<String, dynamic> json) {
    return BannerContentSection(
      type: json['type'] ?? 'text',
      title: json['title'],
      body: json['body'],
      url: json['url'],
      items: (json['items'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }
}
