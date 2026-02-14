import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/critical_alert_payload.dart';

class CriticalAlertState extends Equatable {
  final bool isRinging;
  final CriticalAlertPayload? payload;

  const CriticalAlertState({
    required this.isRinging,
    required this.payload,
  });

  factory CriticalAlertState.idle() => const CriticalAlertState(
        isRinging: false,
        payload: null,
      );

  CriticalAlertState copyWith({
    bool? isRinging,
    CriticalAlertPayload? payload,
  }) {
    return CriticalAlertState(
      isRinging: isRinging ?? this.isRinging,
      payload: payload ?? this.payload,
    );
  }

  @override
  List<Object?> get props => [isRinging, payload];
}

class CriticalAlertCubit extends Cubit<CriticalAlertState> {
  CriticalAlertCubit() : super(CriticalAlertState.idle());

  void startRinging(CriticalAlertPayload payload) {
    emit(CriticalAlertState(isRinging: true, payload: payload));
  }

  void stopRinging() {
    emit(CriticalAlertState.idle());
  }
}
