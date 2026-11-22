package com.example.bebek_monitor_clean

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Speaker for offline (Nearby) mode: plays raw PCM chunks, 16 kHz, mono,
 * 16-bit little-endian, through an [AudioTrack] on the media stream (so it
 * plays on the loudspeaker without switching to the in-call audio mode).
 *
 * "startPlayer" / "writeChunk" / "stopPlayer" on the method channel. The
 * microphone side uses the `record` package (Dart: PcmMicrophone).
 */
class OfflineAudio(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "OfflineAudio"
        const val METHOD_CHANNEL = "bebek_monitor/offline_audio"
        const val SAMPLE_RATE = 16000
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)

    // Writes block until the track has room, so they run on their own thread
    // instead of the platform (UI) thread.
    private var track: AudioTrack? = null
    private val playerExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    init {
        methodChannel.setMethodCallHandler(this)
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        stopPlayer()
        playerExecutor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startPlayer" -> result.success(startPlayer())
            "writeChunk" -> {
                val data = call.argument<ByteArray>("data")
                val audioTrack = track
                if (data != null && audioTrack != null) {
                    playerExecutor.execute {
                        try {
                            audioTrack.write(data, 0, data.size)
                        } catch (e: IllegalStateException) {
                            Log.w(TAG, "AudioTrack.write: ${e.message}")
                        }
                    }
                }
                result.success(null)
            }
            "stopPlayer" -> {
                stopPlayer()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startPlayer(): Boolean {
        if (track != null) return true
        val minBuffer = AudioTrack.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuffer <= 0) return false
        // Normal (not in-call) audio mode, so the media stream uses the speaker.
        (context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager)?.mode =
            AudioManager.MODE_NORMAL
        return try {
            val audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(SAMPLE_RATE)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(minBuffer)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
            audioTrack.play()
            track = audioTrack
            true
        } catch (e: Exception) {
            Log.w(TAG, "AudioTrack start failed: ${e.message}")
            false
        }
    }

    private fun stopPlayer() {
        val audioTrack = track ?: return
        track = null
        // Release after queued writes have finished (same executor).
        playerExecutor.execute {
            try {
                audioTrack.pause()
                audioTrack.flush()
                audioTrack.stop()
            } catch (e: IllegalStateException) {
                Log.w(TAG, "AudioTrack.stop: ${e.message}")
            }
            audioTrack.release()
        }
    }
}
