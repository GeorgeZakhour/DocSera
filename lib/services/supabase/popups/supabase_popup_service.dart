import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/models/popup_banner_model.dart';
import 'package:flutter/material.dart';

class SupabasePopupService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<PopupBannerModel>> getActiveBanners() async {
    try {
      final response = await _client
          .from('popup_banners')
          .select()
          .eq('is_active', true)
          .order('priority', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => PopupBannerModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching popup banners: $e');
      return [];
    }
  }
}
