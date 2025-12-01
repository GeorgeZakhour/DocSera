import 'package:bloc/bloc.dart';
import 'package:docsera/Business_Logic/Account_page/points_history/points_history_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PointsHistoryCubit extends Cubit<PointsHistoryState> {
  PointsHistoryCubit() : super(PointsHistoryLoading());

  Future<void> loadHistory(String userId, {bool silent = false}) async {

    // Only show loading UI if NOT silent refresh
    if (!silent) emit(PointsHistoryLoading());

    try {
      final response = await Supabase.instance.client
          .from('points_history')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final items = List<Map<String, dynamic>>.from(response);

      int total = 0;
      for (var item in items) {
        total += (item["points"] as num?)?.toInt() ?? 0;
      }

      emit(PointsHistoryLoaded(items, total));
    } catch (e) {
      emit(PointsHistoryError("Failed to load history: $e"));
    }
  }
}
