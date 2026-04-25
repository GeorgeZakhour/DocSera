import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/services/supabase/loyalty/loyalty_service.dart';
import 'vouchers_state.dart';

class VouchersCubit extends Cubit<VouchersState> {
  final LoyaltyService _service;

  VouchersCubit(this._service) : super(VouchersLoading());

  Future<void> loadVouchers() async {
    emit(VouchersLoading());

    try {
      // Fetch both partner vouchers and doctor promotion claims
      final results = await Future.wait([
        _service.getUserVouchers(),
        _service.getMyDoctorPromotionClaims(),
      ]);

      final allVouchers = [...results[0], ...results[1]];

      emit(VouchersLoaded(
        active: allVouchers.where((v) => v.isActive).toList(),
        used: allVouchers.where((v) => v.isUsed).toList(),
        expired: allVouchers.where((v) => v.isExpired).toList(),
      ));
    } catch (e) {
      emit(VouchersError('Failed to load vouchers: $e'));
    }
  }
}
