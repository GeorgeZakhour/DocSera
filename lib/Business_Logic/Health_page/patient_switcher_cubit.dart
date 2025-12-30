import 'package:flutter_bloc/flutter_bloc.dart';

/// Patient Switcher State
/// ---------------------------------------------------------------------------
/// - mainUserId     : ID المستخدم الأساسي (ثابت طوال الجلسة)
/// - mainUserName   : اسم المستخدم الأساسي (ثابت ولا يتغير)
///
/// - userId         : يُستخدم عندما يكون المستخدم الأساسي هو المختار
/// - relativeId     : يُستخدم عندما يكون قريب هو المختار
///
/// - patientName    : الاسم المعروض حاليًا (يتغير حسب الاختيار)
/// ---------------------------------------------------------------------------
class PatientSwitcherState {
  final String? mainUserId;
  final String mainUserName;

  final String? userId;       // null إذا كان المختار قريب
  final String? relativeId;   // null إذا كان المختار المستخدم الأساسي

  final String patientName;

  const PatientSwitcherState({
    required this.mainUserId,
    required this.mainUserName,
    required this.userId,
    required this.relativeId,
    required this.patientName,
  });

  PatientSwitcherState copyWith({
    String? mainUserId,
    String? mainUserName,
    String? userId,
    String? relativeId,
    String? patientName,
    bool resetRelative = false,
  }) {
    return PatientSwitcherState(
      mainUserId: mainUserId ?? this.mainUserId,
      mainUserName: mainUserName ?? this.mainUserName,
      userId: userId ?? this.userId,
      relativeId: resetRelative ? null : (relativeId ?? this.relativeId),
      patientName: patientName ?? this.patientName,
    );
  }
}

class PatientSwitcherCubit extends Cubit<PatientSwitcherState> {
  PatientSwitcherCubit()
      : super(
    const PatientSwitcherState(
      mainUserId: null,
      mainUserName: "",
      userId: null,
      relativeId: null,
      patientName: "",
    ),
  );

  // ---------------------------------------------------------------------------
  // INITIAL SET — called once after Auth success
  // ---------------------------------------------------------------------------
  void setMainUser({
    required String id,
    required String name,
  }) {
    emit(
      PatientSwitcherState(
        mainUserId: id,
        mainUserName: name,
        userId: id,
        relativeId: null,
        patientName: name, // البداية دائمًا المستخدم الأساسي
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SWITCH TO MAIN USER
  // ---------------------------------------------------------------------------
  void switchToUser() {
    if (state.mainUserId == null) return;

    emit(
      state.copyWith(
        userId: state.mainUserId,
        relativeId: null,
        patientName: state.mainUserName,
        resetRelative: true,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SWITCH TO RELATIVE
  // ---------------------------------------------------------------------------
  void switchToRelative({
    required String relativeId,
    required String relativeName,
  }) {
    emit(
      state.copyWith(
        userId: null,
        relativeId: relativeId,
        patientName: relativeName,
      ),
    );
  }
}
