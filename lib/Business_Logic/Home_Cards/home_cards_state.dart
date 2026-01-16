import 'package:equatable/equatable.dart';
import 'package:docsera/models/home_card_model.dart';

abstract class HomeCardsState extends Equatable {
  const HomeCardsState();

  @override
  List<Object> get props => [];
}

class HomeCardsInitial extends HomeCardsState {}

class HomeCardsLoading extends HomeCardsState {}

class HomeCardsLoaded extends HomeCardsState {
  final List<HomeCardModel> cards;

  const HomeCardsLoaded(this.cards);

  @override
  List<Object> get props => [cards];
}

class HomeCardsError extends HomeCardsState {
  final String message;

  const HomeCardsError(this.message);

  @override
  List<Object> get props => [message];
}
