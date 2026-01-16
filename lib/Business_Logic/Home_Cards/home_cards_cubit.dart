import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:docsera/models/home_card_model.dart';
import 'package:docsera/services/supabase/home_cards/supabase_home_card_service.dart';
import 'home_cards_state.dart';

class HomeCardsCubit extends Cubit<HomeCardsState> {
  final SupabaseHomeCardService _service;

  HomeCardsCubit(this._service) : super(HomeCardsInitial());

  Future<void> loadHomeCards() async {
    try {
      emit(HomeCardsLoading());
      final cards = await _service.getActiveHomeCards();
      emit(HomeCardsLoaded(cards));
    } catch (e) {
      emit(HomeCardsError("Failed to load cards: ${e.toString()}"));
    }
  }
}
