import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'critical_alert.dart';

enum CriticalAlertStatus { idle, ringing, navigating }

class CriticalAlertState extends Equatable {
  final CriticalAlertStatus status;
  final CriticalAlertPayload? activeAlert;

  const CriticalAlertState({
    required this.status,
    this.activeAlert,
  });

  const CriticalAlertState.idle()
      : status = CriticalAlertStatus.idle,
        activeAlert = null;

  bool get hasActiveAlert => activeAlert != null;

  @override
  List<Object?> get props => [status, activeAlert?.eventId];
}

class CriticalAlertCubit extends Cubit<CriticalAlertState> {
  final AudioPlayer _ringPlayer = AudioPlayer();
  final Queue<String> _recentEventIds = Queue<String>();
  static const int _maxRecentIds = 30;

  CriticalAlertCubit() : super(const CriticalAlertState.idle()) {
    _ringPlayer.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> ingest(Map<String, dynamic> data, {bool suppressLocalRing = false}) async {
    final payload = CriticalAlertPayload.fromData(data);
    if (!payload.isCritical) return;
    if (_isDuplicate(payload.eventId)) return;

    if (!suppressLocalRing) {
      await _startRinging();
    }
    emit(CriticalAlertState(
      status: CriticalAlertStatus.ringing,
      activeAlert: payload,
    ));
  }

  Future<void> markNavigating() async {
    if (!state.hasActiveAlert) return;
    emit(CriticalAlertState(
      status: CriticalAlertStatus.navigating,
      activeAlert: state.activeAlert,
    ));
  }

  Future<void> stopRinging() async {
    try {
      await _ringPlayer.stop();
    } catch (_) {
      // Best-effort stop.
    }
  }

  Future<void> clearActiveAlert() async {
    await stopRinging();
    emit(const CriticalAlertState.idle());
  }

  Future<void> _startRinging() async {
    try {
      await _ringPlayer.stop();
      await _ringPlayer.play(BytesSource(_buildAlertToneWav()));
    } catch (_) {
      // Keep flow functional even when ringtone cannot start.
    }
  }

  Uint8List _buildAlertToneWav() {
    const sampleRate = 16000;
    const seconds = 1;
    const samples = sampleRate * seconds;
    const frequency = 880.0;
    const amplitude = 0.35;

    final pcmData = Int16List(samples);
    for (var i = 0; i < samples; i++) {
      final t = i / sampleRate;
      final wave = math.sin(2 * math.pi * frequency * t);
      final envelope = (i % 2000) < 1400 ? 1.0 : 0.0;
      pcmData[i] = (wave * envelope * amplitude * 32767).toInt();
    }

    final byteData = ByteData(44 + samples * 2);
    void writeString(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        byteData.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeString(0, 'RIFF');
    byteData.setUint32(4, 36 + samples * 2, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little);
    byteData.setUint16(22, 1, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);
    writeString(36, 'data');
    byteData.setUint32(40, samples * 2, Endian.little);

    var offset = 44;
    for (final sample in pcmData) {
      byteData.setInt16(offset, sample, Endian.little);
      offset += 2;
    }

    return byteData.buffer.asUint8List();
  }

  bool _isDuplicate(String eventId) {
    if (_recentEventIds.contains(eventId)) {
      return true;
    }
    _recentEventIds.add(eventId);
    if (_recentEventIds.length > _maxRecentIds) {
      _recentEventIds.removeFirst();
    }
    return false;
  }

  @override
  Future<void> close() async {
    await _ringPlayer.dispose();
    return super.close();
  }
}
