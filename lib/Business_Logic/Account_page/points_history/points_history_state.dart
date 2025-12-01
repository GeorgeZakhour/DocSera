import 'package:equatable/equatable.dart';

abstract class PointsHistoryState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PointsHistoryLoading extends PointsHistoryState {}

class PointsHistoryLoaded extends PointsHistoryState {
  final List<Map<String, dynamic>> items;
  final int totalPoints;

  PointsHistoryLoaded(this.items, this.totalPoints);

  @override
  List<Object?> get props => [items, totalPoints];
}

class PointsHistoryError extends PointsHistoryState {
  final String message;

  PointsHistoryError(this.message);

  @override
  List<Object?> get props => [message];
}
