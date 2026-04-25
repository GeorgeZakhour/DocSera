import 'package:equatable/equatable.dart';
import 'package:docsera/models/offer_model.dart';
import 'package:docsera/models/partner_model.dart';

abstract class PartnerState extends Equatable {
  const PartnerState();
  @override
  List<Object?> get props => [];
}

class PartnerInitial extends PartnerState {
  const PartnerInitial();
}

class PartnerLoading extends PartnerState {
  const PartnerLoading();
}

class PartnerLoaded extends PartnerState {
  final PartnerModel partner;
  final List<OfferModel> offers;

  const PartnerLoaded({required this.partner, required this.offers});

  @override
  List<Object?> get props => [partner, offers];
}

class PartnerError extends PartnerState {
  final String message;
  const PartnerError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Returned when the partner id resolves to no active partner.
class PartnerNotFound extends PartnerState {
  const PartnerNotFound();
}
