import 'package:equatable/equatable.dart';
import 'package:docsera/models/gift.dart';
import 'package:docsera/models/voucher_model.dart';

abstract class VouchersState extends Equatable {
  @override
  List<Object?> get props => [];
}

class VouchersLoading extends VouchersState {}

class VouchersLoaded extends VouchersState {
  final List<VoucherModel> active;
  final List<VoucherModel> used;
  final List<VoucherModel> expired;
  final List<Gift> gifts;

  VouchersLoaded({
    required this.active,
    required this.used,
    required this.expired,
    this.gifts = const [],
  });

  @override
  List<Object?> get props => [active, used, expired, gifts];
}

class VouchersError extends VouchersState {
  final String message;
  VouchersError(this.message);

  @override
  List<Object?> get props => [message];
}
