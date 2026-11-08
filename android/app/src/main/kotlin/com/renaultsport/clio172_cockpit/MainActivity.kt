package com.renaultsport.clio172_cockpit

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.Executors

/**
 * MainActivity para Google Pixel Tablet (Android 17 / API 36).
 * Extiende FlutterFragmentActivity para compatibilidad total con Biometría (local_auth)
 * y Pasarela de Pagos (flutter_stripe), además de exponer MethodChannels nativos para:
 * 1) Car Launcher Dock (apertura de Spotify, Waze, Google Maps, YouTube Music y selector Home)
 * 2) Socket Bluetooth Classic RFCOMM (UUID SPP 00001101-0000-1000-8000-00805F9B34FB) hacia ELM327
 */
class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val LAUNCHER_CHANNEL = "com.renaultsport.clio172/launcher"
        private const val RFCOMM_CHANNEL = "com.renaultsport.clio172/rfcomm"
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }

    private var bluetoothSocket: BluetoothSocket? = null
    private var inputStream: InputStream? = null
    private var outputStream: OutputStream? = null
    private val ioExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Canal del Car Launcher (Android 17 Home Screen & Quick App Dock)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCHER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "launchExternalApp" -> {
                        val packageName = call.argument<String>("packageName")
                        val fallbackUrl = call.argument<String>("fallbackUrl")
                        if (packageName == null) {
                            result.error("INVALID_ARGS", "packageName es requerido", null)
                            return@setMethodCallHandler
                        }
                        val launched = launchAppOrFallback(packageName, fallbackUrl)
                        result.success(launched)
                    }
                    "openHomeLauncherSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_HOME_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "getInstalledCabinApps" -> {
                        result.success(getInstalledCabinApps())
                    }
                    else -> result.notImplemented()
                }
            }

        // 2. Canal Bluetooth Classic RFCOMM nativo para ELM327 (KWP2000 / Siemens Sirius 34)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RFCOMM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPairedDevices" -> {
                        result.success(getBondedElmDevices())
                    }
                    "connect" -> {
                        val address = call.argument<String>("address")
                        if (address == null) {
                            result.error("NO_MAC", "Dirección MAC Bluetooth requerida", null)
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
                        val timeoutMs = call.argument<Int>("timeoutMs") ?: 350
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

    private fun launchAppOrFallback(packageName: String, fallbackUrl: String?): Boolean {
        return try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(launchIntent)
                true
            } else if (!fallbackUrl.isNullOrEmpty()) {
                val uriIntent = Intent(Intent.ACTION_VIEW, Uri.parse(fallbackUrl)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(uriIntent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun getInstalledCabinApps(): List<Map<String, String>> {
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                mainIntent,
                PackageManager.ResolveInfoFlags.of(0L)
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(mainIntent, 0)
        }
        return resolveInfos.take(24).map { info ->
            mapOf(
                "name" to info.loadLabel(packageManager).toString(),
                "packageName" to info.activityInfo.packageName
            )
        }
    }

    @SuppressLint("MissingPermission")
    private fun getBondedElmDevices(): List<Map<String, String>> {
        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter: BluetoothAdapter? = btManager?.adapter
        val bonded: Set<BluetoothDevice> = adapter?.bondedDevices ?: emptySet()
        return bonded.map { device ->
            mapOf(
                "name" to (device.name ?: "ELM327 OBD-II"),
                "address" to device.address
            )
        }
    }

    @SuppressLint("MissingPermission")
    private fun connectRfcommSocket(macAddress: String) {
        closeRfcommSocket()
        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter = btManager.adapter ?: throw IllegalStateException("Bluetooth no disponible")
        val device = adapter.getRemoteDevice(macAddress)
        adapter.cancelDiscovery()
        val socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
        socket.connect()
        bluetoothSocket = socket
        inputStream = socket.inputStream
        outputStream = socket.outputStream
    }

    private fun sendRawElmCommand(cmd: String, timeoutMs: Int): String {
        val out = outputStream ?: throw IllegalStateException("Socket RFCOMM desconectado")
        val inp = inputStream ?: throw IllegalStateException("Socket RFCOMM desconectado")

        val payload = "${cmd.trim()}\r".toByteArray(Charsets.US_ASCII)
        out.write(payload)
        out.flush()

        val sb = StringBuilder()
        val startTime = System.currentTimeMillis()
        while (System.currentTimeMillis() - startTime < timeoutMs) {
            if (inp.available() > 0) {
                val ch = inp.read().toChar()
                if (ch == '>') {
                    break
                }
                sb.append(ch)
            } else {
                Thread.sleep(4)
            }
        }
        return sb.toString()
            .replace("\r", "")
            .replace("\n", "")
            .replace(" ", "")
            .trim()
    }

    private fun closeRfcommSocket() {
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

