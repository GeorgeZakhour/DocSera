import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/services/supabase/loyalty/loyalty_service.dart';
import 'partner_state.dart';

class PartnerCubit extends Cubit<PartnerState> {
  final LoyaltyService _service;

  PartnerCubit(this._service) : super(const PartnerInitial());

  Future<void> load(String partnerId) async {
    emit(const PartnerLoading());
    try {
      final result = await _service.getPartnerProfile(partnerId);
      if (result == null) {
        emit(const PartnerNotFound());
        return;
      }
      emit(PartnerLoaded(partner: result.partner, offers: result.offers));
    } catch (e) {
      emit(PartnerError('Failed to load partner: $e'));
    }
  }
}
