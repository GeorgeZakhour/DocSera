import 'package:equatable/equatable.dart';
import 'package:docsera/services/supabase/storage_quota_service.dart';

abstract class StorageQuotaState extends Equatable {
  const StorageQuotaState();

  @override
  List<Object?> get props => [];
}

class StorageQuotaInitial extends StorageQuotaState {
  const StorageQuotaInitial();
}

class StorageQuotaLoading extends StorageQuotaState {
  const StorageQuotaLoading();
}

class StorageQuotaLoaded extends StorageQuotaState {
  final StorageQuotaResult quota;

  const StorageQuotaLoaded(this.quota);

  @override
  List<Object?> get props => [quota];
}

class StorageQuotaError extends StorageQuotaState {
  final String message;

  const StorageQuotaError(this.message);

  @override
  List<Object?> get props => [message];
}
