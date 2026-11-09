package com.rs.digital.cockpit

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.view.KeyEvent
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.Executors
import kotlin.math.roundToInt

/**
 * MainActivity para RS Digital Cockpit (`com.rs.digital.cockpit`).
 * Soporta Biometría (local_auth), Stripe, Car Launcher Dock, Control Multimedia/Volumen
 * estilo Android Auto (`AudioManager`) y Bluetooth Classic RFCOMM (ELM327).
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Canal del Car Launcher + Multimedia / Control de Volumen Nativo (Android Auto Style)
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
                    "getInstalledMediaApps" -> {
                        result.success(discoverInstalledMediaApps())
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

    private fun dispatchSystemMediaKey(command: String): Map<String, Any> {
        return try {
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
            readAudioVolumeState()
        } catch (_: Exception) {
            readAudioVolumeState()
        }
    }

    private fun discoverInstalledMediaApps(): List<Map<String, Any>> {
        val results = mutableListOf<Map<String, Any>>()
        return try {
            val pm = packageManager
            val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            val resolveInfos = pm.queryIntentActivities(mainIntent, 0)
            val seenPackages = mutableSetOf<String>()

            for (info in resolveInfos) {
                val pkg = info.activityInfo?.packageName ?: continue
                if (pkg == packageName || !seenPackages.add(pkg)) continue
                val appInfo = info.activityInfo.applicationInfo
                val isAudioOrVideoCategory = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    appInfo.category == ApplicationInfo.CATEGORY_AUDIO ||
                        appInfo.category == ApplicationInfo.CATEGORY_VIDEO
                } else {
                    false
                }
                val label = info.loadLabel(pm).toString()
                results.add(
                    mapOf(
                        "name" to label,
                        "packageName" to pkg,
                        "isMediaCategory" to isAudioOrVideoCategory
                    )
                )
            }
            results
        } catch (_: Exception) {
            results
        }
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
