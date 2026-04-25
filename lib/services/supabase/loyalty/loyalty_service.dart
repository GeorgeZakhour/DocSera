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

      final history = List<Map<String, dynamic>>.from(response);

      // Enrich spend entries that lack metadata with offer/voucher details
      await _enrichRedeemEntries(history, userId);

      return history;
    } catch (e) {
      debugPrint('Error fetching points history: $e');
      return [];
    }
  }

  /// For redeem entries without metadata, look up the offer details
  /// from vouchers → offers to provide localized titles and partner names.
  Future<void> _enrichRedeemEntries(List<Map<String, dynamic>> history, String userId) async {
    final redeemEntries = history.where((tx) {
      final desc = (tx['description'] as String? ?? '').toLowerCase();
      final meta = tx['metadata'] as Map<String, dynamic>?;
      final hasMetaTitle = meta != null && meta['offer_title'] != null;
      return !hasMetaTitle && (desc.contains('redeem') || desc.contains('claimed'));
    }).toList();

    if (redeemEntries.isEmpty) return;

    try {
      // Fetch user's vouchers with offer details
      final vouchers = await _client
          .from('vouchers')
          .select('id, code, offer_id, created_at, expires_at, offers!inner(title, title_ar, partner_name, partner_name_ar, category, voucher_validity_days)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final voucherList = List<Map<String, dynamic>>.from(vouchers);

      for (int i = 0; i < history.length; i++) {
        final tx = history[i];
        final desc = (tx['description'] as String? ?? '').toLowerCase();
        final meta = tx['metadata'] as Map<String, dynamic>?;
        if (meta != null && meta['offer_title'] != null) continue;
        if (!desc.contains('redeem') && !desc.contains('claimed')) continue;

        // Try to match by timestamp proximity (within 5 seconds)
        final txCreated = DateTime.tryParse(tx['created_at'] as String? ?? '');
        if (txCreated == null) continue;

        for (final v in voucherList) {
          final vCreated = DateTime.tryParse(v['created_at'] as String? ?? '');
          if (vCreated == null) continue;

          final diff = txCreated.difference(vCreated).inSeconds.abs();
          if (diff < 5) {
            final offer = v['offers'] as Map<String, dynamic>? ?? {};
            history[i] = Map<String, dynamic>.from(tx)
              ..['metadata'] = <String, dynamic>{
                ...?meta,
                'type': 'redeem',
                'offer_title': offer['title'],
                'offer_title_ar': offer['title_ar'],
                'partner_name': offer['partner_name'],
                'partner_name_ar': offer['partner_name_ar'],
                'voucher_code': v['code'],
                'expires_at': v['expires_at'],
                'validity_days': offer['voucher_validity_days'],
                'category': offer['category'],
              };
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error enriching redeem entries: $e');
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

  /// Fetches the current user's doctor promotion claims with promotion details.
  /// Maps them to VoucherModel-compatible format for display in the vouchers page.
  Future<List<VoucherModel>> getMyDoctorPromotionClaims() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('doctor_promotion_claims')
          .select('*, doctor_promotions!inner(offer_type, custom_title, custom_title_ar, description, description_ar, discount_value, doctors!inner(name_en, name_ar))')
          .eq('patient_id', userId)
          .order('claimed_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) {
        final promo = json['doctor_promotions'] as Map<String, dynamic>? ?? {};
        final doctor = promo['doctors'] as Map<String, dynamic>? ?? {};
        final offerType = promo['offer_type'] as String? ?? 'custom';
        final status = json['status'] as String;

        // Map 'claimed' status to 'active' for VoucherModel compatibility
        final mappedStatus = status == 'claimed' ? 'active' : status;

        // Build title from offer type
        String titleEn = promo['custom_title'] as String? ?? _offerTypeTitle(offerType, 'en');
        String titleAr = promo['custom_title_ar'] as String? ?? _offerTypeTitle(offerType, 'ar');

        return VoucherModel(
          id: json['id'] as String,
          offerId: json['promotion_id'] as String,
          code: json['voucher_code'] as String,
          status: mappedStatus,
          redeemedAt: json['claimed_at'] as String,
          usedAt: json['used_at'] as String?,
          expiresAt: json['expires_at'] as String,
          offerTitle: titleEn,
          offerTitleAr: titleAr,
          offerDescription: promo['description'] as String?,
          offerDescriptionAr: promo['description_ar'] as String?,
          offerCategory: 'doctor_promotion',
          discountType: offerType.contains('percentage') ? 'percentage' : 'fixed',
          discountValue: (promo['discount_value'] as num?)?.toDouble(),
          partnerName: doctor['name_en'] as String?,
          partnerNameAr: doctor['name_ar'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching doctor promotion claims: $e');
      return [];
    }
  }

  String _offerTypeTitle(String offerType, String locale) {
    final titles = {
      'free_first_consultation': locale == 'ar' ? 'استشارة أولى مجانية' : 'Free First Consultation',
      'percentage_discount': locale == 'ar' ? 'خصم بالنسبة المئوية' : 'Percentage Discount',
      'fixed_discount': locale == 'ar' ? 'خصم ثابت' : 'Fixed Discount',
      'free_followup': locale == 'ar' ? 'متابعة مجانية' : 'Free Follow-up',
      'custom': locale == 'ar' ? 'عرض خاص' : 'Special Offer',
    };
    return titles[offerType] ?? titles['custom']!;
  }
}
