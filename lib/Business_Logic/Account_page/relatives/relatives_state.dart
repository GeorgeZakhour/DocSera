part of 'relatives_cubit.dart';

abstract class RelativesState {}

class RelativesInitial extends RelativesState {}
class RelativesLoading extends RelativesState {}

class RelativesLoaded extends RelativesState {
  final List<Map<String, dynamic>> relatives;
  RelativesLoaded(this.relatives);
}

class RelativesError extends RelativesState {
  final String message;
  RelativesError(this.message);
}
