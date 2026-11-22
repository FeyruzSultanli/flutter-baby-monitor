package com.example.bebek_monitor_clean

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var offlineAudio: OfflineAudio? = null
    private var monitorChannel: MethodChannel? = null
    private var deviceChannels: DeviceChannels? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        offlineAudio = OfflineAudio(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        deviceChannels = DeviceChannels(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        monitorChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ninni/monitor_service").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val intent = Intent(this@MainActivity, MonitorService::class.java).apply {
                            action = MonitorService.ACTION_START
                            putExtra(MonitorService.EXTRA_TITLE, call.argument<String>("title"))
                            putExtra(MonitorService.EXTRA_TEXT, call.argument<String>("text"))
                            putStringArrayListExtra(
                                MonitorService.EXTRA_TYPES,
                                ArrayList(call.argument<List<String>>("types") ?: emptyList()),
                            )
                        }
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("start_failed", e.message, null)
                        }
                    }
                    "stop" -> {
                        try {
                            stopService(Intent(this@MainActivity, MonitorService::class.java))
                        } catch (_: Exception) {
                        }
                        result.success(true)
                    }
                    "status" -> result.success(
                        mapOf("running" to MonitorService.isRunning, "error" to MonitorService.lastError),
                    )
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        monitorChannel?.setMethodCallHandler(null)
        monitorChannel = null
        deviceChannels?.dispose()
        deviceChannels = null
        offlineAudio?.dispose()
        offlineAudio = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
