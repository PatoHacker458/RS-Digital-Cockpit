import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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

class _RtdbRestResponse {
  final int statusCode;
  final dynamic data;
  const _RtdbRestResponse(this.statusCode, this.data);
}

/// Controlador de Blackbox Cloud: sincroniza automáticamente al abrir la app o iniciar
/// sesión, detecta la región activa de Realtime Database sin colgarse en timeouts,
/// mantiene escucha en tiempo real entre dispositivos (tablet / teléfono) y respalda en local.
class BlackboxRealtimeNotifier extends Notifier<List<BlackboxCloudRecord>> {
  static const String _legacyLocalCacheKey = 'clio_rs_blackbox_history';
  static const List<String> _candidateDbUrls = <String>[
    'https://rs-digital-cockpit-default-rtdb.firebaseio.com',
    'https://rs-digital-cockpit-default-rtdb.us-central1.firebasedatabase.app',
    'https://rs-digital-cockpit-default-rtdb.europe-west1.firebasedatabase.app',
    'https://rs-digital-cockpit-default-rtdb.asia-southeast1.firebasedatabase.app',
  ];

  StreamSubscription<DatabaseEvent>? _rtdbSubscription;
  String? _resolvedDbUrl;
  int _syncGeneration = 0;
  bool _disposed = false;

  String _cacheKeyForUid(String uid) => 'clio_rs_blackbox_history_$uid';

  bool _isActive(int gen) => !_disposed && gen == _syncGeneration;

  FirebaseDatabase? _getDatabaseForUrl(String url) {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: url,
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

  Future<String?> _getFirebaseIdToken() async {
    try {
      if (Firebase.apps.isEmpty) return null;
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
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
      state = _sortRecords(localMap.values);
    }

    await _syncBidirectionalWithCloud(uid, gen, seedLocalMap: localMap);
  }

  void _attachLiveListener(String uid, int gen, String dbUrl) {
    if (!_isActive(gen)) return;
    final db = _getDatabaseForUrl(dbUrl);
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

  Map<String, BlackboxCloudRecord> _parseRawDynamicMap(dynamic rawValue) {
    final result = <String, BlackboxCloudRecord>{};
    if (rawValue is! Map) return result;
    for (final entry in rawValue.entries) {
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

  Future<_RtdbRestResponse?> _restRequest(
    String method,
    String baseUrl,
    String path, {
    String? idToken,
    Object? body,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final cleanBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final authQuery = (idToken != null && idToken.isNotEmpty)
          ? '?auth=${Uri.encodeQueryComponent(idToken)}'
          : '';
      final uri = Uri.parse('$cleanBase/$path.json$authQuery');
      final req = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 5));
      req.headers.set('Accept', 'application/json');
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final resp = await req.close().timeout(const Duration(seconds: 6));
      final text = await resp
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 6));
      dynamic decoded;
      if (text.trim().isNotEmpty) {
        try {
          decoded = jsonDecode(text);
        } catch (_) {
          decoded = text;
        }
      }
      return _RtdbRestResponse(resp.statusCode, decoded);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<(String?, _RtdbRestResponse?)> _probeActiveDatabase(
    String uid, {
    String? idToken,
  }) async {
    final urls = _resolvedDbUrl != null
        ? <String>[_resolvedDbUrl!]
        : _candidateDbUrls;

    final responses = await Future.wait(
      urls.map(
        (url) async => (
          url,
          await _restRequest(
            'GET',
            url,
            'blackbox_sessions/$uid',
            idToken: idToken,
          ),
        ),
      ),
    );

    for (final (url, resp) in responses) {
      if (resp != null && resp.statusCode == 200) {
        _resolvedDbUrl = url;
        return (url, resp);
      }
    }

    for (final (url, resp) in responses) {
      if (resp != null && (resp.statusCode == 401 || resp.statusCode == 403)) {
        _resolvedDbUrl = url;
        return (url, resp);
      }
    }

    for (final (url, resp) in responses) {
      if (resp != null) {
        return (url, resp);
      }
    }

    return (null, null);
  }

  Future<void> _syncBidirectionalWithCloud(
    String uid,
    int gen, {
    Map<String, BlackboxCloudRecord>? seedLocalMap,
  }) async {
    if (Firebase.apps.isEmpty) return;

    ref.read(blackboxSyncMetaProvider.notifier).setSyncing();
    final localMap = seedLocalMap ?? await _loadLocalRecordsForUid(uid);
    if (!_isActive(gen)) return;

    final idToken = await _getFirebaseIdToken();
    if (!_isActive(gen)) return;

    final (resolvedUrl, remoteResp) =
        await _probeActiveDatabase(uid, idToken: idToken);
    if (!_isActive(gen)) return;

    if (remoteResp == null) {
      ref.read(blackboxSyncMetaProvider.notifier).setError(
            'Sin conexión a internet o servidor Firebase no disponible.',
          );
      return;
    }

    if (remoteResp.statusCode == 401 || remoteResp.statusCode == 403) {
      ref.read(blackboxSyncMetaProvider.notifier).setError(
            'Permiso denegado en Firebase Realtime Database (revisa Rules en Firebase Console).',
          );
      return;
    }

    if (remoteResp.statusCode == 404) {
      _resolvedDbUrl = null;
      ref.read(blackboxSyncMetaProvider.notifier).setError(
            'Falta crear Realtime Database en Firebase Console (proyecto rs-digital-cockpit).',
          );
      return;
    }

    if (remoteResp.statusCode != 200 || resolvedUrl == null) {
      ref.read(blackboxSyncMetaProvider.notifier).setError(
            'No se pudo sincronizar (HTTP ${remoteResp.statusCode}).',
          );
      return;
    }

    final merged = _parseRawDynamicMap(remoteResp.data);

    // Subir sesiones creadas offline en este dispositivo que aún no estén en Firebase
    for (final localRec in localMap.values) {
      if (!localRec.syncedToFirebase && !merged.containsKey(localRec.sessionId)) {
        final putResp = await _restRequest(
          'PUT',
          resolvedUrl,
          'blackbox_sessions/$uid/${localRec.sessionId}',
          idToken: idToken,
          body: _recordToRemotePayload(localRec),
        );
        if (putResp != null && putResp.statusCode == 200) {
          merged[localRec.sessionId] = localRec.copyWith(syncedToFirebase: true);
        } else {
          merged[localRec.sessionId] = localRec;
        }
      }
    }

    if (!_isActive(gen)) return;
    final sorted = _sortRecords(merged.values);
    state = sorted;
    await _persistLocalForUid(uid, sorted);
    ref.read(blackboxSyncMetaProvider.notifier).setSuccess();
    _attachLiveListener(uid, gen, resolvedUrl);
  }

  Future<void> _handleRemoteSnapshot(
    String uid,
    int gen,
    DataSnapshot snapshot,
  ) async {
    if (!_isActive(gen)) return;
    final merged = snapshot.exists
        ? _parseRawDynamicMap(snapshot.value)
        : <String, BlackboxCloudRecord>{};

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
    if (Firebase.apps.isNotEmpty && uid != 'anonymous-rs172') {
      final idToken = await _getFirebaseIdToken();
      var dbUrl = _resolvedDbUrl;
      if (dbUrl == null) {
        final (probedUrl, probedResp) =
            await _probeActiveDatabase(uid, idToken: idToken);
        if (probedResp != null && probedResp.statusCode == 200) {
          dbUrl = probedUrl;
        }
      }
      if (dbUrl != null) {
        final payload = _recordToRemotePayload(
          draftRecord,
          dtcsJson: dtcs.map((d) => d.toJson()).toList(),
        );
        final putResp = await _restRequest(
          'PUT',
          dbUrl,
          'blackbox_sessions/$uid/$sessionId',
          idToken: idToken,
          body: payload,
        );
        remoteSuccess = putResp != null && putResp.statusCode == 200;
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
      if (Firebase.apps.isNotEmpty && uid != 'anonymous-rs172') {
        final dbUrl = _resolvedDbUrl;
        if (dbUrl != null) {
          final idToken = await _getFirebaseIdToken();
          await _restRequest(
            'DELETE',
            dbUrl,
            'blackbox_sessions/$uid/$sessionId',
            idToken: idToken,
          );
        }
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
