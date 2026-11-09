import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../cockpit_dashboard/widgets/launcher_dock_widget.dart';
import '../telemetry/models/obd_telemetry_frame.dart';
import '../telemetry/providers/telemetry_providers.dart';

/// Modelo de Aplicación Multimedia compatible con el Hub estilo Android Auto
class MultimediaAppOption {
  final String name;
  final String packageName;
  final String fallbackWebUrl;
  final IconData icon;
  final Color brandColor;
  final bool isInstalled;

  const MultimediaAppOption({
    required this.name,
    required this.packageName,
    required this.fallbackWebUrl,
    required this.icon,
    required this.brandColor,
    this.isInstalled = false,
  });

  MultimediaAppOption copyWith({bool? isInstalled}) {
    return MultimediaAppOption(
      name: name,
      packageName: packageName,
      fallbackWebUrl: fallbackWebUrl,
      icon: icon,
      brandColor: brandColor,
      isInstalled: isInstalled ?? this.isInstalled,
    );
  }
}

class MultimediaHubState {
  final MultimediaAppOption selectedApp;
  final List<MultimediaAppOption> availableApps;
  final double volumePercent;
  final int currentStep;
  final int maxStep;
  final bool isMuted;
  final bool isMusicActive;

  const MultimediaHubState({
    required this.selectedApp,
    required this.availableApps,
    this.volumePercent = 0.65,
    this.currentStep = 10,
    this.maxStep = 15,
    this.isMuted = false,
    this.isMusicActive = false,
  });

  MultimediaHubState copyWith({
    MultimediaAppOption? selectedApp,
    List<MultimediaAppOption>? availableApps,
    double? volumePercent,
    int? currentStep,
    int? maxStep,
    bool? isMuted,
    bool? isMusicActive,
  }) {
    return MultimediaHubState(
      selectedApp: selectedApp ?? this.selectedApp,
      availableApps: availableApps ?? this.availableApps,
      volumePercent: volumePercent ?? this.volumePercent,
      currentStep: currentStep ?? this.currentStep,
      maxStep: maxStep ?? this.maxStep,
      isMuted: isMuted ?? this.isMuted,
      isMusicActive: isMusicActive ?? this.isMusicActive,
    );
  }
}

class MultimediaHubNotifier extends Notifier<MultimediaHubState> {
  static const MethodChannel _channel =
      MethodChannel('com.renaultsport.clio172/launcher');
  static const String _savedPkgKey = 'rs_selected_media_app_pkg';

  static const MultimediaAppOption kDefaultSpotifyApp = MultimediaAppOption(
    name: 'Spotify',
    packageName: 'com.spotify.music',
    fallbackWebUrl: 'https://open.spotify.com',
    icon: Icons.music_note_rounded,
    brandColor: Color(0xFF1DB954),
  );

  static const List<MultimediaAppOption> kCuratedMediaApps =
      <MultimediaAppOption>[
    kDefaultSpotifyApp,
    MultimediaAppOption(
      name: 'YouTube Music',
      packageName: 'com.google.android.apps.youtube.music',
      fallbackWebUrl: 'https://music.youtube.com',
      icon: Icons.play_circle_fill_rounded,
      brandColor: Color(0xFFFF0033),
    ),
    MultimediaAppOption(
      name: 'Apple Music',
      packageName: 'com.apple.android.music',
      fallbackWebUrl: 'https://music.apple.com',
      icon: Icons.album_rounded,
      brandColor: Color(0xFFFA243C),
    ),
    MultimediaAppOption(
      name: 'Amazon Music',
      packageName: 'com.amazon.mp3',
      fallbackWebUrl: 'https://music.amazon.com',
      icon: Icons.library_music_rounded,
      brandColor: Color(0xFF00A8E1),
    ),
    MultimediaAppOption(
      name: 'YouTube',
      packageName: 'com.google.android.youtube',
      fallbackWebUrl: 'https://www.youtube.com',
      icon: Icons.ondemand_video_rounded,
      brandColor: Color(0xFFFF0000),
    ),
    MultimediaAppOption(
      name: 'Tidal',
      packageName: 'com.aspiro.tidal',
      fallbackWebUrl: 'https://listen.tidal.com',
      icon: Icons.graphic_eq_rounded,
      brandColor: Color(0xFF00FFFF),
    ),
    MultimediaAppOption(
      name: 'Deezer',
      packageName: 'deezer.android.app',
      fallbackWebUrl: 'https://www.deezer.com',
      icon: Icons.equalizer_rounded,
      brandColor: Color(0xFFA238FF),
    ),
    MultimediaAppOption(
      name: 'SoundCloud',
      packageName: 'com.soundcloud.android',
      fallbackWebUrl: 'https://soundcloud.com',
      icon: Icons.cloud_queue_rounded,
      brandColor: Color(0xFFFF5500),
    ),
    MultimediaAppOption(
      name: 'VLC Player',
      packageName: 'org.videolan.vlc',
      fallbackWebUrl: 'https://www.videolan.org',
      icon: Icons.speaker_group_rounded,
      brandColor: Color(0xFFFF8800),
    ),
  ];

  Timer? _volumeSyncTimer;

  @override
  MultimediaHubState build() {
    ref.onDispose(() {
      _volumeSyncTimer?.cancel();
    });
    _initializeMultimediaHub();
    _volumeSyncTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => refreshHardwareVolume(),
    );
    return const MultimediaHubState(
      selectedApp: kDefaultSpotifyApp,
      availableApps: kCuratedMediaApps,
    );
  }

  Future<void> _initializeMultimediaHub() async {
    await refreshHardwareVolume();
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPkg =
          prefs.getString(_savedPkgKey) ?? kDefaultSpotifyApp.packageName;

      final installedRaw =
          await _channel.invokeMethod<List<dynamic>>('getInstalledMediaApps');
      final installedPackages = <String>{};
      final extraMediaApps = <MultimediaAppOption>[];

      if (installedRaw != null) {
        for (final item in installedRaw) {
          final map = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
          final pkg = (map['packageName'] as String?) ?? '';
          final name = (map['name'] as String?) ?? '';
          final isMediaCategory = (map['isMediaCategory'] as bool?) ?? false;
          if (pkg.isEmpty) continue;
          installedPackages.add(pkg);

          final alreadyInCurated =
              kCuratedMediaApps.any((c) => c.packageName == pkg);
          if (!alreadyInCurated && isMediaCategory && name.isNotEmpty) {
            extraMediaApps.add(
              MultimediaAppOption(
                name: name,
                packageName: pkg,
                fallbackWebUrl: '',
                icon: Icons.headphones_rounded,
                brandColor: RenaultSportPalette.sagemAmberOrange,
                isInstalled: true,
              ),
            );
          }
        }
      }

      final mergedApps = <MultimediaAppOption>[
        ...kCuratedMediaApps.map(
          (app) => app.copyWith(
            isInstalled: installedPackages.contains(app.packageName),
          ),
        ),
        ...extraMediaApps,
      ];

      final active = mergedApps.firstWhere(
        (a) => a.packageName == savedPkg,
        orElse: () => mergedApps.first,
      );

      state = state.copyWith(
        availableApps: mergedApps,
        selectedApp: active,
      );
    } catch (_) {}
  }

  /// Sincroniza el slider con el volumen real actual de la tablet (`AudioManager.STREAM_MUSIC`)
  Future<void> refreshHardwareVolume() async {
    try {
      final raw =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getVolumeState');
      if (raw == null) return;
      _applyVolumeMap(raw);
    } catch (_) {}
  }

  void _applyVolumeMap(Map<dynamic, dynamic> raw) {
    final current = (raw['current'] as num?)?.toInt() ?? state.currentStep;
    final max = (raw['max'] as num?)?.toInt() ?? state.maxStep;
    final percent =
        (raw['percent'] as num?)?.toDouble() ?? state.volumePercent;
    final isMuted = (raw['isMuted'] as bool?) ?? state.isMuted;
    final isMusicActive =
        (raw['isMusicActive'] as bool?) ?? state.isMusicActive;

    state = state.copyWith(
      currentStep: current,
      maxStep: max,
      volumePercent: percent.clamp(0.0, 1.0),
      isMuted: isMuted,
      isMusicActive: isMusicActive,
    );
  }

  /// Cambia el volumen físico de la tablet desde el Slider
  Future<void> setTabletVolume(double nextPercent, {bool showUi = false}) async {
    final clamped = nextPercent.clamp(0.0, 1.0);
    state = state.copyWith(
      volumePercent: clamped,
      currentStep: (clamped * state.maxStep).round(),
      isMuted: clamped == 0.0,
    );
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'setVolume',
        <String, dynamic>{
          'percent': clamped,
          'showUi': showUi,
        },
      );
      if (raw != null) {
        _applyVolumeMap(raw);
      }
    } catch (_) {}
  }

  /// Sube/baja 1 paso o silencia el volumen de la tablet
  Future<void> adjustVolumeStep({int delta = 0, bool toggleMute = false}) async {
    HapticFeedback.selectionClick();
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'adjustVolumeStep',
        <String, dynamic>{
          'delta': delta,
          'toggleMute': toggleMute,
        },
      );
      if (raw != null) {
        _applyVolumeMap(raw);
      }
    } catch (_) {}
  }

  /// Envía comandos multimedia nativos (Play/Pause, Siguiente, Anterior) a Spotify o la app activa
  Future<void> sendMediaTransportCommand(String command) async {
    HapticFeedback.lightImpact();
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'sendMediaKey',
        <String, dynamic>{'command': command},
      );
      if (raw != null) {
        _applyVolumeMap(raw);
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await refreshHardwareVolume();
    } catch (_) {}
  }

  /// Cambia la app multimedia predeterminada (Spotify por defecto, o cualquier otra)
  Future<void> selectMultimediaApp(MultimediaAppOption app) async {
    HapticFeedback.selectionClick();
    state = state.copyWith(selectedApp: app);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedPkgKey, app.packageName);
    } catch (_) {}
  }

  /// Abre la app multimedia seleccionada (en pantalla completa o en pantalla dividida estilo Android Auto)
  Future<void> openSelectedMultimediaApp({bool splitScreen = false}) async {
    HapticFeedback.mediumImpact();
    final app = state.selectedApp;
    try {
      await _channel.invokeMethod<bool>(
        'launchExternalApp',
        <String, dynamic>{
          'packageName': app.packageName,
          'fallbackUrl': app.fallbackWebUrl,
          'splitScreen': splitScreen,
        },
      );
    } catch (_) {}
  }
}

final multimediaHubProvider =
    NotifierProvider<MultimediaHubNotifier, MultimediaHubState>(
  MultimediaHubNotifier.new,
);

/// Pantalla **MULTIMEDIA** estilo Android Auto:
/// - Spotify por defecto con selector rápido a cualquier otra app multimedia.
/// - Controles de reproducción (Anterior, Play/Pause, Siguiente) conectados al AudioManager de Android.
/// - Slider de volumen real que controla directamente el volumen físico de la tablet.
/// - Tarjeta lateral de telemetría en vivo (RPM, KM/H, Marcha, Temp) estilo Android Auto Split-Screen.
class MultimediaHubScreen extends ConsumerWidget {
  const MultimediaHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaState = ref.watch(multimediaHubProvider);
    final mediaNotifier = ref.read(multimediaHubProvider.notifier);
    final telemetryAsync = ref.watch(obdTelemetryStreamProvider);
    final frame = telemetryAsync.valueOrNull ??
        ObdTelemetryFrame.initial(isSimulator: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTabletWide = constraints.maxWidth >= 820;

        if (isTabletWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Columna Izquierda (65%): Reproductor Android Auto + Volumen Tablet + Selector de Apps
              Expanded(
                flex: 7,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AndroidAutoPlayerDeckCard(
                        state: mediaState,
                        notifier: mediaNotifier,
                      ),
                      const SizedBox(height: 12),
                      _TabletHardwareVolumeCard(
                        state: mediaState,
                        notifier: mediaNotifier,
                      ),
                      const SizedBox(height: 12),
                      _MultimediaAppSwitcherCard(
                        state: mediaState,
                        notifier: mediaNotifier,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Columna Derecha (35%): Mini-Cockpit Android Auto en Vivo
              Expanded(
                flex: 4,
                child: _AndroidAutoMiniTelemetryCard(frame: frame),
              ),
            ],
          );
        }

        // Vista compacta (Teléfono o ventana dividida)
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AndroidAutoPlayerDeckCard(
                state: mediaState,
                notifier: mediaNotifier,
              ),
              const SizedBox(height: 10),
              _TabletHardwareVolumeCard(
                state: mediaState,
                notifier: mediaNotifier,
              ),
              const SizedBox(height: 10),
              _MultimediaAppSwitcherCard(
                state: mediaState,
                notifier: mediaNotifier,
              ),
              const SizedBox(height: 10),
              _AndroidAutoMiniTelemetryCard(
                frame: frame,
                isCompact: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AndroidAutoPlayerDeckCard extends StatelessWidget {
  final MultimediaHubState state;
  final MultimediaHubNotifier notifier;

  const _AndroidAutoPlayerDeckCard({
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final app = state.selectedApp;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              app.brandColor.withValues(alpha: isDark ? 0.24 : 0.14),
              Colors.transparent,
            ],
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera de la App Activa (Spotify por defecto)
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: app.brandColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: app.brandColor,
                          width: 1.8,
                        ),
                      ),
                      child: Icon(
                        app.icon,
                        size: 28,
                        color: app.brandColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  app.name.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.renaultSportHeaderStyle(
                                    fontSize: 19,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: (state.isMusicActive
                                          ? RenaultSportPalette.oemShiftGreen
                                          : app.brandColor)
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: state.isMusicActive
                                        ? RenaultSportPalette.oemShiftGreen
                                        : app.brandColor,
                                  ),
                                ),
                                child: Text(
                                  state.isMusicActive ? 'EN REPRODUCCIÓN' : 'ACTIVA',
                                  style: AppTheme.telemetryNumericStyle(
                                    fontSize: 9.5,
                                    color: state.isMusicActive
                                        ? RenaultSportPalette.oemShiftGreen
                                        : app.brandColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Control directo de reproducción en segundo plano y pantalla dividida',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: app.brandColor,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () =>
                          notifier.openSelectedMultimediaApp(splitScreen: false),
                      icon: Icon(app.icon, size: 18),
                      label: Text('ABRIR ${app.name.toUpperCase()}'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          notifier.openSelectedMultimediaApp(splitScreen: true),
                      icon: const Icon(Icons.vertical_split_rounded, size: 18),
                      label: const Text('PANTALLA DIVIDIDA'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Botonera de Transporte Multimedia estilo Android Auto
            Center(
              child: Wrap(
                spacing: 18,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                children: [
                  _TransportCircleButton(
                    icon: Icons.skip_previous_rounded,
                    tooltip: 'Canción Anterior',
                    size: 54,
                    iconSize: 28,
                    accentColor: app.brandColor,
                    onTap: () => notifier.sendMediaTransportCommand('previous'),
                  ),
                  _TransportCircleButton(
                    icon: state.isMusicActive
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    tooltip: 'Reproducir / Pausar',
                    size: 70,
                    iconSize: 38,
                    accentColor: app.brandColor,
                    filled: true,
                    onTap: () =>
                        notifier.sendMediaTransportCommand('play_pause'),
                  ),
                  _TransportCircleButton(
                    icon: Icons.skip_next_rounded,
                    tooltip: 'Siguiente Canción',
                    size: 54,
                    iconSize: 28,
                    accentColor: app.brandColor,
                    onTap: () => notifier.sendMediaTransportCommand('next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransportCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final double size;
  final double iconSize;
  final Color accentColor;
  final bool filled;
  final VoidCallback onTap;

  const _TransportCircleButton({
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.iconSize,
    required this.accentColor,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? accentColor : accentColor.withValues(alpha: 0.14),
            border: Border.all(
              color: accentColor,
              width: 1.8,
            ),
            boxShadow: filled
                ? <BoxShadow>[
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: filled ? Colors.black : accentColor,
          ),
        ),
      ),
    );
  }
}

class _TabletHardwareVolumeCard extends StatelessWidget {
  final MultimediaHubState state;
  final MultimediaHubNotifier notifier;

  const _TabletHardwareVolumeCard({
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final pctInt = (state.volumePercent * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      state.isMuted || pctInt == 0
                          ? Icons.volume_off_rounded
                          : (pctInt < 50
                              ? Icons.volume_down_rounded
                              : Icons.volume_up_rounded),
                      color: state.isMuted
                          ? RenaultSportPalette.revLimiterRed
                          : primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'VOLUMEN DE LA TABLET',
                      style: AppTheme.renaultSportHeaderStyle(
                        fontSize: 15,
                        color: primary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primary),
                  ),
                  child: Text(
                    state.isMuted
                        ? 'MUTE (0%)'
                        : '$pctInt%  •  ${state.currentStep}/${state.maxStep}',
                    style: AppTheme.telemetryNumericStyle(
                      fontSize: 12.5,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Slider Principal + Botones Mute / - / +
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Silenciar / Activar Audio',
                  onPressed: () =>
                      notifier.adjustVolumeStep(toggleMute: true),
                  icon: Icon(
                    state.isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_mute_rounded,
                    color: state.isMuted
                        ? RenaultSportPalette.revLimiterRed
                        : null,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Bajar Volumen',
                  onPressed: () => notifier.adjustVolumeStep(delta: -1),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 10,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 12,
                      ),
                    ),
                    child: Slider(
                      value: state.isMuted ? 0.0 : state.volumePercent,
                      min: 0.0,
                      max: 1.0,
                      divisions: state.maxStep > 0 ? state.maxStep : 15,
                      label: '$pctInt%',
                      onChanged: (val) => notifier.setTabletVolume(val),
                      onChangeEnd: (val) =>
                          notifier.setTabletVolume(val, showUi: true),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Subir Volumen',
                  onPressed: () => notifier.adjustVolumeStep(delta: 1),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Niveles rápidos para tocar con un dedo al conducir
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <int>[25, 50, 75, 100].map((presetPct) {
                final isCurrent = (pctInt - presetPct).abs() <= 4 && !state.isMuted;
                return ActionChip(
                  backgroundColor: isCurrent
                      ? primary.withValues(alpha: 0.25)
                      : null,
                  side: BorderSide(
                    color: isCurrent ? primary : Colors.white24,
                  ),
                  label: Text(
                    '$presetPct%',
                    style: AppTheme.telemetryNumericStyle(
                      fontSize: 11.5,
                      color: isCurrent
                          ? primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  onPressed: () =>
                      notifier.setTabletVolume(presetPct / 100.0, showUi: true),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultimediaAppSwitcherCard extends StatelessWidget {
  final MultimediaHubState state;
  final MultimediaHubNotifier notifier;

  const _MultimediaAppSwitcherCard({
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CAMBIAR APP MULTIMEDIA (SPOTIFY POR DEFECTO)',
              style: AppTheme.renaultSportHeaderStyle(
                fontSize: 14,
                color: primary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: state.availableApps.map((app) {
                final isSelected =
                    app.packageName == state.selectedApp.packageName;
                return InkWell(
                  onTap: () => notifier.selectMultimediaApp(app),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 175,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? app.brandColor.withValues(alpha: 0.18)
                          : Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? app.brandColor : Colors.white12,
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: app.brandColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            app.icon,
                            size: 18,
                            color: app.brandColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              Text(
                                app.isInstalled ? 'Instalada' : 'Web / App',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: app.isInstalled
                                      ? RenaultSportPalette.oemShiftGreen
                                      : Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            size: 17,
                            color: app.brandColor,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AndroidAutoMiniTelemetryCard extends ConsumerWidget {
  final ObdTelemetryFrame frame;
  final bool isCompact;

  const _AndroidAutoMiniTelemetryCard({
    required this.frame,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final gearText = frame.estimatedGear == 0 ? 'N' : '${frame.estimatedGear}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TELEMETRÍA EN VIVO',
                      style: AppTheme.renaultSportHeaderStyle(
                        fontSize: 14,
                        color: primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: RenaultSportPalette.oemShiftGreen
                            .withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${frame.kLineHz} HZ',
                        style: AppTheme.telemetryNumericStyle(
                          fontSize: 10,
                          color: RenaultSportPalette.oemShiftGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Indicador grande de RPM + Velocidad + Marcha
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'MARCHA',
                              style: TextStyle(fontSize: 10),
                            ),
                            Text(
                              gearText,
                              style: AppTheme.digitalDisplayStyle(
                                fontSize: 32,
                                color: primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 22),
                        Column(
                          children: [
                            const Text(
                              'MOTOR RPM',
                              style: TextStyle(fontSize: 10),
                            ),
                            Text(
                              '${frame.rpm.round()}',
                              style: AppTheme.digitalDisplayStyle(
                                fontSize: 32,
                                color: frame.rpm >= 6750
                                    ? RenaultSportPalette.oemShiftGreen
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 22),
                        Column(
                          children: [
                            const Text(
                              'KM/H',
                              style: TextStyle(fontSize: 10),
                            ),
                            Text(
                              '${frame.speedKmh}',
                              style: AppTheme.digitalDisplayStyle(
                                fontSize: 32,
                                color: RenaultSportPalette.siriusLiquidYellow,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Tarjetas de Temperatura, TPS y Voltaje
                Row(
                  children: [
                    Expanded(
                      child: _MiniHudStatBox(
                        label: 'REFRIGERANTE',
                        value: '${frame.coolantTempC.toStringAsFixed(0)} °C',
                        color: frame.isEngineCold
                            ? RenaultSportPalette.coldEngineAmber
                            : RenaultSportPalette.oemShiftGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniHudStatBox(
                        label: 'ACELERADOR',
                        value: '${frame.throttleTps.toStringAsFixed(0)} %',
                        color: primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniHudStatBox(
                        label: 'BATERÍA',
                        value: '${frame.batteryVolts.toStringAsFixed(1)} V',
                        color: Colors.cyanAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            OutlinedButton.icon(
              onPressed: () => ref
                  .read(cockpitTabProvider.notifier)
                  .selectTab(CockpitSectionTab.cockpitHud),
              icon: const Icon(Icons.speed_rounded, size: 18),
              label: const Text('VOLVER AL COCKPIT COMPLETO'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniHudStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniHudStatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTheme.telemetryNumericStyle(
                fontSize: 13.5,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
