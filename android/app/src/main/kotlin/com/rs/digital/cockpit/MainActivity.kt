package com.rs.digital.cockpit

import android.Manifest
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
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.Executors

/**
 * MainActivity para RS Digital Cockpit (`com.rs.digital.cockpit`).
 * Soporta Biometría (local_auth), Stripe, Car Launcher Dock y Bluetooth Classic RFCOMM (ELM327).
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Canal del Car Launcher (Accesos directos y ajustes de sistema)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCHER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "launchExternalApp" -> {
                        val packageName = call.argument<String>("packageName")
                        val fallbackUrl = call.argument<String>("fallbackUrl")
                        if (packageName == null) {
                            result.error("INVALID_ARGS", "packageName requerido", null)
                            return@setMethodCallHandler
                        }
                        result.success(launchAppOrFallback(packageName, fallbackUrl))
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
        closeRfcommSocket()
        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter = btManager.adapter ?: throw IllegalStateException("Bluetooth apagado")
        val device = adapter.getRemoteDevice(macAddress)
        adapter.cancelDiscovery()
        val socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
        socket.connect()
        bluetoothSocket = socket
        inputStream = socket.inputStream
        outputStream = socket.outputStream
    }

    private fun sendRawElmCommand(cmd: String, timeoutMs: Int): String {
        val out = outputStream ?: throw IllegalStateException("OBD2 desconectado")
        val inp = inputStream ?: throw IllegalStateException("OBD2 desconectado")

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

