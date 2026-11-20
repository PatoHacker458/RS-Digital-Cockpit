import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_profile/providers/auth_profile_providers.dart';
import '../telemetry/models/obd_telemetry_frame.dart';
import '../telemetry/providers/telemetry_providers.dart';

/// Registro de sesión de telemetría guardado en Blackbox Cloud (Firebase Realtime DB + Local)
class BlackboxCloudRecord {
  final String sessionId;
  final double peakRpm;
  final int maxSpeedKmh;
  final double maxCoolantTempC;
  final double? zeroToHundredSec;
  final int dtcCount;
  final DateTime syncedAt;
  final bool syncedToFirebase;

  const BlackboxCloudRecord({
    required this.sessionId,
    required this.peakRpm,
    required this.maxSpeedKmh,
    required this.maxCoolantTempC,
    this.zeroToHundredSec,
    required this.dtcCount,
    required this.syncedAt,
    required this.syncedToFirebase,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sessionId': sessionId,
        'peakRpm': peakRpm,
        'maxSpeedKmh': maxSpeedKmh,
        'maxCoolantTempC': maxCoolantTempC,
        'zeroToHundredSec': zeroToHundredSec,
        'dtcCount': dtcCount,
        'syncedAt': syncedAt.toIso8601String(),
        'syncedToFirebase': syncedToFirebase,
      };

  factory BlackboxCloudRecord.fromJson(Map<String, dynamic> map) {
    return BlackboxCloudRecord(
      sessionId: map['sessionId'] as String? ?? 'RS172-SESION',
      peakRpm: (map['peakRpm'] as num?)?.toDouble() ?? 0.0,
      maxSpeedKmh: (map['maxSpeedKmh'] as num?)?.toInt() ?? 0,
      maxCoolantTempC: (map['maxCoolantTempC'] as num?)?.toDouble() ?? 0.0,
      zeroToHundredSec: (map['zeroToHundredSec'] as num?)?.toDouble(),
      dtcCount: (map['dtcCount'] as num?)?.toInt() ?? 0,
      syncedAt:
          DateTime.tryParse(map['syncedAt'] as String? ?? '') ?? DateTime.now(),
      syncedToFirebase: map['syncedToFirebase'] as bool? ?? false,
    );
  }
}

/// Controlador de Blackbox Cloud: guarda, carga desde Firebase/caché y permite revisar
/// o eliminar sesiones de telemetría registradas en el auto.
class BlackboxRealtimeNotifier extends Notifier<List<BlackboxCloudRecord>> {
  static const String _localCacheKey = 'clio_rs_blackbox_history';

  @override
  List<BlackboxCloudRecord> build() {
    _loadHistoryFromCacheAndCloud();
    return const <BlackboxCloudRecord>[];
  }

  Future<void> _loadHistoryFromCacheAndCloud() async {
    final merged = <String, BlackboxCloudRecord>{};

    // 1. Cargar caché local offline
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_localCacheKey);
      if (raw != null) {
        for (final entry in raw) {
          final rec = BlackboxCloudRecord.fromJson(
            jsonDecode(entry) as Map<String, dynamic>,
          );
          merged[rec.sessionId] = rec;
        }
      }
    } catch (_) {}

    // 2. Sincronizar desde Firebase Realtime Database si el piloto está autenticado
    try {
      final pilot = ref.read(pilotAuthProvider);
      if (pilot != null) {
        final snapshot = await FirebaseDatabase.instance
            .ref('blackbox_sessions/${pilot.uid}')
            .get()
            .timeout(const Duration(seconds: 4));
        if (snapshot.exists && snapshot.value is Map) {
          final map = Map<dynamic, dynamic>.from(snapshot.value as Map);
          for (final item in map.values) {
            if (item is Map) {
              final data = Map<String, dynamic>.from(item);
              data['syncedToFirebase'] = true;
              final dtcs = data['dtcs'];
              if (dtcs is List) {
                data['dtcCount'] = dtcs.length;
              }
              final rec = BlackboxCloudRecord.fromJson(data);
              merged[rec.sessionId] = rec;
            }
          }
        }
      }
    } catch (_) {}

    final sorted = merged.values.toList()
      ..sort((a, b) => b.syncedAt.compareTo(a.syncedAt));
    state = sorted;
    await _persistLocal(sorted);
  }

  Future<void> refreshFromCloud() => _loadHistoryFromCacheAndCloud();

  /// Guarda los picos actuales de la sesión (RPM máx, Vel máx, Temp máx, 0-100 y DTCs)
  Future<void> syncCurrentSessionToCloud() async {
    final stats = ref.read(telemetrySessionStatsProvider);
    final dtcs =
        ref.read(sirius34DtcProvider).valueOrNull ?? const <Sirius34DtcFault>[];
    final pilot = ref.read(pilotAuthProvider);
    final uid = pilot?.uid ?? 'anonymous-rs172';
    final now = DateTime.now();
    final sessionId =
        'RS172-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    var remoteSuccess = false;
    final payload = <String, dynamic>{
      'sessionId': sessionId,
      'vin': 'VF1CB1N0F31040172',
      'ecu': 'Siemens Sirius 34 (KWP2000)',
      'peakRpm': stats.peakRpm.round(),
      'maxSpeedKmh': stats.maxSpeedKmh,
      'maxCoolantTempC': stats.maxCoolantTempC,
      'zeroToHundredSec': stats.bestZeroToHundredSec,
      'dtcCount': dtcs.length,
      'dtcs': dtcs.map((d) => d.toJson()).toList(),
      'syncedAt': now.toIso8601String(),
    };

    try {
      final dbRef =
          FirebaseDatabase.instance.ref('blackbox_sessions/$uid/$sessionId');
      await dbRef.set(payload).timeout(const Duration(seconds: 4));
      remoteSuccess = true;
    } catch (_) {
      remoteSuccess = false;
    }

    final record = BlackboxCloudRecord(
      sessionId: sessionId,
      peakRpm: stats.peakRpm,
      maxSpeedKmh: stats.maxSpeedKmh,
      maxCoolantTempC: stats.maxCoolantTempC,
      zeroToHundredSec: stats.bestZeroToHundredSec,
      dtcCount: dtcs.length,
      syncedAt: now,
      syncedToFirebase: remoteSuccess,
    );

    final updated = <BlackboxCloudRecord>[record, ...state.take(29)];
    state = updated;
    await _persistLocal(updated);
  }

  Future<void> deleteSession(String sessionId) async {
    final updated =
        state.where((element) => element.sessionId != sessionId).toList();
    state = updated;
    await _persistLocal(updated);

    try {
      final pilot = ref.read(pilotAuthProvider);
      if (pilot != null) {
        await FirebaseDatabase.instance
            .ref('blackbox_sessions/${pilot.uid}/$sessionId')
            .remove()
            .timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
  }

  Future<void> _persistLocal(List<BlackboxCloudRecord> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _localCacheKey,
        list.map((r) => jsonEncode(r.toJson())).toList(),
      );
    } catch (_) {}
  }
}

final blackboxRealtimeProvider =
    NotifierProvider<BlackboxRealtimeNotifier, List<BlackboxCloudRecord>>(
  BlackboxRealtimeNotifier.new,
);
