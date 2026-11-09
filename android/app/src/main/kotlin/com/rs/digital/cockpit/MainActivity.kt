package com.rs.digital.cockpit

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.view.KeyEvent
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.Executors
import kotlin.math.roundToInt

/**
 * Servicio puente del sistema Android para permitir que `MediaSessionManager`
 * lea la carátula (Bitmap), canción, artista y progreso del reproductor activo.
 */
class RsMediaNotificationListenerService : NotificationListenerService()

/**
 * MainActivity para RS Digital Cockpit (`com.rs.digital.cockpit`).
 * Soporta Biometría (local_auth), Stripe, Car Launcher Dock, Lector del Reproductor
 * Multimedia del Sistema Android (`MediaSessionManager` + `AudioManager`) y Bluetooth Classic RFCOMM (ELM327).
 */
class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val LAUNCHER_CHANNEL = "com.renaultsport.clio172/launcher"
        private const val RFCOMM_CHANNEL = "com.renaultsport.clio172/rfcomm"
        private const val BT_PERMISSION_REQ_CODE = 1720
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }

    private var bluetoothSocket: BluetoothSocket? = null
    private var inputStream: InputStream? = null
    private var outputStream: OutputStream? = null
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val ioLock = Any()

    // Caché ligera de carátula para no recomprimir el mismo Bitmap en cada ciclo
    private var cachedArtworkKey: String = ""
    private var cachedArtworkBytes: ByteArray? = null

    // Fallback por Broadcast para reproductores (Spotify / Android Music)
    private var broadcastTitle: String? = null
    private var broadcastArtist: String? = null
    private var broadcastAlbum: String? = null
    private var broadcastDurationMs: Long = 0L
    private var broadcastPositionMs: Long = 0L
    private var broadcastPositionTimestamp: Long = 0L
    private var broadcastIsPlaying: Boolean = false
    private var broadcastPackage: String? = null

    private val mediaBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null) return
            val action = intent.action ?: ""
            if (action.contains("spotify")) {
                broadcastPackage = "com.spotify.music"
            }
            intent.getStringExtra("track")?.let { broadcastTitle = it }
            intent.getStringExtra("artist")?.let { broadcastArtist = it }
            intent.getStringExtra("album")?.let { broadcastAlbum = it }
            if (intent.hasExtra("length")) {
                broadcastDurationMs = intent.getIntExtra("length", 0).toLong()
            } else if (intent.hasExtra("duration")) {
                broadcastDurationMs = intent.getLongExtra("duration", 0L)
            }
            if (intent.hasExtra("playbackPosition")) {
                broadcastPositionMs = intent.getIntExtra("playbackPosition", 0).toLong()
                broadcastPositionTimestamp = SystemClock.elapsedRealtime()
            } else if (intent.hasExtra("position")) {
                broadcastPositionMs = intent.getLongExtra("position", 0L)
                broadcastPositionTimestamp = SystemClock.elapsedRealtime()
            }
            if (intent.hasExtra("playing")) {
                broadcastIsPlaying = intent.getBooleanExtra("playing", false)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerMediaBroadcastReceiver()
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(mediaBroadcastReceiver)
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    @SuppressLint("UnspecifiedRegisterReceiverFlag")
    private fun registerMediaBroadcastReceiver() {
        try {
            val filter = IntentFilter().apply {
                addAction("com.spotify.music.metadatachanged")
                addAction("com.spotify.music.playbackstatechanged")
                addAction("com.android.music.metachanged")
                addAction("com.android.music.playstatechanged")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(mediaBroadcastReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(mediaBroadcastReceiver, filter)
            }
        } catch (_: Exception) {
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Canal del Car Launcher + Reproductor del Sistema Android + Volumen/ATT
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCHER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "launchExternalApp" -> {
                        val packageName = call.argument<String>("packageName")
                        val fallbackUrl = call.argument<String>("fallbackUrl")
                        val splitScreen = call.argument<Boolean>("splitScreen") ?: false
                        if (packageName == null) {
                            result.error("INVALID_ARGS", "packageName requerido", null)
                            return@setMethodCallHandler
                        }
                        result.success(launchAppOrFallback(packageName, fallbackUrl, splitScreen))
                    }
                    "getSystemMediaSession" -> {
                        result.success(readSystemMediaSessionState())
                    }
                    "seekMediaTo" -> {
                        val positionMs = (call.argument<Number>("positionMs")?.toLong()) ?: 0L
                        result.success(seekActiveMediaController(positionMs))
                    }
                    "openMediaListenerSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "getVolumeState" -> {
                        result.success(readAudioVolumeState())
                    }
                    "setVolume" -> {
                        val percent = call.argument<Double>("percent") ?: 0.5
                        val showUi = call.argument<Boolean>("showUi") ?: false
                        result.success(setMediaVolumePercent(percent, showUi))
                    }
                    "adjustVolumeStep" -> {
                        val delta = call.argument<Int>("delta") ?: 0
                        val toggleMute = call.argument<Boolean>("toggleMute") ?: false
                        result.success(adjustMediaVolumeStep(delta, toggleMute))
                    }
                    "sendMediaKey" -> {
                        val command = call.argument<String>("command") ?: "play_pause"
                        result.success(dispatchSystemMediaKey(command))
                    }
                    "openHomeLauncherSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_HOME_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "openBluetoothSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // 2. Canal Bluetooth Classic RFCOMM para Adaptador OBD2 ELM327
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RFCOMM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPairedDevices" -> {
                        if (!ensureBluetoothPermissions()) {
                            result.success(emptyList<Map<String, String>>())
                            return@setMethodCallHandler
                        }
                        result.success(getBondedElmDevices())
                    }
                    "connect" -> {
                        val address = call.argument<String>("address")
                        if (address == null) {
                            result.error("NO_MAC", "Dirección MAC requerida", null)
                            return@setMethodCallHandler
                        }
                        if (!ensureBluetoothPermissions()) {
                            result.error("BT_PERM", "Permiso Bluetooth pendiente", null)
                            return@setMethodCallHandler
                        }
                        ioExecutor.execute {
                            try {
                                connectRfcommSocket(address)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("RFCOMM_CONNECT_ERR", e.message, null)
                                }
                            }
                        }
                    }
                    "sendCommand" -> {
                        val command = call.argument<String>("command") ?: ""
                        val timeoutMs = call.argument<Int>("timeoutMs") ?: 1200
                        ioExecutor.execute {
                            try {
                                val rawResponse = sendRawElmCommand(command, timeoutMs)
                                runOnUiThread { result.success(rawResponse) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("RFCOMM_IO_ERR", e.message, null)
                                }
                            }
                        }
                    }
                    "disconnect" -> {
                        ioExecutor.execute {
                            closeRfcommSocket()
                            runOnUiThread { result.success(true) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        return try {
            val enabledListeners = Settings.Secure.getString(
                contentResolver,
                "enabled_notification_listeners"
            ) ?: return false
            enabledListeners.contains(packageName)
        } catch (_: Exception) {
            false
        }
    }

    private fun getPrimaryMediaController(): MediaController? {
        if (!isNotificationListenerEnabled()) return null
        return try {
            val manager = getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
                ?: return null
            val component = ComponentName(this, RsMediaNotificationListenerService::class.java)
            val controllers = manager.getActiveSessions(component)
            if (controllers.isEmpty()) return null
            controllers.firstOrNull {
                it.playbackState?.state == PlaybackState.STATE_PLAYING
            } ?: controllers.firstOrNull()
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveAppName(pkg: String?): String {
        if (pkg.isNullOrEmpty()) return "Reproductor del Sistema"
        return try {
            val appInfo = packageManager.getApplicationInfo(pkg, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (_: Exception) {
            if (pkg.contains("spotify")) "Spotify" else "Reproductor Multimedia"
        }
    }

    private fun readSystemMediaSessionState(): Map<String, Any?> {
        val volumeInfo = readAudioVolumeState()
        val hasPermission = isNotificationListenerEnabled()
        val controller = getPrimaryMediaController()

        if (controller != null) {
            val meta = controller.metadata
            val pb = controller.playbackState

            val title = meta?.getString(MediaMetadata.METADATA_KEY_TITLE)
                ?: meta?.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
                ?: broadcastTitle
                ?: "Sin reproducción activa"
            val artist = meta?.getString(MediaMetadata.METADATA_KEY_ARTIST)
                ?: meta?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
                ?: meta?.getString(MediaMetadata.METADATA_KEY_WRITER)
                ?: broadcastArtist
                ?: "Reproduce música en tu tablet"
            val album = meta?.getString(MediaMetadata.METADATA_KEY_ALBUM)
                ?: broadcastAlbum
                ?: ""
            val durationMs = (meta?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L)
                .coerceAtLeast(0L)

            val isPlaying = pb?.state == PlaybackState.STATE_PLAYING
            var positionMs = pb?.position ?: 0L
            if (isPlaying && pb != null && pb.lastPositionUpdateTime > 0L) {
                val elapsed = SystemClock.elapsedRealtime() - pb.lastPositionUpdateTime
                val speed = if (pb.playbackSpeed > 0f) pb.playbackSpeed else 1.0f
                positionMs += (elapsed * speed).toLong()
            }
            if (durationMs > 0L) {
                positionMs = positionMs.coerceIn(0L, durationMs)
            } else {
                positionMs = positionMs.coerceAtLeast(0L)
            }

            // Extraer Bitmap de la carátula del álbum
            val artKey = "${controller.packageName}|$title|$artist|$album"
            if (artKey != cachedArtworkKey) {
                val bmp: Bitmap? = meta?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
                    ?: meta?.getBitmap(MediaMetadata.METADATA_KEY_ART)
                    ?: meta?.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON)
                cachedArtworkBytes = if (bmp != null) compressArtworkBitmap(bmp) else null
                cachedArtworkKey = artKey
            }

            val srcPkg = controller.packageName
            return mapOf(
                "hasPermission" to hasPermission,
                "hasActiveSession" to true,
                "title" to title,
                "artist" to artist,
                "album" to album,
                "durationMs" to durationMs,
                "positionMs" to positionMs,
                "isPlaying" to isPlaying,
                "sourcePackage" to srcPkg,
                "sourceAppName" to resolveAppName(srcPkg),
                "albumArtBytes" to cachedArtworkBytes,
                "volume" to volumeInfo
            )
        }

        // Fallback si aún no se activó el acceso o si solo hay datos de Broadcast / AudioManager
        val audioActive = (volumeInfo["isMusicActive"] as? Boolean) ?: broadcastIsPlaying
        var estPos = broadcastPositionMs
        if (broadcastIsPlaying && broadcastPositionTimestamp > 0L) {
            estPos += (SystemClock.elapsedRealtime() - broadcastPositionTimestamp)
        }
        if (broadcastDurationMs > 0L) {
            estPos = estPos.coerceIn(0L, broadcastDurationMs)
        }

        return mapOf(
            "hasPermission" to hasPermission,
            "hasActiveSession" to (broadcastTitle != null || audioActive),
            "title" to (broadcastTitle ?: if (audioActive) "Audio en reproducción" else "Reproductor en espera"),
            "artist" to (broadcastArtist ?: if (hasPermission) "Inicia una canción en tu reproductor favorito" else "Conecta el lector multimedia para ver carátula y título"),
            "album" to (broadcastAlbum ?: ""),
            "durationMs" to broadcastDurationMs,
            "positionMs" to estPos,
            "isPlaying" to audioActive,
            "sourcePackage" to (broadcastPackage ?: "com.spotify.music"),
            "sourceAppName" to resolveAppName(broadcastPackage),
            "albumArtBytes" to null,
            "volume" to volumeInfo
        )
    }

    private fun compressArtworkBitmap(source: Bitmap): ByteArray? {
        return try {
            val maxDim = 360
            val width = source.width
            val height = source.height
            val scaled = if (width > maxDim || height > maxDim) {
                val ratio = width.toFloat() / height.toFloat()
                val targetW = if (ratio >= 1f) maxDim else (maxDim * ratio).roundToInt().coerceAtLeast(1)
                val targetH = if (ratio >= 1f) (maxDim / ratio).roundToInt().coerceAtLeast(1) else maxDim
                Bitmap.createScaledBitmap(source, targetW, targetH, true)
            } else {
                source
            }
            val out = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 86, out)
            out.toByteArray()
        } catch (_: Exception) {
            null
        }
    }

    private fun seekActiveMediaController(positionMs: Long): Boolean {
        return try {
            val controller = getPrimaryMediaController() ?: return false
            controller.transportControls.seekTo(positionMs.coerceAtLeast(0L))
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun readAudioVolumeState(): Map<String, Any> {
        return try {
            val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val current = audio.getStreamVolume(AudioManager.STREAM_MUSIC)
            val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
            val isMuted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                audio.isStreamMute(AudioManager.STREAM_MUSIC)
            } else {
                current == 0
            }
            val percent = (current.toDouble() / max.toDouble()).coerceIn(0.0, 1.0)
            mapOf(
                "current" to current,
                "max" to max,
                "percent" to percent,
                "isMuted" to isMuted,
                "isMusicActive" to audio.isMusicActive
            )
        } catch (_: Exception) {
            mapOf(
                "current" to 10,
                "max" to 15,
                "percent" to 0.66,
                "isMuted" to false,
                "isMusicActive" to false
            )
        }
    }

    private fun setMediaVolumePercent(percent: Double, showUi: Boolean): Map<String, Any> {
        return try {
            val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
            val targetStep = (percent.coerceIn(0.0, 1.0) * max).roundToInt().coerceIn(0, max)
            val flags = if (showUi) AudioManager.FLAG_SHOW_UI else 0
            audio.setStreamVolume(AudioManager.STREAM_MUSIC, targetStep, flags)
            readAudioVolumeState()
        } catch (_: Exception) {
            readAudioVolumeState()
        }
    }

    private fun adjustMediaVolumeStep(delta: Int, toggleMute: Boolean): Map<String, Any> {
        return try {
            val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (toggleMute && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                audio.adjustStreamVolume(
                    AudioManager.STREAM_MUSIC,
                    AudioManager.ADJUST_TOGGLE_MUTE,
                    AudioManager.FLAG_SHOW_UI
                )
            } else if (delta > 0) {
                audio.adjustStreamVolume(
                    AudioManager.STREAM_MUSIC,
                    AudioManager.ADJUST_RAISE,
                    AudioManager.FLAG_SHOW_UI
                )
            } else if (delta < 0) {
                audio.adjustStreamVolume(
                    AudioManager.STREAM_MUSIC,
                    AudioManager.ADJUST_LOWER,
                    AudioManager.FLAG_SHOW_UI
                )
            }
            readAudioVolumeState()
        } catch (_: Exception) {
            readAudioVolumeState()
        }
    }

    private fun dispatchSystemMediaKey(command: String): Map<String, Any?> {
        try {
            val controller = getPrimaryMediaController()
            if (controller != null) {
                val controls = controller.transportControls
                val isPlaying = controller.playbackState?.state == PlaybackState.STATE_PLAYING
                when (command) {
                    "next" -> controls.skipToNext()
                    "previous" -> controls.skipToPrevious()
                    "play" -> controls.play()
                    "pause" -> controls.pause()
                    "stop" -> controls.stop()
                    else -> if (isPlaying) controls.pause() else controls.play()
                }
                return readSystemMediaSessionState()
            }

            val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val keyCode = when (command) {
                "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
                "previous" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
                "play" -> KeyEvent.KEYCODE_MEDIA_PLAY
                "pause" -> KeyEvent.KEYCODE_MEDIA_PAUSE
                "stop" -> KeyEvent.KEYCODE_MEDIA_STOP
                else -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            }
            val now = SystemClock.uptimeMillis()
            val downEvent = KeyEvent(now, now, KeyEvent.ACTION_DOWN, keyCode, 0)
            val upEvent = KeyEvent(now, now, KeyEvent.ACTION_UP, keyCode, 0)
            audio.dispatchMediaKeyEvent(downEvent)
            audio.dispatchMediaKeyEvent(upEvent)
        } catch (_: Exception) {
        }
        return readSystemMediaSessionState()
    }

    private fun ensureBluetoothPermissions(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val hasConnect = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
            val hasScan = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_SCAN
            ) == PackageManager.PERMISSION_GRANTED

            if (!hasConnect || !hasScan) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(
                        Manifest.permission.BLUETOOTH_CONNECT,
                        Manifest.permission.BLUETOOTH_SCAN
                    ),
                    BT_PERMISSION_REQ_CODE
                )
                return false
            }
        }
        return true
    }

    private fun launchAppOrFallback(
        packageName: String,
        fallbackUrl: String?,
        splitScreen: Boolean = false
    ): Boolean {
        return try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                if (splitScreen) {
                    launchIntent.addFlags(
                        Intent.FLAG_ACTIVITY_LAUNCH_ADJACENT or
                            Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_MULTIPLE_TASK
                    )
                } else {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(launchIntent)
                true
            } else if (!fallbackUrl.isNullOrEmpty()) {
                val uriIntent = Intent(Intent.ACTION_VIEW, Uri.parse(fallbackUrl)).apply {
                    if (splitScreen) {
                        addFlags(
                            Intent.FLAG_ACTIVITY_LAUNCH_ADJACENT or
                                Intent.FLAG_ACTIVITY_NEW_TASK
                        )
                    } else {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                }
                startActivity(uriIntent)
                true
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }
    }

    @SuppressLint("MissingPermission")
    private fun getBondedElmDevices(): List<Map<String, String>> {
        return try {
            val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            val adapter: BluetoothAdapter? = btManager?.adapter
            val bonded: Set<BluetoothDevice> = adapter?.bondedDevices ?: emptySet()
            bonded.map { device ->
                mapOf(
                    "name" to (device.name ?: "OBD-II Bluetooth"),
                    "address" to device.address
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    @SuppressLint("MissingPermission")
    private fun connectRfcommSocket(macAddress: String) {
        synchronized(ioLock) {
            closeRfcommSocket()
            val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            val adapter = btManager.adapter ?: throw IllegalStateException("Bluetooth apagado")
            val device = adapter.getRemoteDevice(macAddress)
            try {
                adapter.cancelDiscovery()
            } catch (_: Exception) {
            }

            var socket: BluetoothSocket? = null
            try {
                socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect()
            } catch (_: Exception) {
                try {
                    socket?.close()
                } catch (_: Exception) {
                }
                socket = device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect()
            }

            bluetoothSocket = socket
            inputStream = socket?.inputStream
            outputStream = socket?.outputStream
        }
    }

    private fun sendRawElmCommand(cmd: String, timeoutMs: Int): String {
        synchronized(ioLock) {
            val out = outputStream ?: throw IllegalStateException("OBD2 desconectado")
            val inp = inputStream ?: throw IllegalStateException("OBD2 desconectado")

            try {
                while (inp.available() > 0) {
                    inp.read()
                }
            } catch (_: Exception) {
            }

            val payload = "${cmd.trim()}\r".toByteArray(Charsets.US_ASCII)
            out.write(payload)
            out.flush()

            val sb = StringBuilder()
            val buffer = ByteArray(128)
            val startTime = System.currentTimeMillis()
            var promptReceived = false
            while (System.currentTimeMillis() - startTime < timeoutMs && !promptReceived) {
                val avail = inp.available()
                if (avail > 0) {
                    val toRead = if (avail > buffer.size) buffer.size else avail
                    val bytesRead = inp.read(buffer, 0, toRead)
                    if (bytesRead <= 0) break
                    for (i in 0 until bytesRead) {
                        val ch = buffer[i].toInt().toChar()
                        if (ch == '>') {
                            promptReceived = true
                            break
                        }
                        sb.append(ch)
                    }
                } else {
                    Thread.sleep(1)
                }
            }

            return sb.toString()
                .replace("\r", " ")
                .replace("\n", " ")
                .replace(Regex("\\s+"), " ")
                .trim()
        }
    }

    private fun closeRfcommSocket() {
        synchronized(ioLock) {
            try {
                inputStream?.close()
                outputStream?.close()
                bluetoothSocket?.close()
            } catch (_: Exception) {
            } finally {
                inputStream = null
                outputStream = null
                bluetoothSocket = null
            }
        }
    }
}
