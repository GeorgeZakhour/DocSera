import 'package:docsera/models/banner_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBannerService {
  final SupabaseClient _client;

  SupabaseBannerService() : _client = Supabase.instance.client;

  Future<List<BannerModel>> getActiveBanners() async {
    final now = DateTime.now().toIso8601String();

    // Query for active banners within the time range
    final response = await _client
        .from('banners')
        .select()
        .eq('is_active', true)
        .or('start_time.is.null,start_time.lte.$now')
        .or('end_time.is.null,end_time.gte.$now')
        .order('order_index', ascending: true);

    final data = response as List<dynamic>;
    return data.map((e) => BannerModel.fromJson(e)).toList();
  }
}
