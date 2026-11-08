import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handler de Segundo Plano de Nivel Superior obligatorio para Android 17 (FCM Background):
/// Se invoca en su propio Isolate cuando la app está en background o terminada.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

/// Modelo inmutable de Notificación Push mostrada en el Banner Global HUD Automotriz
class HudNotificationBannerMessage {
  final String title;
  final String body;
  final String topic;
  final DateTime receivedAt;

  const HudNotificationBannerMessage({
    required this.title,
    required this.body,
    required this.topic,
    required this.receivedAt,
  });
}

/// Estado reactivo de los canales/temas FCM (`subscribeToTopic` / `unsubscribeFromTopic`)
class FcmTopicsState {
  final bool maintenanceSubscribed; // clio_rs_maintenance
  final bool trackDaysSubscribed;   // track_day_events
  final bool otaThemesSubscribed;   // ota_gauge_themes
  final HudNotificationBannerMessage? activeHudBanner;

  const FcmTopicsState({
    this.maintenanceSubscribed = true,
    this.trackDaysSubscribed = true,
    this.otaThemesSubscribed = false,
    this.activeHudBanner,
  });

  FcmTopicsState copyWith({
    bool? maintenanceSubscribed,
    bool? trackDaysSubscribed,
    bool? otaThemesSubscribed,
    HudNotificationBannerMessage? activeHudBanner,
    bool clearBanner = false,
  }) {
    return FcmTopicsState(
      maintenanceSubscribed: maintenanceSubscribed ?? this.maintenanceSubscribed,
      trackDaysSubscribed: trackDaysSubscribed ?? this.trackDaysSubscribed,
      otaThemesSubscribed: otaThemesSubscribed ?? this.otaThemesSubscribed,
      activeHudBanner: clearBanner ? null : (activeHudBanner ?? this.activeHudBanner),
    );
  }
}

/// Notifier que gestiona el Ciclo de Vida Completo de Firebase Cloud Messaging (FCM):
/// 1) Primer plano (`FirebaseMessaging.onMessage`)
/// 2) Segundo plano (`FirebaseMessaging.onMessageOpenedApp`)
/// 3) Estado terminado (`FirebaseMessaging.instance.getInitialMessage()`)
/// 4) Canal de alta prioridad en Android 17 con `flutter_local_notifications`
/// 5) Suscripción reactiva a Temas (`subscribeToTopic` / `unsubscribeFromTopic`)
class FcmTopicsNotifier extends Notifier<FcmTopicsState> {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidHudChannel =
      AndroidNotificationChannel(
    'clio_rs_hud_channel',
    'Clio RS 172 Cockpit HUD Alerts',
    description: 'Alertas críticas de telemetría F4R, mantenimiento y Track Days',
    importance: Importance.max,
  );

  @override
  FcmTopicsState build() {
    _initializeFcmAndLocalNotifications();
    return const FcmTopicsState();
  }

  Future<void> _initializeFcmAndLocalNotifications() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _localNotifications.initialize(
        const InitializationSettings(android: androidInit),
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
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

      // Suscripciones iniciales por defecto
      await messaging.subscribeToTopic('clio_rs_maintenance');
      await messaging.subscribeToTopic('track_day_events');

      // 1. Estado Terminado (getInitialMessage)
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleIncomingRemoteMessage(initialMessage, origin: 'TERMINATED');
      }

      // 2. Primer Plano (onMessage)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleIncomingRemoteMessage(message, origin: 'FOREGROUND');
      });

      // 3. Segundo Plano al tocar la notificación (onMessageOpenedApp)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleIncomingRemoteMessage(message, origin: 'BACKGROUND_OPENED');
      });
    } catch (_) {
      // Si se ejecuta en el aula sin credenciales Firebase activas, mantiene listos los switches
    }
  }

  void _handleIncomingRemoteMessage(RemoteMessage message, {required String origin}) {
    final title = message.notification?.title ?? 'TELEMETRÍA RENAULT SPORT ($origin)';
    final body = message.notification?.body ??
        (message.data['body'] as String? ?? 'Mensaje recibido desde Firebase Cloud Messaging.');
    final topic = message.from ?? 'clio_rs_maintenance';

    triggerSimulatedHudPush(title: title, body: body, topic: topic);
  }

  /// Suscribe o desuscribe reactivamente un tema en FCM (`subscribeToTopic` / `unsubscribeFromTopic`)
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

    triggerSimulatedHudPush(
      title: subscribe ? 'SUSCRITO A CANAL FCM' : 'BAJA DE CANAL FCM',
      body: subscribe
          ? 'FirebaseMessaging.subscribeToTopic("$topicName") ejecutado en Android 17.'
          : 'FirebaseMessaging.unsubscribeFromTopic("$topicName") ejecutado.',
      topic: topicName,
    );
  }

  /// Lanza un banner estilo HUD automotriz en el Listener Global y notificación local de Android 17
  Future<void> triggerSimulatedHudPush({
    required String title,
    required String body,
    required String topic,
  }) async {
    state = state.copyWith(
      activeHudBanner: HudNotificationBannerMessage(
        title: title,
        body: body,
        topic: topic,
        receivedAt: DateTime.now(),
      ),
    );

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

  void dismissHudBanner() {
    state = state.copyWith(clearBanner: true);
  }
}

final fcmTopicsProvider = NotifierProvider<FcmTopicsNotifier, FcmTopicsState>(
  FcmTopicsNotifier.new,
);

