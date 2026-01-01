import 'package:docsera/services/supabase/user/account_relatives_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'relatives_state.dart';

class RelativesCubit extends Cubit<RelativesState> {
  final AccountRelativesService _service;

  RelativesCubit(this._service) : super(RelativesInitial());

  List<Map<String, dynamic>> _cachedRelatives = [];

  Future<void> loadRelatives() async {
    emit(RelativesLoading());
    try {
      final relatives = await _service.getMyRelatives();
      _cachedRelatives = relatives;
      emit(RelativesLoaded(_cachedRelatives));
    } catch (e) {
      emit(RelativesError(e.toString()));
    }
  }

  Future<void> addRelative(Map<String, dynamic> data) async {
    try {
      await _service.addRelative(data);
      await loadRelatives(); // 🔁 refresh
    } catch (e) {
      emit(RelativesError(e.toString()));
    }
  }

  Future<void> updateRelative(String id, Map<String, dynamic> data) async {
    try {
      debugPrint('🟠 CUBIT → updateRelative called');
      debugPrint('🟠 CUBIT → id = $id');
      debugPrint('🟠 CUBIT → data = $data');

      final updated = await _service.updateRelative(id, data);

      debugPrint('🟠 CUBIT → updated returned = $updated');

      _cachedRelatives = _cachedRelatives.map((r) {
        debugPrint('🟠 comparing ${r['id']} with ${updated['id']}');
        return r['id'] == updated['id'] ? updated : r;
      }).toList();

      emit(RelativesLoaded(_cachedRelatives));
    } catch (e, st) {
      debugPrint('🔴 CUBIT ERROR = $e');
      debugPrint(st.toString());
      emit(RelativesError(e.toString()));
    }
  }


  // ✅ الجديد (Soft delete)
  Future<void> deactivateRelative(String id) async {
    try {
      await _service.deactivateRelative(id);

      // 👇 إخفاؤه من UI كأنه محذوف
      _cachedRelatives =
          _cachedRelatives.where((r) => r['id'] != id).toList();

      emit(RelativesLoaded(_cachedRelatives));
    } catch (e) {
      emit(RelativesError(e.toString()));
    }
  }

  Future<bool> isPhoneDuplicate(String phone) async {
    return await _service.isPhoneExists(phone);
  }

  Future<bool> isEmailDuplicate(String email) async {
    return await _service.isEmailExists(email);
  }

}
