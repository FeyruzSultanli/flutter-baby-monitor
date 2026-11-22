package com.example.bebek_monitor_clean

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Raw PCM audio for offline (Nearby) mode: 16 kHz, mono, 16-bit little-endian.
 *
 * - Microphone: listening on the event channel starts an [AudioRecord] and
 *   streams PCM chunks as byte arrays; cancelling the stream stops it.
 * - Speaker: "startPlayer" / "writeChunk" / "stopPlayer" on the method
 *   channel play received chunks through an [AudioTrack] (media stream, so
 *   it plays on the loudspeaker without switching the call audio mode).
 *
 * Replaces the GPL-3.0 sound_stream plugin with the same audio format.
 */
class OfflineAudio(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "OfflineAudio"
        const val METHOD_CHANNEL = "bebek_monitor/offline_audio"
        const val MIC_CHANNEL = "bebek_monitor/offline_audio/mic"
        const val SAMPLE_RATE = 16000
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val micChannel = EventChannel(messenger, MIC_CHANNEL)

    // Microphone
    @Volatile private var recording = false
    private var recorder: AudioRecord? = null
    private var recordThread: Thread? = null

    // Speaker. Writes block until the track has room, so they run on their
    // own thread instead of the platform (UI) thread.
    private var track: AudioTrack? = null
    private val playerExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    init {
        methodChannel.setMethodCallHandler(this)
        micChannel.setStreamHandler(this)
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        micChannel.setStreamHandler(null)
        stopRecording()
        stopPlayer()
        playerExecutor.shutdown()
    }

    // ---- Microphone ---------------------------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            events.error("PERMISSION_DENIED", "RECORD_AUDIO not granted", null)
            return
        }
        stopRecording()

        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuffer <= 0) {
            events.error("UNSUPPORTED", "Audio format not supported ($minBuffer)", null)
            return
        }
        // Chunk = minBuffer samples (2 * minBuffer bytes), the same chunk size
        // the previous plugin delivered, so payload rate and dB windows match.
        val chunkBytes = minBuffer * 2
        val audioRecord = try {
            AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                chunkBytes * 2
            )
        } catch (e: Exception) {
            events.error("INIT_FAILED", e.message, null)
            return
        }
        if (audioRecord.state != AudioRecord.STATE_INITIALIZED) {
            audioRecord.release()
            events.error("INIT_FAILED", "AudioRecord not initialized", null)
            return
        }
        try {
            audioRecord.startRecording()
        } catch (e: Exception) {
            audioRecord.release()
            events.error("START_FAILED", e.message, null)
            return
        }

        recorder = audioRecord
        recording = true
        Log.i(TAG, "microphone started (chunk $chunkBytes bytes)")
        recordThread = Thread({
            val buffer = ByteArray(chunkBytes)
            var first = true
            while (recording) {
                val read = audioRecord.read(buffer, 0, buffer.size)
                if (first) {
                    Log.i(TAG, "first microphone read: $read")
                    first = false
                }
                if (read > 0) {
                    val chunk = buffer.copyOf(read)
                    mainHandler.post { if (recording) events.success(chunk) }
                } else if (read < 0) {
                    Log.w(TAG, "AudioRecord.read failed: $read")
                    mainHandler.post {
                        if (recording) events.error("READ_FAILED", "AudioRecord.read: $read", null)
                    }
                    break
                }
            }
        }, "OfflineAudioMic").also { it.start() }
    }

    override fun onCancel(arguments: Any?) {
        stopRecording()
    }

    private fun stopRecording() {
        recording = false
        val audioRecord = recorder ?: return
        recorder = null
        try {
            audioRecord.stop()
        } catch (e: IllegalStateException) {
            Log.w(TAG, "AudioRecord.stop: ${e.message}")
        }
        // stop() makes a blocked read() return, so the thread ends quickly.
        recordThread?.join(500)
        recordThread = null
        audioRecord.release()
    }

    // ---- Speaker ------------------------------------------------------------

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
