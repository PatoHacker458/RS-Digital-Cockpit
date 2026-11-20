import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../digital_garage_payments/providers/payment_garage_providers.dart';

/// Handler de Segundo Plano de Nivel Superior para FCM Background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

/// Estado reactivo de Notificaciones del Sistema + Seguimiento Automático de Kilometraje (Odómetro)
class FcmTopicsState {
  final bool maintenanceSubscribed; // clio_rs_maintenance (Alertas por kilometraje)
  final bool trackDaysSubscribed;   // track_day_events
  final bool otaThemesSubscribed;   // ota_gauge_themes

  // Seguimiento automático de kilometraje del vehículo (OBD-II + GPS)
  final double vehicleOdometerKm;
  final double sessionDistanceKm;
  final double lastOilServiceKm;
  final double lastSparkPlugsKm;
  final double lastTimingBeltKm;

  const FcmTopicsState({
    this.maintenanceSubscribed = true,
    this.trackDaysSubscribed = true,
    this.otaThemesSubscribed = false,
    this.vehicleOdometerKm = 148200.0,
    this.sessionDistanceKm = 0.0,
    this.lastOilServiceKm = 140000.0,
    this.lastSparkPlugsKm = 125000.0,
    this.lastTimingBeltKm = 100000.0,
  });

  // Intervalos oficiales Renault Sport Clio 172 (F4R 736)
  static const double kOilIntervalKm = 10000.0;
  static const double kSparkPlugIntervalKm = 30000.0;
  static const double kTimingBeltIntervalKm = 60000.0;

  double get kmUntilOilService =>
      (lastOilServiceKm + kOilIntervalKm) - vehicleOdometerKm;
  double get kmUntilSparkPlugs =>
      (lastSparkPlugsKm + kSparkPlugIntervalKm) - vehicleOdometerKm;
  double get kmUntilTimingBelt =>
      (lastTimingBeltKm + kTimingBeltIntervalKm) - vehicleOdometerKm;

  FcmTopicsState copyWith({
    bool? maintenanceSubscribed,
    bool? trackDaysSubscribed,
    bool? otaThemesSubscribed,
    double? vehicleOdometerKm,
    double? sessionDistanceKm,
    double? lastOilServiceKm,
    double? lastSparkPlugsKm,
    double? lastTimingBeltKm,
  }) {
    return FcmTopicsState(
      maintenanceSubscribed:
          maintenanceSubscribed ?? this.maintenanceSubscribed,
      trackDaysSubscribed: trackDaysSubscribed ?? this.trackDaysSubscribed,
      otaThemesSubscribed: otaThemesSubscribed ?? this.otaThemesSubscribed,
      vehicleOdometerKm: vehicleOdometerKm ?? this.vehicleOdometerKm,
      sessionDistanceKm: sessionDistanceKm ?? this.sessionDistanceKm,
      lastOilServiceKm: lastOilServiceKm ?? this.lastOilServiceKm,
      lastSparkPlugsKm: lastSparkPlugsKm ?? this.lastSparkPlugsKm,
      lastTimingBeltKm: lastTimingBeltKm ?? this.lastTimingBeltKm,
    );
  }
}

/// Notifier que gestiona:
/// 1) Notificaciones nativas del sistema Android (sin banner interno duplicado).
/// 2) Cálculo automático de kilometraje en vivo (integración OBD2 / GPS) y disparo
///    automático de alertas de mantenimiento (Aceite, Bujías, Distribución + VVT).
class FcmTopicsNotifier extends Notifier<FcmTopicsState> {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _prefOdometerKey = 'rs_vehicle_odometer_km';
  static const String _prefLastOilKey = 'rs_service_last_oil_km';
  static const String _prefLastPlugsKey = 'rs_service_last_plugs_km';
  static const String _prefLastBeltKey = 'rs_service_last_belt_km';
  static const String _prefNotifiedPrefix = 'rs_maint_notified_';

  DateTime _lastPersistedAt = DateTime.fromMillisecondsSinceEpoch(0);
  final Set<String> _notifiedAlertsThisSession = <String>{};

  static const AndroidNotificationChannel _androidHudChannel =
      AndroidNotificationChannel(
    'clio_rs_hud_channel',
    'RS Digital Cockpit Alertas',
    description: 'Alertas de mantenimiento por kilometraje y eventos RS',
    importance: Importance.max,
  );

  @override
  FcmTopicsState build() {
    _initializeFcmAndOdometer();
    return const FcmTopicsState();
  }

  Future<void> _initializeFcmAndOdometer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOdo = prefs.getDouble(_prefOdometerKey);
      final savedOil = prefs.getDouble(_prefLastOilKey);
      final savedPlugs = prefs.getDouble(_prefLastPlugsKey);
      final savedBelt = prefs.getDouble(_prefLastBeltKey);
      final maintSub = prefs.getBool('fcm_topic_clio_rs_maintenance');
      final trackSub = prefs.getBool('fcm_topic_track_day_events');
      final otaSub = prefs.getBool('fcm_topic_ota_gauge_themes');

      state = state.copyWith(
        vehicleOdometerKm: savedOdo ?? state.vehicleOdometerKm,
        lastOilServiceKm: savedOil ?? state.lastOilServiceKm,
        lastSparkPlugsKm: savedPlugs ?? state.lastSparkPlugsKm,
        lastTimingBeltKm: savedBelt ?? state.lastTimingBeltKm,
        maintenanceSubscribed: maintSub ?? state.maintenanceSubscribed,
        trackDaysSubscribed: trackSub ?? state.trackDaysSubscribed,
        otaThemesSubscribed: otaSub ?? state.otaThemesSubscribed,
      );
    } catch (_) {}

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _localNotifications.initialize(
        const InitializationSettings(android: androidInit),
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidHudChannel);
    } catch (_) {}

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (state.maintenanceSubscribed) {
        await messaging.subscribeToTopic('clio_rs_maintenance');
      }
      if (state.trackDaysSubscribed) {
        await messaging.subscribeToTopic('track_day_events');
      }

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleIncomingRemoteMessage(initialMessage);
      }

      FirebaseMessaging.onMessage.listen(_handleIncomingRemoteMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleIncomingRemoteMessage);
    } catch (_) {}

    // Verificar al iniciar si algún mantenimiento ya venció o está próximo por kilometraje
    await _evaluateAutomaticMileageAlerts();
  }

  void _handleIncomingRemoteMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'RS DIGITAL COCKPIT';
    final body = message.notification?.body ??
        (message.data['body'] as String? ?? 'Nueva alerta recibida.');
    final topic = message.from ?? 'clio_rs_maintenance';
    triggerSystemNotification(title: title, body: body, topic: topic);
  }

  /// Suma automáticamente los kilómetros recorridos (provenientes de GPS real o velocidad OBD2)
  /// y evalúa las alertas automáticas de mantenimiento.
  Future<void> addDrivenDistanceKm(double deltaKm) async {
    if (deltaKm <= 0.0 || deltaKm > 5.0) return; // Descartar saltos GPS imposibles
    final nextOdo = state.vehicleOdometerKm + deltaKm;
    final nextSession = state.sessionDistanceKm + deltaKm;

    state = state.copyWith(
      vehicleOdometerKm: nextOdo,
      sessionDistanceKm: nextSession,
    );

    final now = DateTime.now();
    if (now.difference(_lastPersistedAt).inSeconds >= 10) {
      _lastPersistedAt = now;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_prefOdometerKey, nextOdo);
      } catch (_) {}
      await _evaluateAutomaticMileageAlerts();
    }
  }

  /// Permite al usuario sincronizar su kilometraje actual del tablero físico del Clio
  Future<void> updateVehicleOdometerKm(double exactKm) async {
    if (exactKm < 0) return;
    state = state.copyWith(vehicleOdometerKm: exactKm);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefOdometerKey, exactKm);
    } catch (_) {}
    await _evaluateAutomaticMileageAlerts();
  }

  /// Marca un servicio como realizado hoy en el kilometraje actual (reinicia su contador)
  Future<void> markServiceCompleted(String serviceType) async {
    final currentKm = state.vehicleOdometerKm;
    final prefs = await SharedPreferences.getInstance();
    switch (serviceType) {
      case 'oil':
        state = state.copyWith(lastOilServiceKm: currentKm);
        await prefs.setDouble(_prefLastOilKey, currentKm);
        await prefs.remove('${_prefNotifiedPrefix}oil');
        _notifiedAlertsThisSession.remove('oil');
      case 'plugs':
        state = state.copyWith(lastSparkPlugsKm: currentKm);
        await prefs.setDouble(_prefLastPlugsKey, currentKm);
        await prefs.remove('${_prefNotifiedPrefix}plugs');
        _notifiedAlertsThisSession.remove('plugs');
      case 'belt':
        state = state.copyWith(lastTimingBeltKm: currentKm);
        await prefs.setDouble(_prefLastBeltKey, currentKm);
        await prefs.remove('${_prefNotifiedPrefix}belt');
        _notifiedAlertsThisSession.remove('belt');
    }
  }

  /// Evalúa automáticamente si el kilometraje actual alcanzó algún umbral de servicio
  /// (vencido <= 0 km o próximo <= 500 km) y dispara la notificación nativa del sistema Android.
  Future<void> _evaluateAutomaticMileageAlerts() async {
    final activePlan = ref.read(digitalGaragePaymentProvider).activeSubscription;
    if (!state.maintenanceSubscribed || !activePlan.unlocksMileageAlerts) return;

    final checks = <({String id, String name, double remaining})>[
      (
        id: 'oil',
        name: 'Cambio de Aceite 5W40 Sintético',
        remaining: state.kmUntilOilService,
      ),
      (
        id: 'plugs',
        name: 'Bujías NGK PFR6E-10 y Filtros',
        remaining: state.kmUntilSparkPlugs,
      ),
      (
        id: 'belt',
        name: 'Kit de Distribución y Polea VVT F4R',
        remaining: state.kmUntilTimingBelt,
      ),
    ];

    try {
      final prefs = await SharedPreferences.getInstance();
      for (final check in checks) {
        if (check.remaining <= 500.0) {
          final bucket = check.remaining <= 0 ? 'due' : 'soon';
          final alertKey = '${check.id}_$bucket';
          if (_notifiedAlertsThisSession.contains(alertKey)) continue;
          final alreadySentKm = prefs.getDouble('$_prefNotifiedPrefix$alertKey');
          // Evitar repetir la misma alerta hasta que recorra otros 250 km
          if (alreadySentKm != null &&
              (state.vehicleOdometerKm - alreadySentKm).abs() < 250.0) {
            continue;
          }

          _notifiedAlertsThisSession.add(alertKey);
          await prefs.setDouble(
            '$_prefNotifiedPrefix$alertKey',
            state.vehicleOdometerKm,
          );

          final body = check.remaining <= 0
              ? 'Kilometraje actual: ${state.vehicleOdometerKm.round()} km. ${check.name} vencido por ${check.remaining.abs().round()} km.'
              : 'Kilometraje actual: ${state.vehicleOdometerKm.round()} km. Faltan ${check.remaining.round()} km para ${check.name}.';

          await triggerSystemNotification(
            title: check.remaining <= 0
                ? 'SERVICIO REQUERIDO (${state.vehicleOdometerKm.round()} KM)'
                : 'PRÓXIMO MANTENIMIENTO F4R',
            body: body,
            topic: 'clio_rs_maintenance',
          );
        }
      }
    } catch (_) {}
  }

  /// Suscribe o desuscribe un canal FCM y envía notificación del sistema
  Future<void> toggleTopic(String topicName, bool subscribe) async {
    switch (topicName) {
      case 'clio_rs_maintenance':
        state = state.copyWith(maintenanceSubscribed: subscribe);
      case 'track_day_events':
        state = state.copyWith(trackDaysSubscribed: subscribe);
      case 'ota_gauge_themes':
        state = state.copyWith(otaThemesSubscribed: subscribe);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fcm_topic_$topicName', subscribe);
      if (subscribe) {
        await FirebaseMessaging.instance.subscribeToTopic(topicName);
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topicName);
      }
    } catch (_) {}
  }

  /// Dispara ÚNICAMENTE la notificación nativa del sistema Android (sin banner interno en la app).
  Future<void> triggerSystemNotification({
    required String title,
    required String body,
    required String topic,
  }) async {
    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidHudChannel.id,
            _androidHudChannel.name,
            channelDescription: _androidHudChannel.description,
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {}
  }

  /// Alias retrocompatible para llamadas existentes -> dispara únicamente notificación del sistema
  Future<void> triggerSimulatedHudPush({
    required String title,
    required String body,
    required String topic,
  }) {
    return triggerSystemNotification(title: title, body: body, topic: topic);
  }
}

final fcmTopicsProvider = NotifierProvider<FcmTopicsNotifier, FcmTopicsState>(
  FcmTopicsNotifier.new,
);
