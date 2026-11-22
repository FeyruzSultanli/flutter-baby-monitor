package com.example.bebek_monitor_clean

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * V2.1: small platform channels instead of extra packages.
 *
 * - `ninni/network` (events): true while the default network can reach the
 *   internet (NET_CAPABILITY_INTERNET), false when there is none (§3).
 *   connectivity_plus was not used because it pulls in an MPL-2.0 package.
 * - `ninni/device` (methods): `audioRoute` for the diagnostics screen (§1, §2).
 */
class DeviceChannels(private val context: Context, messenger: BinaryMessenger) {
    private val main = Handler(Looper.getMainLooper())
    private val connectivity =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var sink: EventChannel.EventSink? = null
    private var callback: ConnectivityManager.NetworkCallback? = null

    private val networkChannel = EventChannel(messenger, "ninni/network").apply {
        setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sink = events
                emit()
                register()
            }

            override fun onCancel(arguments: Any?) {
                unregister()
                sink = null
            }
        })
    }

    private val deviceChannel = MethodChannel(messenger, "ninni/device").apply {
        setMethodCallHandler { call, result ->
            when (call.method) {
                "audioRoute" -> result.success(audioRoute())
                "isOnline" -> result.success(isOnline())
                else -> result.notImplemented()
            }
        }
    }

    private fun isOnline(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            @Suppress("DEPRECATION")
            return connectivity.activeNetworkInfo?.isConnected == true
        }
        val network = connectivity.activeNetwork ?: return false
        val caps = connectivity.getNetworkCapabilities(network) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    private fun emit() {
        val online = try {
            isOnline()
        } catch (_: Exception) {
            true
        }
        main.post { sink?.success(online) }
    }

    private fun register() {
        if (callback != null) return
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = emit()
            override fun onLost(network: Network) = emit()
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) = emit()
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                connectivity.registerDefaultNetworkCallback(cb)
            } else {
                connectivity.registerNetworkCallback(
                    android.net.NetworkRequest.Builder()
                        .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET).build(),
                    cb,
                )
            }
            callback = cb
        } catch (_: Exception) {
        }
    }

    private fun unregister() {
        val cb = callback ?: return
        callback = null
        try {
            connectivity.unregisterNetworkCallback(cb)
        } catch (_: Exception) {
        }
    }

    private fun audioRoute(): Map<String, Any?> {
        val outputs = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            for (d in audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)) {
                outputs.add(deviceName(d.type))
            }
        }
        val mode = when (audio.mode) {
            AudioManager.MODE_NORMAL -> "normal"
            AudioManager.MODE_IN_CALL -> "inCall"
            AudioManager.MODE_IN_COMMUNICATION -> "inCommunication"
            AudioManager.MODE_RINGTONE -> "ringtone"
            else -> audio.mode.toString()
        }
        val communicationDevice = if (Build.VERSION.SDK_INT >= 31) {
            audio.communicationDevice?.let { deviceName(it.type) }
        } else {
            null
        }
        return mapOf(
            "platform" to "android",
            "mode" to mode,
            "speakerphone" to audio.isSpeakerphoneOn,
            "microphoneMute" to audio.isMicrophoneMute,
            "communicationDevice" to communicationDevice,
            "outputs" to outputs,
            "voiceCallVolume" to audio.getStreamVolume(AudioManager.STREAM_VOICE_CALL),
            "voiceCallMax" to audio.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL),
            "musicVolume" to audio.getStreamVolume(AudioManager.STREAM_MUSIC),
            "musicMax" to audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
        )
    }

    private fun deviceName(type: Int): String = when (type) {
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "speaker"
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "earpiece"
        AudioDeviceInfo.TYPE_WIRED_HEADSET, AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "wired"
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetoothSco"
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "bluetoothA2dp"
        AudioDeviceInfo.TYPE_USB_DEVICE, AudioDeviceInfo.TYPE_USB_HEADSET -> "usb"
        else -> "type$type"
    }

    fun dispose() {
        unregister()
        networkChannel.setStreamHandler(null)
        deviceChannel.setMethodCallHandler(null)
    }
}
