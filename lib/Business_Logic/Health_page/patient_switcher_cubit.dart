import 'package:flutter_bloc/flutter_bloc.dart';

/// الحالة العامة للـ Patient Switcher:
/// userId = المستخدم الرئيسي
/// relativeId = القريب
/// المهم: واحد منهم فقط يكون NOT NULL
class PatientSwitcherState {
  final String? mainUserId;
  final String? userId;       // null إذا اخترنا قريب
  final String? relativeId;   // null إذا اخترنا المستخدم الرئيسي
  final String patientName;
  final List<Map<String, dynamic>> relatives;

  PatientSwitcherState({
    required this.mainUserId,
    required this.userId,
    required this.relativeId,
    required this.patientName,
    required this.relatives,
  });

  PatientSwitcherState copyWith({
    String? mainUserId,
    String? userId,
    String? relativeId,
    String? patientName,
    List<Map<String, dynamic>>? relatives,
    bool resetRelative = false,
  }) {
    return PatientSwitcherState(
      mainUserId: mainUserId ?? this.mainUserId,
      userId: userId ?? this.userId,
      relativeId: resetRelative ? null : (relativeId ?? this.relativeId),
      patientName: patientName ?? this.patientName,
      relatives: relatives ?? this.relatives,
    );
  }

}

class PatientSwitcherCubit extends Cubit<PatientSwitcherState> {
  PatientSwitcherCubit()
      : super(
    PatientSwitcherState(
      mainUserId: null,   // ← سيتم تعبئتها فور فتح HealthPage
      userId: null,
      relativeId: null,
      patientName: "",
      relatives: [],
    ),
  );


  /// عند تحميل بيانات المستخدم الرئيسي
  void setMainUser(String id, String name) {
    emit(
      state.copyWith(
        mainUserId: id,
        userId: id,
        relativeId: null,
        patientName: name,
      ),
    );
  }


  void switchToUser(String id, String name) {
    print("👤 switchToUser → id=$id name=$name");

    emit(
      state.copyWith(
        userId: id,
        patientName: name,
        resetRelative: true,   // ← هذا يمسح relativeId
      ),
    );

    print("👉 NEW STATE (User) → userId=${state.userId} relativeId=${state.relativeId}");
  }


  void switchToRelative(String id, String name) {
    print("👤 switchToRelative → id=$id name=$name");

    emit(
      state.copyWith(
        userId: null,
        relativeId: id,
        patientName: name,
        resetRelative: false,
      ),
    );

    print("👉 NEW STATE (Relative) → userId=${state.userId} relativeId=${state.relativeId}");
  }




  void updateRelatives(List<Map<String, dynamic>> newList) {
    emit(state.copyWith(relatives: newList));
  }
}
