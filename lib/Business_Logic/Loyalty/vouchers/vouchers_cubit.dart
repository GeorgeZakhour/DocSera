import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/services/supabase/loyalty/loyalty_service.dart';
import 'vouchers_state.dart';

class VouchersCubit extends Cubit<VouchersState> {
  final LoyaltyService _service;

  VouchersCubit(this._service) : super(VouchersLoading());

  Future<void> loadVouchers() async {
    emit(VouchersLoading());

    try {
      final vouchers = await _service.getUserVouchers();

      emit(VouchersLoaded(
        active: vouchers.where((v) => v.isActive).toList(),
        used: vouchers.where((v) => v.isUsed).toList(),
        expired: vouchers.where((v) => v.isExpired).toList(),
      ));
    } catch (e) {
      emit(VouchersError('Failed to load vouchers: $e'));
    }
  }
}
