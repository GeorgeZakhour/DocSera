import 'package:equatable/equatable.dart';
import 'package:docsera/models/referral_model.dart';

abstract class ReferralState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ReferralLoading extends ReferralState {}

class ReferralLoaded extends ReferralState {
  final ReferralInfo info;

  ReferralLoaded(this.info);

  @override
  List<Object?> get props => [info];
}

class ReferralError extends ReferralState {
  final String message;
  ReferralError(this.message);

  @override
  List<Object?> get props => [message];
}
