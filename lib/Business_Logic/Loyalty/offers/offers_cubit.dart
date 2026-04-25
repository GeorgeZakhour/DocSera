import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/services/supabase/loyalty/loyalty_service.dart';
import 'offers_state.dart';

class OffersCubit extends Cubit<OffersState> {
  final LoyaltyService _service;

  OffersCubit(this._service) : super(OffersLoading());

  Future<void> loadOffers({String? category}) async {
    emit(OffersLoading());

    try {
      final offers = await _service.getAvailableOffers(category: category);

      emit(OffersLoaded(allOffers: offers));
    } catch (e) {
      emit(OffersError('Failed to load offers: $e'));
    }
  }

  Future<void> redeemOffer(String offerId) async {
    emit(OfferRedeemLoading());

    final result = await _service.redeemOffer(offerId);

    if (result['success'] == true) {
      emit(OfferRedeemSuccess(
        voucherCode: result['voucher_code'] as String,
        expiresAt: result['expires_at'] as String,
      ));
    } else {
      emit(OfferRedeemError(result['error'] as String? ?? 'unknown_error'));
    }
  }
}
