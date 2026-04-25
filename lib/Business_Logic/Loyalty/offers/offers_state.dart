import 'package:equatable/equatable.dart';
import 'package:docsera/models/offer_model.dart';

abstract class OffersState extends Equatable {
  @override
  List<Object?> get props => [];
}

class OffersLoading extends OffersState {}

class OffersLoaded extends OffersState {
  final List<OfferModel> allOffers;

  OffersLoaded({required this.allOffers});

  @override
  List<Object?> get props => [allOffers];
}

class OffersError extends OffersState {
  final String message;
  OffersError(this.message);

  @override
  List<Object?> get props => [message];
}

class OfferRedeemLoading extends OffersState {}

class OfferRedeemSuccess extends OffersState {
  final String voucherCode;
  final String expiresAt;

  OfferRedeemSuccess({required this.voucherCode, required this.expiresAt});

  @override
  List<Object?> get props => [voucherCode, expiresAt];
}

class OfferRedeemError extends OffersState {
  final String error;
  OfferRedeemError(this.error);

  @override
  List<Object?> get props => [error];
}
