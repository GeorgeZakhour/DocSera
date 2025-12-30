import 'package:docsera/services/supabase/user/account_danger_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class AccountDangerState {
  const AccountDangerState();
}

class AccountDangerIdle extends AccountDangerState {
  const AccountDangerIdle();
}

class AccountDangerLoading extends AccountDangerState {
  const AccountDangerLoading();
}

class AccountDangerSuccess extends AccountDangerState {
  const AccountDangerSuccess();
}

class AccountDangerError extends AccountDangerState {
  final String message;

  const AccountDangerError(this.message);
}

class AccountDangerCubit extends Cubit<AccountDangerState> {
  final AccountDangerService _service;

  AccountDangerCubit({required AccountDangerService service})
      : _service = service,
        super(const AccountDangerIdle());

  // ---------------------------------------------------------------------------
  // 🗑️ Delete account
  // ---------------------------------------------------------------------------
  Future<void> deleteMyAccount() async {
    try {
      emit(const AccountDangerLoading());
      await _service.deleteMyAccount();
      emit(const AccountDangerSuccess());
    } catch (e) {
      emit(AccountDangerError('Failed to delete account: $e'));
    }
  }

  void reset() {
    emit(const AccountDangerIdle());
  }
}
