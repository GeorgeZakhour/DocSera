import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/services/supabase/loyalty/loyalty_service.dart';

/// Tracks the count of gift sends the patient hasn't viewed yet.
/// State is the raw int count. The bottom nav badge reads this value.
class UnreadGiftsCubit extends Cubit<int> {
  final LoyaltyService _service;

  UnreadGiftsCubit(this._service) : super(0);

  /// Refreshes the unread count from the server.
  Future<void> refresh() async {
    final count = await _service.countMyUnreadGifts();
    emit(count);
  }

  /// Marks the given claim ids as viewed, then refreshes the count.
  Future<void> markViewed(List<String> claimIds) async {
    if (claimIds.isEmpty) return;
    await _service.markGiftsViewed(claimIds);
    await refresh();
  }

  /// Marks every unread gift for the calling patient as viewed —
  /// drops the count to 0 immediately. Called when the patient
  /// opens the vouchers page so the loyalty-banner badge clears.
  Future<void> acknowledgeAll() async {
    await _service.acknowledgeAllGifts();
    await refresh();
  }
}
