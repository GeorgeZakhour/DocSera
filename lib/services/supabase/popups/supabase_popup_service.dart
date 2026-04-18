import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/models/popup_banner_model.dart';
import 'package:flutter/material.dart';

class SupabasePopupService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<PopupBannerModel>> getActiveBanners({String? appVersion}) async {
    try {
      final response = await _client.rpc('get_active_popups', params: {
        'p_app': 'patient',
        'p_version': appVersion,
      });

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => PopupBannerModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error fetching popup banners: $e');
      return [];
    }
  }
}
