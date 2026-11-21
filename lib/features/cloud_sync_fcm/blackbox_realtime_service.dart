import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../firebase_options.dart';
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

  BlackboxCloudRecord copyWith({
    bool? syncedToFirebase,
  }) {
    return BlackboxCloudRecord(
      sessionId: sessionId,
      peakRpm: peakRpm,
      maxSpeedKmh: maxSpeedKmh,
      maxCoolantTempC: maxCoolantTempC,
      zeroToHundredSec: zeroToHundredSec,
      dtcCount: dtcCount,
      syncedAt: syncedAt,
      syncedToFirebase: syncedToFirebase ?? this.syncedToFirebase,
    );
  }

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

/// Estado auxiliar de sincronización en vivo con Firebase Realtime Database
class BlackboxSyncMeta {
  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  const BlackboxSyncMeta({
    this.isSyncing = false,
    this.lastSyncedAt,
    this.errorMessage,
  });

  BlackboxSyncMeta copyWith({
    bool? isSyncing,
    DateTime? lastSyncedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BlackboxSyncMeta(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class BlackboxSyncMetaNotifier extends Notifier<BlackboxSyncMeta> {
  @override
  BlackboxSyncMeta build() => const BlackboxSyncMeta();

  void setSyncing() {
    state = state.copyWith(isSyncing: true, clearError: true);
  }

  void setSuccess() {
    state = state.copyWith(
      isSyncing: false,
      lastSyncedAt: DateTime.now(),
      clearError: true,
    );
  }

  void setError(String message) {
    state = state.copyWith(isSyncing: false, errorMessage: message);
  }
}

final blackboxSyncMetaProvider =
    NotifierProvider<BlackboxSyncMetaNotifier, BlackboxSyncMeta>(
  BlackboxSyncMetaNotifier.new,
);

/// Controlador de Blackbox Cloud: sincroniza automáticamente al abrir la app o iniciar
/// sesión, mantiene escucha en tiempo real entre dispositivos (tablet / teléfono) y
/// respalda en caché local offline por cuenta.
class BlackboxRealtimeNotifier extends Notifier<List<BlackboxCloudRecord>> {
  static const String _legacyLocalCacheKey = 'clio_rs_blackbox_history';

  StreamSubscription<DatabaseEvent>? _rtdbSubscription;
  int _syncGeneration = 0;
  bool _disposed = false;

  String _cacheKeyForUid(String uid) => 'clio_rs_blackbox_history_$uid';

  bool _isActive(int gen) => !_disposed && gen == _syncGeneration;

  FirebaseDatabase? _getDatabase() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: DefaultFirebaseOptions.android.databaseURL,
      );
    } catch (_) {
      return null;
    }
  }

  String? _resolveUid() {
    final pilotUid = ref.read(pilotAuthProvider)?.uid;
    if (pilotUid != null && pilotUid.isNotEmpty) return pilotUid;
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance.currentUser?.uid;
      }
    } catch (_) {}
    return null;
  }

  @override
  List<BlackboxCloudRecord> build() {
    final watchedUid = ref.watch(pilotAuthProvider.select((p) => p?.uid));
    var uid = watchedUid;
    if (uid == null) {
      try {
        if (Firebase.apps.isNotEmpty) {
          uid = FirebaseAuth.instance.currentUser?.uid;
        }
      } catch (_) {}
    }

    final gen = ++_syncGeneration;
    _disposed = false;

    ref.onDispose(() {
      _disposed = true;
      _rtdbSubscription?.cancel();
      _rtdbSubscription = null;
    });

    _rtdbSubscription?.cancel();
    _rtdbSubscription = null;

    if (uid != null && uid.isNotEmpty) {
      final activeUid = uid;
      Future.microtask(() => _initializeAndSyncForUser(activeUid, gen));
    }

    return const <BlackboxCloudRecord>[];
  }

  Future<void> _initializeAndSyncForUser(String uid, int gen) async {
    final localMap = await _loadLocalRecordsForUid(uid);
    if (!_isActive(gen)) return;

    if (localMap.isNotEmpty) {
      final localSorted = _sortRecords(localMap.values);
      state = localSorted;
    }

    await _syncBidirectionalWithCloud(uid, gen, seedLocalMap: localMap);
    if (!_isActive(gen)) return;

    final db = _getDatabase();
    if (db == null) return;

    _rtdbSubscription?.cancel();
    _rtdbSubscription = db.ref('blackbox_sessions/$uid').onValue.listen(
      (DatabaseEvent event) async {
        if (!_isActive(gen)) return;
        await _handleRemoteSnapshot(uid, gen, event.snapshot);
      },
      onError: (_) {},
    );
  }

  Future<Map<String, BlackboxCloudRecord>> _loadLocalRecordsForUid(
    String uid,
  ) async {
    final map = <String, BlackboxCloudRecord>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = _cacheKeyForUid(uid);
      var raw = prefs.getStringList(userKey);

      if (raw == null) {
        final legacyRaw = prefs.getStringList(_legacyLocalCacheKey);
        if (legacyRaw != null && legacyRaw.isNotEmpty) {
          raw = legacyRaw;
          await prefs.setStringList(userKey, legacyRaw);
          await prefs.remove(_legacyLocalCacheKey);
        }
      }

      if (raw != null) {
        for (final entry in raw) {
          final decoded = jsonDecode(entry);
          if (decoded is Map<String, dynamic>) {
            final rec = BlackboxCloudRecord.fromJson(decoded);
            map[rec.sessionId] = rec;
          }
        }
      }
    } catch (_) {}
    return map;
  }

  Map<String, BlackboxCloudRecord> _parseSnapshotRecords(
    DataSnapshot snapshot,
  ) {
    final result = <String, BlackboxCloudRecord>{};
    if (!snapshot.exists || snapshot.value is! Map) {
      return result;
    }
    final rawMap = snapshot.value as Map<dynamic, dynamic>;
    for (final entry in rawMap.entries) {
      if (entry.value is! Map) continue;
      final itemMap = entry.value as Map<dynamic, dynamic>;
      final data = <String, dynamic>{
        for (final kv in itemMap.entries) kv.key.toString(): kv.value,
      };
      data['sessionId'] ??= entry.key.toString();
      data['syncedToFirebase'] = true;
      final dtcs = data['dtcs'];
      if (dtcs is List) {
        data['dtcCount'] = dtcs.length;
      }
      final rec = BlackboxCloudRecord.fromJson(data);
      result[rec.sessionId] = rec;
    }
    return result;
  }

  Map<String, dynamic> _recordToRemotePayload(
    BlackboxCloudRecord rec, {
    List<Map<String, dynamic>>? dtcsJson,
  }) {
    return <String, dynamic>{
      'sessionId': rec.sessionId,
      'vin': 'VF1CB1N0F31040172',
      'ecu': 'Siemens Sirius 34 (KWP2000)',
      'peakRpm': rec.peakRpm.round(),
      'maxSpeedKmh': rec.maxSpeedKmh,
      'maxCoolantTempC': rec.maxCoolantTempC,
      'zeroToHundredSec': rec.zeroToHundredSec,
      'dtcCount': rec.dtcCount,
      if (dtcsJson != null) 'dtcs': dtcsJson,
      'syncedAt': rec.syncedAt.toIso8601String(),
    };
  }

  Future<void> _syncBidirectionalWithCloud(
    String uid,
    int gen, {
    Map<String, BlackboxCloudRecord>? seedLocalMap,
  }) async {
    final db = _getDatabase();
    if (db == null) return;

    ref.read(blackboxSyncMetaProvider.notifier).setSyncing();
    final localMap = seedLocalMap ?? await _loadLocalRecordsForUid(uid);
    if (!_isActive(gen)) return;

    try {
      final snapshot = await db
          .ref('blackbox_sessions/$uid')
          .get()
          .timeout(const Duration(seconds: 10));
      if (!_isActive(gen)) return;

      final merged = _parseSnapshotRecords(snapshot);

      // Subir sesiones creadas offline en este dispositivo que aún no estén en Firebase
      for (final localRec in localMap.values) {
        if (!localRec.syncedToFirebase && !merged.containsKey(localRec.sessionId)) {
          try {
            await db
                .ref('blackbox_sessions/$uid/${localRec.sessionId}')
                .set(_recordToRemotePayload(localRec))
                .timeout(const Duration(seconds: 8));
            merged[localRec.sessionId] = localRec.copyWith(syncedToFirebase: true);
          } catch (_) {
            merged[localRec.sessionId] = localRec;
          }
        }
      }

      if (!_isActive(gen)) return;
      final sorted = _sortRecords(merged.values);
      state = sorted;
      await _persistLocalForUid(uid, sorted);
      ref.read(blackboxSyncMetaProvider.notifier).setSuccess();
    } catch (e) {
      if (!_isActive(gen)) return;
      ref.read(blackboxSyncMetaProvider.notifier).setError(
            'Error al sincronizar con Firebase: $e',
          );
    }
  }

  Future<void> _handleRemoteSnapshot(
    String uid,
    int gen,
    DataSnapshot snapshot,
  ) async {
    if (!_isActive(gen)) return;
    final merged = _parseSnapshotRecords(snapshot);

    for (final localRec in state) {
      if (!localRec.syncedToFirebase && !merged.containsKey(localRec.sessionId)) {
        merged[localRec.sessionId] = localRec;
      }
    }

    final sorted = _sortRecords(merged.values);
    state = sorted;
    await _persistLocalForUid(uid, sorted);
    ref.read(blackboxSyncMetaProvider.notifier).setSuccess();
  }

  List<BlackboxCloudRecord> _sortRecords(Iterable<BlackboxCloudRecord> items) {
    final list = items.toList()
      ..sort((a, b) => b.syncedAt.compareTo(a.syncedAt));
    return list.take(50).toList();
  }

  Future<void> refreshFromCloud() async {
    final uid = _resolveUid();
    if (uid == null || uid.isEmpty) return;
    await _syncBidirectionalWithCloud(uid, _syncGeneration);
  }

  /// Guarda los picos actuales de la sesión (RPM máx, Vel máx, Temp máx, 0-100 y DTCs)
  Future<void> syncCurrentSessionToCloud() async {
    final stats = ref.read(telemetrySessionStatsProvider);
    final dtcs =
        ref.read(sirius34DtcProvider).valueOrNull ?? const <Sirius34DtcFault>[];
    final uid = _resolveUid() ?? 'anonymous-rs172';
    final now = DateTime.now();
    final sessionId =
        'RS172-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final draftRecord = BlackboxCloudRecord(
      sessionId: sessionId,
      peakRpm: stats.peakRpm,
      maxSpeedKmh: stats.maxSpeedKmh,
      maxCoolantTempC: stats.maxCoolantTempC,
      zeroToHundredSec: stats.bestZeroToHundredSec,
      dtcCount: dtcs.length,
      syncedAt: now,
      syncedToFirebase: false,
    );

    var remoteSuccess = false;
    final db = _getDatabase();
    if (db != null && uid != 'anonymous-rs172') {
      try {
        final payload = _recordToRemotePayload(
          draftRecord,
          dtcsJson: dtcs.map((d) => d.toJson()).toList(),
        );
        await db
            .ref('blackbox_sessions/$uid/$sessionId')
            .set(payload)
            .timeout(const Duration(seconds: 8));
        remoteSuccess = true;
      } catch (_) {
        remoteSuccess = false;
      }
    }

    final finalRecord = draftRecord.copyWith(syncedToFirebase: remoteSuccess);
    final updated = _sortRecords(<BlackboxCloudRecord>[
      finalRecord,
      ...state.where((r) => r.sessionId != sessionId),
    ]);
    state = updated;
    await _persistLocalForUid(uid, updated);
    if (remoteSuccess) {
      ref.read(blackboxSyncMetaProvider.notifier).setSuccess();
    }
  }

  Future<void> deleteSession(String sessionId) async {
    final uid = _resolveUid() ?? 'anonymous-rs172';
    final updated =
        state.where((element) => element.sessionId != sessionId).toList();
    state = updated;
    await _persistLocalForUid(uid, updated);

    try {
      final db = _getDatabase();
      if (db != null && uid != 'anonymous-rs172') {
        await db
            .ref('blackbox_sessions/$uid/$sessionId')
            .remove()
            .timeout(const Duration(seconds: 6));
      }
    } catch (_) {}
  }

  Future<void> _persistLocalForUid(
    String uid,
    List<BlackboxCloudRecord> list,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _cacheKeyForUid(uid),
        list.map((r) => jsonEncode(r.toJson())).toList(),
      );
    } catch (_) {}
  }
}

final blackboxRealtimeProvider =
    NotifierProvider<BlackboxRealtimeNotifier, List<BlackboxCloudRecord>>(
  BlackboxRealtimeNotifier.new,
);
