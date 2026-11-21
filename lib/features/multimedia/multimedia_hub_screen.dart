import 'dart:async';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';

enum MediaRepeatMode { off, all, one }

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
  final String? albumArtUri;
  final bool shuffleEnabled;
  final MediaRepeatMode repeatMode;

  // Volumen físico y Atenuación (ATT -75%)
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
    this.albumArtUri,
    this.shuffleEnabled = false,
    this.repeatMode = MediaRepeatMode.off,
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

  bool get hasArtwork =>
      albumArtBytes != null ||
      (albumArtUri != null &&
          (albumArtUri!.startsWith('http://') ||
              albumArtUri!.startsWith('https://')));

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
    String? albumArtUri,
    bool clearAlbumArtUri = false,
    bool? shuffleEnabled,
    MediaRepeatMode? repeatMode,
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
      albumArtUri: clearAlbumArtUri ? null : (albumArtUri ?? this.albumArtUri),
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
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
      const Duration(milliseconds: 700),
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
    final artUri = raw['albumArtUri'] as String?;

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
      albumArtUri: artUri,
      clearAlbumArtUri: artUri == null,
      currentStep: currentStep,
      maxStep: maxStep,
      volumePercent: volumePercent,
      isMuted: isMuted,
    );
  }

  Future<void> openMediaPermissionSettings() async {
    try {
      await _channel.invokeMethod<bool>('openMediaListenerSettings');
    } catch (_) {}
  }

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

  Future<void> toggleShuffle() async {
    HapticFeedback.selectionClick();
    final nextVal = !state.shuffleEnabled;
    state = state.copyWith(shuffleEnabled: nextVal);
    try {
      await _channel.invokeMethod<bool>(
        'toggleShuffle',
        <String, dynamic>{'enabled': nextVal},
      );
    } catch (_) {}
  }

  Future<void> cycleRepeatMode() async {
    HapticFeedback.selectionClick();
    final nextMode = switch (state.repeatMode) {
      MediaRepeatMode.off => MediaRepeatMode.all,
      MediaRepeatMode.all => MediaRepeatMode.one,
      MediaRepeatMode.one => MediaRepeatMode.off,
    };
    state = state.copyWith(repeatMode: nextMode);
    final androidRepeatInt = switch (nextMode) {
      MediaRepeatMode.off => 0,
      MediaRepeatMode.one => 1,
      MediaRepeatMode.all => 2,
    };
    try {
      await _channel.invokeMethod<bool>(
        'toggleRepeat',
        <String, dynamic>{'mode': androidRepeatInt},
      );
    } catch (_) {}
  }

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

  /// Ajusta el volumen de la tablet silenciosamente (sin popup del sistema Android)
  Future<void> setTabletVolume(double nextPercent) async {
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
        <String, dynamic>{'percent': clamped},
      );
    } catch (_) {}
  }

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

  /// Botón **ATT** al lado izquierdo:
  /// - 1er toque: atenúa el volumen actual sin subirlo nunca si ya estaba bajo.
  /// - 2do toque: regresa el volumen exactamente a donde estaba antes de tocar ATT.
  Future<void> toggleAttenuation() async {
    HapticFeedback.mediumImpact();
    if (!state.isAttenuated) {
      var currentStep = state.currentStep;
      var maxStep = state.maxStep > 0 ? state.maxStep : 15;
      var originalVol = state.volumePercent;

      try {
        final volMap =
            await _channel.invokeMethod<Map<dynamic, dynamic>>('getVolumeState');
        if (volMap != null) {
          currentStep = (volMap['current'] as num?)?.toInt() ?? currentStep;
          maxStep = (volMap['max'] as num?)?.toInt() ?? maxStep;
          originalVol =
              ((volMap['percent'] as num?)?.toDouble() ?? originalVol)
                  .clamp(0.0, 1.0);
        }
      } catch (_) {}

      final int targetStep;
      if (currentStep <= 0) {
        targetStep = 0;
      } else {
        targetStep = (currentStep * 0.25).round().clamp(0, currentStep - 1);
      }

      final attenuatedVol = maxStep > 0
          ? (targetStep / maxStep).clamp(0.0, originalVol)
          : 0.0;

      state = state.copyWith(
        preAttVolumePercent: originalVol,
        isAttenuated: true,
        volumePercent: attenuatedVol,
        currentStep: targetStep,
        maxStep: maxStep,
        isMuted: targetStep == 0,
      );
      try {
        await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'setVolume',
          <String, dynamic>{'percent': attenuatedVol},
        );
      } catch (_) {}
    } else {
      final restoredVol =
          (state.preAttVolumePercent ?? state.volumePercent).clamp(0.0, 1.0);
      final maxStep = state.maxStep > 0 ? state.maxStep : 15;
      final restoredStep = (restoredVol * maxStep).round().clamp(0, maxStep);
      state = state.copyWith(
        isAttenuated: false,
        volumePercent: restoredVol,
        currentStep: restoredStep,
        isMuted: restoredStep == 0,
      );
      try {
        await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'setVolume',
          <String, dynamic>{'percent': restoredVol},
        );
      } catch (_) {}
    }
  }
}

final multimediaHubProvider =
    NotifierProvider<MultimediaHubNotifier, MultimediaHubState>(
  MultimediaHubNotifier.new,
);

/// Menú **MULTIMEDIA** rediseñado:
/// - Tarjeta principal con el arte de la canción a fondo completo + filtro claro translúcido.
/// - Interfaz limpia y centrada con botones Random (Shuffle), Anterior, Play/Pausa, Siguiente y Repeat.
/// - Barra de volumen inferior con botón **ATT** al lado izquierdo y slider silencioso (sin popup Android).
class MultimediaHubScreen extends ConsumerWidget {
  const MultimediaHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaState = ref.watch(multimediaHubProvider);
    final mediaNotifier = ref.read(multimediaHubProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactHeight = constraints.maxHeight < 420;

        if (isCompactHeight) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 310,
                  child: _FullArtworkCenteredPlayerCard(
                    state: mediaState,
                    notifier: mediaNotifier,
                  ),
                ),
                const SizedBox(height: 10),
                _VolumeBarWithLeftAtt(
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
            Expanded(
              child: _FullArtworkCenteredPlayerCard(
                state: mediaState,
                notifier: mediaNotifier,
              ),
            ),
            const SizedBox(height: 10),
            _VolumeBarWithLeftAtt(
              state: mediaState,
              notifier: mediaNotifier,
            ),
          ],
        );
      },
    );
  }
}

class _FullArtworkCenteredPlayerCard extends StatelessWidget {
  final MultimediaHubState state;
  final MultimediaHubNotifier notifier;

  const _FullArtworkCenteredPlayerCard({
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
    const inkColor = Color(0xFF0F172A);
    const mutedInkColor = Color(0xFF334155);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Fondo completo con el arte de la canción
          if (state.albumArtBytes != null)
            Image.memory(
              state.albumArtBytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            )
          else if (state.albumArtUri != null &&
              (state.albumArtUri!.startsWith('http://') ||
                  state.albumArtUri!.startsWith('https://')))
            CachedNetworkImage(
              imageUrl: state.albumArtUri!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _FallbackBackdrop(primary: primary),
            )
          else
            _FallbackBackdrop(primary: primary),

          // 2. Filtro claro translúcido con desenfoque sutil para legibilidad perfecta
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.62),
                    const Color(0xFFF1F5F9).withValues(alpha: 0.74),
                    const Color(0xFFE2E8F0).withValues(alpha: 0.80),
                  ],
                ),
              ),
            ),
          ),

          // 3. Interfaz Centrada de Metadatos, Progreso y Controles
          LayoutBuilder(
            builder: (context, cardConstraints) {
              final isNarrow = cardConstraints.maxWidth < 460;
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 16 : 28,
                    vertical: isNarrow ? 14 : 20,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Fuente activa + botón de permiso si aún no se habilita
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            InkWell(
                              onTap: notifier.openActivePlayerApp,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: inkColor.withValues(alpha: 0.16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.graphic_eq_rounded,
                                      size: 16,
                                      color: primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      state.sourceAppName.toUpperCase(),
                                      style: AppTheme.telemetryNumericStyle(
                                        fontSize: 11,
                                        color: inkColor,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 13,
                                      color: mutedInkColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!state.hasMediaPermission)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: inkColor,
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: notifier.openMediaPermissionSettings,
                                icon: const Icon(Icons.art_track_rounded,
                                    size: 16),
                                label: const Text(
                                  'HABILITAR CARÁTULAS',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                        ),

                        SizedBox(height: isNarrow ? 12 : 18),

                        // Título de la canción centrado
                        Text(
                          state.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTheme.renaultSportHeaderStyle(
                            fontSize: isNarrow ? 22 : 28,
                            color: inkColor,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Artista y álbum centrados
                        Text(
                          state.album.isNotEmpty
                              ? '${state.artist}  •  ${state.album}'
                              : state.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isNarrow ? 13.5 : 15,
                            fontWeight: FontWeight.w600,
                            color: mutedInkColor,
                          ),
                        ),

                        SizedBox(height: isNarrow ? 14 : 22),

                        // Barra de progreso interactiva centrada
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: inkColor,
                            inactiveTrackColor:
                                inkColor.withValues(alpha: 0.22),
                            thumbColor: primary,
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 15,
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
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatMs(state.positionMs),
                                style: AppTheme.telemetryNumericStyle(
                                  fontSize: 12,
                                  color: mutedInkColor,
                                ),
                              ),
                              Text(
                                _formatMs(state.durationMs),
                                style: AppTheme.telemetryNumericStyle(
                                  fontSize: 12,
                                  color: mutedInkColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Controles Centrados: Random, Anterior, Play/Pausa, Siguiente, Repeat
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // RANDOM (SHUFFLE)
                              _CenteredMediaButton(
                                icon: Icons.shuffle_rounded,
                                tooltip: 'Aleatorio (Random)',
                                size: 56,
                                iconSize: 27,
                                active: state.shuffleEnabled,
                                accentColor: primary,
                                inkColor: inkColor,
                                onTap: notifier.toggleShuffle,
                              ),
                              const SizedBox(width: 18),

                              // ANTERIOR
                              _CenteredMediaButton(
                                icon: Icons.skip_previous_rounded,
                                tooltip: 'Anterior',
                                size: 68,
                                iconSize: 36,
                                accentColor: primary,
                                inkColor: inkColor,
                                onTap: () => notifier
                                    .sendMediaTransportCommand('previous'),
                              ),
                              const SizedBox(width: 22),

                              // PLAY / PAUSA
                              _CenteredMediaButton(
                                icon: state.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                tooltip:
                                    state.isPlaying ? 'Pausar' : 'Reproducir',
                                size: 88,
                                iconSize: 48,
                                isPrimaryFocal: true,
                                accentColor: primary,
                                inkColor: inkColor,
                                onTap: () => notifier
                                    .sendMediaTransportCommand('play_pause'),
                              ),
                              const SizedBox(width: 22),

                              // SIGUIENTE
                              _CenteredMediaButton(
                                icon: Icons.skip_next_rounded,
                                tooltip: 'Siguiente',
                                size: 68,
                                iconSize: 36,
                                accentColor: primary,
                                inkColor: inkColor,
                                onTap: () =>
                                    notifier.sendMediaTransportCommand('next'),
                              ),
                              const SizedBox(width: 18),

                              // REPEAT (Off -> Todo -> 1 Canción)
                              _CenteredMediaButton(
                                icon: state.repeatMode == MediaRepeatMode.one
                                    ? Icons.repeat_one_rounded
                                    : Icons.repeat_rounded,
                                tooltip: switch (state.repeatMode) {
                                  MediaRepeatMode.off => 'Repetir: Desactivado',
                                  MediaRepeatMode.all => 'Repetir: Lista',
                                  MediaRepeatMode.one => 'Repetir: 1 Canción',
                                },
                                size: 56,
                                iconSize: 27,
                                active: state.repeatMode != MediaRepeatMode.off,
                                accentColor: primary,
                                inkColor: inkColor,
                                onTap: notifier.cycleRepeatMode,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FallbackBackdrop extends StatelessWidget {
  final Color primary;

  const _FallbackBackdrop({required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            primary.withValues(alpha: 0.45),
            const Color(0xFF94A3B8),
            const Color(0xFFCBD5E1),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.album_rounded,
          size: 220,
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

class _CenteredMediaButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final double size;
  final double iconSize;
  final Color accentColor;
  final Color inkColor;
  final bool isPrimaryFocal;
  final bool active;
  final VoidCallback onTap;

  const _CenteredMediaButton({
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.iconSize,
    required this.accentColor,
    required this.inkColor,
    required this.onTap,
    this.isPrimaryFocal = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isPrimaryFocal
        ? inkColor
        : active
            ? accentColor
            : Colors.white.withValues(alpha: 0.68);
    final fgColor = isPrimaryFocal
        ? Colors.white
        : active
            ? Colors.white
            : inkColor;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(
              color: isPrimaryFocal || active
                  ? Colors.transparent
                  : inkColor.withValues(alpha: 0.18),
              width: 1.4,
            ),
            boxShadow: isPrimaryFocal
                ? <BoxShadow>[
                    BoxShadow(
                      color: inkColor.withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, size: iconSize, color: fgColor),
        ),
      ),
    );
  }
}

/// Barra inferior de Volumen con **ATT** en el lado izquierdo y Slider silencioso (sin popup Android)
class _VolumeBarWithLeftAtt extends StatelessWidget {
  final MultimediaHubState state;
  final MultimediaHubNotifier notifier;

  const _VolumeBarWithLeftAtt({
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final pctInt = (state.volumePercent * 100).round();
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = isPortrait || constraints.maxWidth < 540;

        return Card(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 16,
              vertical: 10,
            ),
            child: Row(
              children: [
                // 1. Botón ATT al lado IZQUIERDO (-75% con 1 toque / restaurar con otro)
                InkWell(
                  onTap: notifier.toggleAttenuation,
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 10 : 16,
                      vertical: isCompact ? 8 : 10,
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
                                    .withValues(alpha: 0.4),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.graphic_eq_rounded,
                          size: isCompact ? 15 : 17,
                          color: state.isAttenuated
                              ? Colors.black
                              : RenaultSportPalette.siriusLiquidYellow,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'ATT',
                          style: AppTheme.renaultSportHeaderStyle(
                            fontSize: isCompact ? 12 : 13,
                            color: state.isAttenuated
                                ? Colors.black
                                : RenaultSportPalette.siriusLiquidYellow,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(width: isCompact ? 4 : 12),

                // 2. Botón Bajar Volumen (-)
                IconButton(
                  tooltip: 'Bajar Volumen',
                  visualDensity: isCompact
                      ? VisualDensity.compact
                      : VisualDensity.standard,
                  padding: EdgeInsets.all(isCompact ? 4 : 8),
                  constraints: isCompact
                      ? const BoxConstraints(minWidth: 34, minHeight: 34)
                      : null,
                  onPressed: () => notifier.adjustVolumeStep(-1),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),

                // 3. Slider de Volumen Físico (silencioso, sin popup de sistema)
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
                      onChanged: (val) => notifier.setTabletVolume(val),
                    ),
                  ),
                ),

                // 4. Botón Subir Volumen (+)
                IconButton(
                  tooltip: 'Subir Volumen',
                  visualDensity: isCompact
                      ? VisualDensity.compact
                      : VisualDensity.standard,
                  padding: EdgeInsets.all(isCompact ? 4 : 8),
                  constraints: isCompact
                      ? const BoxConstraints(minWidth: 34, minHeight: 34)
                      : null,
                  onPressed: () => notifier.adjustVolumeStep(1),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),

                // 5. En vertical / pantallas compactas ocultamos % e icono para dar amplitud al slider
                if (!isCompact) ...[
                  const SizedBox(width: 6),
                  Icon(
                    state.isAttenuated
                        ? Icons.volume_down_rounded
                        : (pctInt == 0
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded),
                    color: state.isAttenuated
                        ? RenaultSportPalette.siriusLiquidYellow
                        : primary,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 46,
                    child: Text(
                      '$pctInt%',
                      textAlign: TextAlign.right,
                      style: AppTheme.telemetryNumericStyle(
                        fontSize: 14.5,
                        color: state.isAttenuated
                            ? RenaultSportPalette.siriusLiquidYellow
                            : primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
