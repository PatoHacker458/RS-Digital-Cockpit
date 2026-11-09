import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';

class MultimediaHubState {
  final bool hasMediaPermission;
  final bool hasActiveSession;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int positionMs;
  final bool isPlaying;
  final String sourcePackage;
  final String sourceAppName;
  final Uint8List? albumArtBytes;

  // Estado de Volumen y Atenuación (ATT -75%)
  final double volumePercent;
  final int currentStep;
  final int maxStep;
  final bool isMuted;
  final bool isAttenuated;
  final double? preAttVolumePercent;

  const MultimediaHubState({
    this.hasMediaPermission = false,
    this.hasActiveSession = false,
    this.title = 'Reproductor en espera',
    this.artist = 'Reproduce música en tu tablet',
    this.album = '',
    this.durationMs = 0,
    this.positionMs = 0,
    this.isPlaying = false,
    this.sourcePackage = 'com.spotify.music',
    this.sourceAppName = 'Reproductor del Sistema',
    this.albumArtBytes,
    this.volumePercent = 0.65,
    this.currentStep = 10,
    this.maxStep = 15,
    this.isMuted = false,
    this.isAttenuated = false,
    this.preAttVolumePercent,
  });

  double get progressRatio {
    if (durationMs <= 0) return 0.0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  MultimediaHubState copyWith({
    bool? hasMediaPermission,
    bool? hasActiveSession,
    String? title,
    String? artist,
    String? album,
    int? durationMs,
    int? positionMs,
    bool? isPlaying,
    String? sourcePackage,
    String? sourceAppName,
    Uint8List? albumArtBytes,
    bool clearAlbumArt = false,
    double? volumePercent,
    int? currentStep,
    int? maxStep,
    bool? isMuted,
    bool? isAttenuated,
    double? preAttVolumePercent,
  }) {
    return MultimediaHubState(
      hasMediaPermission: hasMediaPermission ?? this.hasMediaPermission,
      hasActiveSession: hasActiveSession ?? this.hasActiveSession,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      positionMs: positionMs ?? this.positionMs,
      isPlaying: isPlaying ?? this.isPlaying,
      sourcePackage: sourcePackage ?? this.sourcePackage,
      sourceAppName: sourceAppName ?? this.sourceAppName,
      albumArtBytes:
          clearAlbumArt ? null : (albumArtBytes ?? this.albumArtBytes),
      volumePercent: volumePercent ?? this.volumePercent,
      currentStep: currentStep ?? this.currentStep,
      maxStep: maxStep ?? this.maxStep,
      isMuted: isMuted ?? this.isMuted,
      isAttenuated: isAttenuated ?? this.isAttenuated,
      preAttVolumePercent: preAttVolumePercent ?? this.preAttVolumePercent,
    );
  }
}

class MultimediaHubNotifier extends Notifier<MultimediaHubState> {
  static const MethodChannel _channel =
      MethodChannel('com.renaultsport.clio172/launcher');

  Timer? _sessionPollTimer;

  @override
  MultimediaHubState build() {
    ref.onDispose(() {
      _sessionPollTimer?.cancel();
    });
    _pollSystemMediaSession();
    _sessionPollTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => _pollSystemMediaSession(),
    );
    return const MultimediaHubState();
  }

  Future<void> _pollSystemMediaSession() async {
    try {
      final raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getSystemMediaSession');
      if (raw == null) return;
      _applyMediaSessionMap(raw);
    } catch (_) {}
  }

  void _applyMediaSessionMap(Map<dynamic, dynamic> raw) {
    final hasPerm =
        (raw['hasPermission'] as bool?) ?? state.hasMediaPermission;
    final hasActive =
        (raw['hasActiveSession'] as bool?) ?? state.hasActiveSession;
    final title = (raw['title'] as String?) ?? state.title;
    final artist = (raw['artist'] as String?) ?? state.artist;
    final album = (raw['album'] as String?) ?? state.album;
    final durationMs = (raw['durationMs'] as num?)?.toInt() ?? 0;
    final positionMs = (raw['positionMs'] as num?)?.toInt() ?? 0;
    final isPlaying = (raw['isPlaying'] as bool?) ?? false;
    final sourcePkg =
        (raw['sourcePackage'] as String?) ?? state.sourcePackage;
    final sourceName =
        (raw['sourceAppName'] as String?) ?? state.sourceAppName;
    final artBytes = raw['albumArtBytes'] as Uint8List?;

    var currentStep = state.currentStep;
    var maxStep = state.maxStep;
    var volumePercent = state.volumePercent;
    var isMuted = state.isMuted;

    final volMap = raw['volume'] as Map<dynamic, dynamic>?;
    if (volMap != null) {
      currentStep = (volMap['current'] as num?)?.toInt() ?? currentStep;
      maxStep = (volMap['max'] as num?)?.toInt() ?? maxStep;
      volumePercent =
          ((volMap['percent'] as num?)?.toDouble() ?? volumePercent)
              .clamp(0.0, 1.0);
      isMuted = (volMap['isMuted'] as bool?) ?? isMuted;
    }

    state = state.copyWith(
      hasMediaPermission: hasPerm,
      hasActiveSession: hasActive,
      title: title,
      artist: artist,
      album: album,
      durationMs: durationMs,
      positionMs: positionMs,
      isPlaying: isPlaying,
      sourcePackage: sourcePkg,
      sourceAppName: sourceName,
      albumArtBytes: artBytes,
      clearAlbumArt: artBytes == null,
      currentStep: currentStep,
      maxStep: maxStep,
      volumePercent: volumePercent,
      isMuted: isMuted,
    );
  }

  /// Abre el ajuste de Android una sola vez para autorizar la lectura de carátulas y sesiones multimedia
  Future<void> openMediaPermissionSettings() async {
    try {
      await _channel.invokeMethod<bool>('openMediaListenerSettings');
    } catch (_) {}
  }

  /// Abre la aplicación del reproductor activo actual (ej. Spotify)
  Future<void> openActivePlayerApp() async {
    HapticFeedback.lightImpact();
    try {
      await _channel.invokeMethod<bool>(
        'launchExternalApp',
        <String, dynamic>{
          'packageName': state.sourcePackage,
          'fallbackUrl': 'https://open.spotify.com',
        },
      );
    } catch (_) {}
  }

  /// Controles de reproducción (Play/Pause, Siguiente, Anterior)
  Future<void> sendMediaTransportCommand(String command) async {
    HapticFeedback.lightImpact();
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'sendMediaKey',
        <String, dynamic>{'command': command},
      );
      if (raw != null) {
        _applyMediaSessionMap(raw);
      }
      await Future<void>.delayed(const Duration(milliseconds: 220));
      await _pollSystemMediaSession();
    } catch (_) {}
  }

  /// Permite adelantar o atrasar la canción desde la barra de progreso
  Future<void> seekToRatio(double ratio) async {
    if (state.durationMs <= 0) return;
    final targetMs = (ratio.clamp(0.0, 1.0) * state.durationMs).round();
    state = state.copyWith(positionMs: targetMs);
    try {
      await _channel.invokeMethod<bool>(
        'seekMediaTo',
        <String, dynamic>{'positionMs': targetMs},
      );
    } catch (_) {}
  }

  /// Controla directamente el volumen de la tablet desde el Slider
  /// (Mover manualmente el slider desactiva el modo ATT si estaba activo)
  Future<void> setTabletVolume(double nextPercent, {bool showUi = false}) async {
    final clamped = nextPercent.clamp(0.0, 1.0);
    state = state.copyWith(
      volumePercent: clamped,
      currentStep: (clamped * state.maxStep).round(),
      isMuted: clamped == 0.0,
      isAttenuated: false,
    );
    try {
      await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'setVolume',
        <String, dynamic>{
          'percent': clamped,
          'showUi': showUi,
        },
      );
    } catch (_) {}
  }

  /// Sube o baja 1 paso el volumen de la tablet
  Future<void> adjustVolumeStep(int delta) async {
    HapticFeedback.selectionClick();
    state = state.copyWith(isAttenuated: false);
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'adjustVolumeStep',
        <String, dynamic>{
          'delta': delta,
          'toggleMute': false,
        },
      );
      if (raw != null) {
        final current = (raw['current'] as num?)?.toInt() ?? state.currentStep;
        final max = (raw['max'] as num?)?.toInt() ?? state.maxStep;
        final pct = (raw['percent'] as num?)?.toDouble() ?? state.volumePercent;
        state = state.copyWith(
          currentStep: current,
          maxStep: max,
          volumePercent: pct.clamp(0.0, 1.0),
        );
      }
    } catch (_) {}
  }

  /// Botón **ATT (Atenuación)**:
  /// - 1er toque: Guarda el volumen actual y lo reduce un 75% de donde está (quedando al 25% de su nivel previo).
  /// - 2do toque: Restaura el volumen exactamente a donde estaba antes de tocar ATT.
  Future<void> toggleAttenuation() async {
    HapticFeedback.mediumImpact();
    if (!state.isAttenuated) {
      final originalVol = state.volumePercent > 0.04 ? state.volumePercent : 0.60;
      final attenuatedVol = (originalVol * 0.25).clamp(0.0, 1.0); // Baja un 75% de donde está
      state = state.copyWith(
        preAttVolumePercent: originalVol,
        isAttenuated: true,
        volumePercent: attenuatedVol,
        currentStep: (attenuatedVol * state.maxStep).round(),
      );
      try {
        await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'setVolume',
          <String, dynamic>{
            'percent': attenuatedVol,
            'showUi': true,
          },
        );
      } catch (_) {}
    } else {
      final restoredVol = (state.preAttVolumePercent ?? 0.65).clamp(0.0, 1.0);
      state = state.copyWith(
        isAttenuated: false,
        volumePercent: restoredVol,
        currentStep: (restoredVol * state.maxStep).round(),
      );
      try {
        await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'setVolume',
          <String, dynamic>{
            'percent': restoredVol,
            'showUi': true,
          },
        );
      } catch (_) {}
    }
  }
}

final multimediaHubProvider =
    NotifierProvider<MultimediaHubNotifier, MultimediaHubState>(
  MultimediaHubNotifier.new,
);

/// Menú **MULTIMEDIA** limpio y relajado:
/// 1) Reproductor principal conectado al evento multimedia del sistema Android
///    (Carátula del álbum, título, artista, barra de progreso interactiva y controles).
/// 2) Barra inferior de volumen con Slider nativo de la tablet y botón **ATT** (-75% / restaurar).
class MultimediaHubScreen extends ConsumerWidget {
  const MultimediaHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaState = ref.watch(multimediaHubProvider);
    final mediaNotifier = ref.read(multimediaHubProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactHeight = constraints.maxHeight < 430;

        if (isCompactHeight) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 310,
                  child: _SystemMediaPlayerCard(
                    state: mediaState,
                    notifier: mediaNotifier,
                  ),
                ),
                const SizedBox(height: 10),
                _VolumeAndAttenuationBar(
                  state: mediaState,
                  notifier: mediaNotifier,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Reproductor Principal (Carátula, Canción, Progreso y Controles)
            Expanded(
              child: _SystemMediaPlayerCard(
                state: mediaState,
                notifier: mediaNotifier,
              ),
            ),
            const SizedBox(height: 10),

            // 2. Barra Inferior de Volumen + Botón ATT (-75%)
            _VolumeAndAttenuationBar(
              state: mediaState,
              notifier: mediaNotifier,
            ),
          ],
        );
      },
    );
  }
}

class _SystemMediaPlayerCard extends StatelessWidget {
  final MultimediaHubState state;
  final MultimediaHubNotifier notifier;

  const _SystemMediaPlayerCard({
    required this.state,
    required this.notifier,
  });

  static String _formatMs(int ms) {
    final totalSeconds = (ms ~/ 1000).clamp(0, 35999);
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              primary.withValues(alpha: isDark ? 0.14 : 0.08),
              Colors.transparent,
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isHorizontal = constraints.maxWidth >= 620;
            final maxArtworkSize = isHorizontal
                ? (constraints.maxHeight * 0.78).clamp(130.0, 250.0)
                : (constraints.maxHeight * 0.38).clamp(100.0, 165.0);

            final artworkWidget = Center(
              child: Container(
                width: maxArtworkSize,
                height: maxArtworkSize,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF141821)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.45),
                    width: 1.6,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.38),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: state.albumArtBytes != null
                    ? Image.memory(
                        state.albumArtBytes!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.album_rounded,
                            size: maxArtworkSize * 0.62,
                            color: primary.withValues(alpha: 0.28),
                          ),
                          Icon(
                            Icons.music_note_rounded,
                            size: maxArtworkSize * 0.24,
                            color: primary,
                          ),
                        ],
                      ),
              ),
            );

            final detailsAndControls = Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: isHorizontal
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Etiqueta de la fuente actual + Acceso rápido a permisos si falta
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    InkWell(
                      onTap: notifier.openActivePlayerApp,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.graphic_eq_rounded,
                              size: 15,
                              color: primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              state.sourceAppName.toUpperCase(),
                              style: AppTheme.telemetryNumericStyle(
                                fontSize: 11,
                                color: primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 12,
                              color: primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!state.hasMediaPermission)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                        ),
                        onPressed: notifier.openMediaPermissionSettings,
                        icon: const Icon(
                          Icons.art_track_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          'HABILITAR LECTURA DE CARÁTULA',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Título de la Canción
                Text(
                  state.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: isHorizontal ? TextAlign.start : TextAlign.center,
                  style: AppTheme.renaultSportHeaderStyle(
                    fontSize: isHorizontal ? 24 : 19,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),

                // Artista y Álbum
                Text(
                  state.album.isNotEmpty
                      ? '${state.artist}  •  ${state.album}'
                      : state.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: isHorizontal ? TextAlign.start : TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),

                const SizedBox(height: 16),

                // Barra de Progreso de la Canción + Tiempos
                Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                      ),
                      child: Slider(
                        value: state.progressRatio,
                        min: 0.0,
                        max: 1.0,
                        onChanged: state.durationMs > 0
                            ? (val) => notifier.seekToRatio(val)
                            : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatMs(state.positionMs),
                            style: AppTheme.telemetryNumericStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          Text(
                            _formatMs(state.durationMs),
                            style: AppTheme.telemetryNumericStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Controles de Transporte Multimedia (Anterior, Play/Pause, Siguiente)
                Row(
                  mainAxisAlignment: isHorizontal
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    _MediaCircleButton(
                      icon: Icons.skip_previous_rounded,
                      size: 54,
                      iconSize: 28,
                      color: primary,
                      onTap: () =>
                          notifier.sendMediaTransportCommand('previous'),
                    ),
                    const SizedBox(width: 22),
                    _MediaCircleButton(
                      icon: state.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 68,
                      iconSize: 38,
                      color: primary,
                      filled: true,
                      onTap: () =>
                          notifier.sendMediaTransportCommand('play_pause'),
                    ),
                    const SizedBox(width: 22),
                    _MediaCircleButton(
                      icon: Icons.skip_next_rounded,
                      size: 54,
                      iconSize: 28,
                      color: primary,
                      onTap: () => notifier.sendMediaTransportCommand('next'),
                    ),
                  ],
                ),
              ],
            );

            if (isHorizontal) {
              return Row(
                children: [
                  artworkWidget,
                  const SizedBox(width: 28),
                  Expanded(
                    child: SingleChildScrollView(
                      child: detailsAndControls,
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  artworkWidget,
                  const SizedBox(height: 14),
                  detailsAndControls,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MediaCircleButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _MediaCircleButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : color.withValues(alpha: 0.14),
          border: Border.all(
            color: color,
            width: 1.8,
          ),
          boxShadow: filled
              ? <BoxShadow>[
                  BoxShadow(
                    color: color.withValues(alpha: 0.38),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: filled ? (isDark ? Colors.black : Colors.white) : color,
        ),
      ),
    );
  }
}

/// Barra inferior dedicada al Volumen de la Tablet + Botón **ATT** (Atenuación -75%)
class _VolumeAndAttenuationBar extends StatelessWidget {
  final MultimediaHubState state;
  final MultimediaHubNotifier notifier;

  const _VolumeAndAttenuationBar({
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final pctInt = (state.volumePercent * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            // Icono de Volumen + Porcentaje
            Icon(
              state.isAttenuated
                  ? Icons.volume_down_rounded
                  : (pctInt == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded),
              color: state.isAttenuated
                  ? RenaultSportPalette.siriusLiquidYellow
                  : primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 52,
              child: Text(
                '$pctInt%',
                style: AppTheme.telemetryNumericStyle(
                  fontSize: 15,
                  color: state.isAttenuated
                      ? RenaultSportPalette.siriusLiquidYellow
                      : primary,
                ),
              ),
            ),

            // Botón Bajar Volumen (-)
            IconButton(
              tooltip: 'Bajar Volumen',
              onPressed: () => notifier.adjustVolumeStep(-1),
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),

            // Slider de Volumen Físico de la Tablet
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 10,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12,
                  ),
                ),
                child: Slider(
                  value: state.volumePercent,
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

            // Botón Subir Volumen (+)
            IconButton(
              tooltip: 'Subir Volumen',
              onPressed: () => notifier.adjustVolumeStep(1),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),

            const SizedBox(width: 10),

            // Botón ATT (Atenuación -75% con un toque / Restaurar con otro toque)
            InkWell(
              onTap: notifier.toggleAttenuation,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: state.isAttenuated
                      ? RenaultSportPalette.siriusLiquidYellow
                      : RenaultSportPalette.siriusLiquidYellow
                          .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: RenaultSportPalette.siriusLiquidYellow,
                    width: 1.8,
                  ),
                  boxShadow: state.isAttenuated
                      ? <BoxShadow>[
                          BoxShadow(
                            color: RenaultSportPalette.siriusLiquidYellow
                                .withValues(alpha: 0.45),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.graphic_eq_rounded,
                      size: 18,
                      color: state.isAttenuated
                          ? Colors.black
                          : RenaultSportPalette.siriusLiquidYellow,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.isAttenuated ? 'ATT ON (-75%)' : 'ATT',
                      style: AppTheme.renaultSportHeaderStyle(
                        fontSize: 13.5,
                        color: state.isAttenuated
                            ? Colors.black
                            : RenaultSportPalette.siriusLiquidYellow,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
