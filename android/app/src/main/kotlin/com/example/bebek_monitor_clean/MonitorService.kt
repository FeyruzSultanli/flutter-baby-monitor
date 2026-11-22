package com.example.bebek_monitor_clean

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log

/**
 * Foreground service that keeps the app process at foreground priority while
 * the baby phone broadcasts (camera / microphone / Nearby) or the parent phone
 * listens in the background (media playback). All streaming work stays in the
 * Flutter engine of MainActivity; this service only holds the notification,
 * a partial wake lock and a Wi-Fi lock (V2 5.10 / 5.12).
 *
 * A small own service instead of a plugin: the plugin we evaluated creates a
 * second Flutter engine with every plugin registered (DECISIONS A18).
 */
class MonitorService : Service() {
    companion object {
        private const val TAG = "MonitorService"
        const val ACTION_START = "ninni.monitor.START"
        const val ACTION_STOP = "ninni.monitor.STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_TYPES = "types"
        const val CHANNEL_ID = "ninni_monitor_service"
        private const val NOTIFICATION_ID = 4242

        @Volatile
        var isRunning: Boolean = false
            private set

        @Volatile
        var lastError: String? = null
            private set

        fun typeMask(types: List<String>): Int {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return 0
            var mask = 0
            for (t in types) {
                mask = mask or when (t) {
                    "camera" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA else 0
                    "microphone" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE else 0
                    "connectedDevice" -> ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
                    "mediaPlayback" -> ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                    else -> 0
                }
            }
            return mask
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null || intent.action == ACTION_STOP) {
            // null intent: restarted by the system without our Flutter state;
            // nothing to keep alive, so do not show an orphan notification.
            stopSelfCleanly()
            return START_NOT_STICKY
        }
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "Ninni"
        val text = intent.getStringExtra(EXTRA_TEXT) ?: ""
        val types = intent.getStringArrayListExtra(EXTRA_TYPES) ?: arrayListOf()
        try {
            val notification = buildNotification(title, text)
            val mask = typeMask(types)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && mask != 0) {
                startForeground(NOTIFICATION_ID, notification, mask)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            acquireLocks()
            isRunning = true
            lastError = null
        } catch (e: Exception) {
            // e.g. SecurityException (permission for a type missing) or
            // ForegroundServiceStartNotAllowedException (app in background).
            Log.e(TAG, "startForeground failed", e)
            lastError = e.javaClass.simpleName + ": " + (e.message ?: "")
            stopSelfCleanly()
        }
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // The Flutter engine lives with the activity task; without it there is
        // nothing to keep running.
        stopSelfCleanly()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        releaseLocks()
        isRunning = false
        super.onDestroy()
    }

    private fun stopSelfCleanly() {
        releaseLocks()
        isRunning = false
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (_: Exception) {
        }
        stopSelf()
    }

    private fun buildNotification(title: String, text: String): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Ninni",
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.setShowBadge(false)
            manager.createNotificationChannel(channel)
        }
        val launch = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        }
        var piFlags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) piFlags = piFlags or PendingIntent.FLAG_IMMUTABLE
        val content = launch?.let { PendingIntent.getActivity(this, 0, it, piFlags) }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }
        builder
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
        if (content != null) builder.setContentIntent(content)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }

    private fun acquireLocks() {
        if (wakeLock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ninni:monitor").apply {
                setReferenceCounted(false)
                acquire()
            }
        }
        if (wifiLock == null) {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
            } else {
                WifiManager.WIFI_MODE_FULL_HIGH_PERF
            }
            wifiLock = wm.createWifiLock(mode, "ninni:monitor").apply {
                setReferenceCounted(false)
                acquire()
            }
        }
    }

    private fun releaseLocks() {
        try {
            wakeLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) {
        }
        wakeLock = null
        try {
            wifiLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) {
        }
        wifiLock = null
    }
}
