import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/models/offer_model.dart';
import 'package:docsera/models/voucher_model.dart';
import 'package:docsera/models/referral_model.dart';

class LoyaltyService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<OfferModel>> getAvailableOffers({String? category}) async {
    try {
      final response = await _client.rpc('get_available_offers', params: {
        'p_category': category,
      });

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => OfferModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error fetching offers: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> redeemOffer(String offerId) async {
    try {
      final response = await _client.rpc('redeem_offer', params: {
        'p_offer_id': offerId,
      });
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error redeeming offer: $e');
      return {'success': false, 'error': 'network_error'};
    }
  }

  Future<List<VoucherModel>> getUserVouchers({String? status}) async {
    try {
      final response = await _client.rpc('get_user_vouchers', params: {
        'p_status': status,
      });

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => VoucherModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error fetching vouchers: $e');
      return [];
    }
  }

  Future<ReferralInfo?> getMyReferralInfo() async {
    try {
      final response = await _client.rpc('get_my_referral_info');
      return ReferralInfo.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error fetching referral info: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> completeReferral({
    required String referralCode,
    required String referredUserId,
    required String referredPhone,
    required String deviceId,
  }) async {
    try {
      final response = await _client.rpc('complete_referral', params: {
        'p_referral_code': referralCode,
        'p_referred_user_id': referredUserId,
        'p_referred_phone': referredPhone,
        'p_device_id': deviceId,
      });
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error completing referral: $e');
      return {'success': false, 'error': 'network_error'};
    }
  }

  Future<List<Map<String, dynamic>>> getPointsHistory(String userId) async {
    try {
      final response = await _client
          .from('points_history')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching points history: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDoctorPromotions(String doctorId) async {
    try {
      final response = await _client
          .from('doctor_promotions')
          .select()
          .eq('doctor_id', doctorId)
          .eq('is_active', true)
          .or('end_date.is.null,end_date.gt.${DateTime.now().toUtc().toIso8601String()}');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching doctor promotions: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> claimDoctorPromotion(String promotionId) async {
    try {
      final response = await _client.rpc('claim_doctor_promotion', params: {
        'p_promotion_id': promotionId,
      });
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error claiming promotion: $e');
      return {'success': false, 'error': 'network_error'};
    }
  }
}
