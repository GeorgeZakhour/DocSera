import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/services/supabase/loyalty/loyalty_service.dart';
import 'referral_state.dart';

class ReferralCubit extends Cubit<ReferralState> {
  final LoyaltyService _service;

  ReferralCubit(this._service) : super(ReferralLoading());

  Future<void> loadReferralInfo() async {
    emit(ReferralLoading());

    try {
      final info = await _service.getMyReferralInfo();

      if (info != null) {
        emit(ReferralLoaded(info));
      } else {
        emit(ReferralError('Failed to load referral info'));
      }
    } catch (e) {
      emit(ReferralError('Error: $e'));
    }
  }
}
