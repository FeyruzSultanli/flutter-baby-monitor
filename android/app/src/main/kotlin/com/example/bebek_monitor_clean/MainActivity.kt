package com.example.bebek_monitor_clean

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var offlineAudio: OfflineAudio? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        offlineAudio = OfflineAudio(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        offlineAudio?.dispose()
        offlineAudio = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
