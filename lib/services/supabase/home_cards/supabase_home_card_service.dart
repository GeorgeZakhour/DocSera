import 'package:docsera/models/home_card_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseHomeCardService {
  final SupabaseClient _client;

  SupabaseHomeCardService() : _client = Supabase.instance.client;

  Future<List<HomeCardModel>> getActiveHomeCards() async {
    // Query for active cards
    final response = await _client
        .from('home_cards')
        .select()
        .eq('is_active', true)
        .order('order_index', ascending: true);

    final data = response as List<dynamic>;
    return data.map((e) => HomeCardModel.fromJson(e)).toList();
  }
}
