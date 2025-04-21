package com.it7.flutter_audio_recorder_player

import android.content.Context
import android.content.Intent
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.audiofx.Visualizer
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.source.MediaSourceFactory
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.BufferUnderflowException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class AudioPlayer(private val context: Context) {
    private var exoPlayer: ExoPlayer? = null
    private var visualizer: Visualizer? = null
    private var visualizerDataCallback: ((ByteArray, ByteArray) -> Unit)? = null
    private var pcmDataCallback: ((ByteArray) -> Unit)? = null
    private var playbackStateListener:
            ((String, String?, String?, Long, Long, String?, String?) -> Unit)? =
            null
    // No longer need scheduler as we're using Visualizer's direct callbacks
    private val mainHandler = Handler(Looper.getMainLooper())

    // Metadata manager
    private val metadataManager = RecordingMetadata(context)

    // Visualization rate limiting
    private var lastWaveformTime = 0L
    private var lastFftTime = 0L
    private var lastPcmTime = 0L

    // Recording variables
    private var isRecording = false
    private var recordingFile: FileOutputStream? = null
    private var recordingTempFile: File? = null
    private var recordingStartTime = 0L
    private var recordingSampleRate = SAMPLE_RATE
    private var recordingChannels = CHANNELS
    private var recordingBitDepth = DEFAULT_BIT_DEPTH
    private var recordingTitle: String? = null

    // MediaCodec related variables
    private var mediaExtractor: MediaExtractor? = null
    private var mediaCodec: MediaCodec? = null
    private var decoderThread: Thread? = null
    private val isDecoding = AtomicBoolean(false)

    // PCM buffer management
    private val pcmInputBuffer = CircularBuffer(PCM_BUFFER_SIZE * 4) // Input buffer (from decoder)
    private val pcmOutputBuffer =
            CircularBuffer(PCM_BUFFER_SIZE * 2) // Output buffer (to visualization)
    private val tempBuffer = ByteArray(PCM_BUFFER_SIZE) // Temporary buffer for processing

    // Thread pool for audio processing
    private val audioProcessingExecutor: ThreadPoolExecutor by lazy {
        ThreadPoolExecutor(
                        1, // Core pool size
                        2, // Max pool size
                        60L, // Keep alive time
                        TimeUnit.SECONDS,
                        LinkedBlockingQueue<Runnable>(100), // Queue with larger capacity
                        ThreadPoolExecutor
                                .CallerRunsPolicy() // Use caller runs policy instead of rejecting
                        // tasks
                        )
                .apply {
                    // Allow core threads to time out
                    allowCoreThreadTimeOut(true)
                }
    }

    // Buffer for PCM data
    private val pcmDataQueue = LinkedBlockingQueue<ByteArray>(20) // Buffer up to 20 chunks
    private var processingThread: Thread? = null
    private val isProcessing = AtomicBoolean(false)

    companion object {
        private const val TAG = "AudioPlayer"
        private const val CAPTURE_SIZE = 1024
        private const val SAMPLING_INTERVAL_MS = 100L // Increased for smoother visualization
        private const val VISUALIZATION_RATE_MS =
                100L // Rate at which visualization data is sent (100ms = 10 updates per second)
        private const val PCM_BUFFER_SIZE = 8192 // 8KB buffer (smaller for more frequent updates)
        private const val TIMEOUT_US = 10000L // 10ms timeout
        private const val PROCESSING_INTERVAL_MS = 20L // 20ms for processing interval
        private const val CACHE_SIZE = 100 * 1024 * 1024 // 100MB cache size
        private var simpleCache: SimpleCache? = null

        // Audio playback constants
        private const val SAMPLE_RATE = 44100 // Standard audio sample rate
        private const val CHANNELS = 2 // Stereo audio

        // Default bit depth is 16-bit (2 bytes per sample)
        private const val DEFAULT_BIT_DEPTH = 16

        // Calculate bytes per sample based on bit depth
        fun getBytesPerSample(bitDepth: Int): Int {
            return when (bitDepth) {
                8 -> 1
                16 -> 2
                24 -> 3
                32 -> 4
                else -> bitDepth / 8
            }
        }

        // Default bytes per sample
        private const val BYTES_PER_SAMPLE = 2 // 16-bit audio = 2 bytes per sample

        // Calculate how many bytes to process per visualization update to match natural playback
        // For 100ms at 44.1kHz stereo 16-bit: 44100 * 2 * 2 * 0.1 = 17640 bytes
        private const val NATURAL_CHUNK_SIZE =
                (SAMPLE_RATE * BYTES_PER_SAMPLE * CHANNELS * (VISUALIZATION_RATE_MS / 1000.0))
                        .toInt()

        init {
            // Log the natural chunk size for debugging
            Log.d(
                    TAG,
                    "Natural chunk size for visualization: $NATURAL_CHUNK_SIZE bytes per ${VISUALIZATION_RATE_MS}ms"
            )
            Log.d(
                    TAG,
                    "This corresponds to ${NATURAL_CHUNK_SIZE / (BYTES_PER_SAMPLE * CHANNELS)} samples per update"
            )
        }
    }

    fun startPlayback(url: String, result: MethodChannel.Result) {
        try {
            // Release any existing player
            releaseResources()

            // Enable PCM decoding for recording
            Log.d(TAG, "Starting playback with PCM decoding for recording")

            // Flag to track if we've already responded to the method call
            var resultSent = false

            // Create a new ExoPlayer instance
            exoPlayer =
                    ExoPlayer.Builder(context)
                            .setMediaSourceFactory(createCachingMediaSourceFactory(context))
                            .build()
                            .apply {
                                // Configure audio attributes
                                val audioAttributes =
                                        AudioAttributes.Builder()
                                                .setUsage(C.USAGE_MEDIA)
                                                .setContentType(C.CONTENT_TYPE_MUSIC)
                                                .build()
                                setAudioAttributes(audioAttributes, true)

                                // Prepare the media source
                                val mediaItem = MediaItem.fromUri(Uri.parse(url))
                                setMediaItem(mediaItem)
                                prepare()

                                // Start playback
                                play()

                                // Add a listener to handle player state changes
                                addListener(
                                        object : Player.Listener {
                                            override fun onPlaybackStateChanged(state: Int) {
                                                when (state) {
                                                    Player.STATE_READY -> {
                                                        // Initialize visualizer when player is
                                                        // ready
                                                        initVisualizer()

                                                        // Start PCM decoding for recording on a
                                                        // background
                                                        // thread
                                                        Thread {
                                                                    try {
                                                                        startPcmDecoding(url)
                                                                    } catch (e: Exception) {
                                                                        Log.e(
                                                                                TAG,
                                                                                "Error starting PCM decoding: ${e.message}"
                                                                        )
                                                                    }
                                                                }
                                                                .start()

                                                        // Only send success once
                                                        mainHandler.post {
                                                            if (!resultSent) {
                                                                resultSent = true
                                                                result.success(true)

                                                                // Notify playback state listener
                                                                playbackStateListener?.invoke(
                                                                        PlaybackStateReceiver
                                                                                .STATE_PLAYING,
                                                                        "Now Playing",
                                                                        url,
                                                                        0,
                                                                        exoPlayer?.duration ?: 0,
                                                                        null, // artist
                                                                        null // album
                                                                )
                                                            }
                                                        }
                                                    }
                                                    Player.STATE_ENDED -> {
                                                        // Handle playback completion
                                                    }
                                                    Player.STATE_BUFFERING -> {
                                                        // Handle buffering state
                                                    }
                                                    Player.STATE_IDLE -> {
                                                        // Handle idle state
                                                    }
                                                }
                                            }

                                            override fun onPlayerError(
                                                    error: androidx.media3.common.PlaybackException
                                            ) {
                                                // Log the error details for debugging
                                                Log.e(TAG, "Player error: ${error.message}")
                                                Log.e(TAG, "Error cause: ${error.cause?.message}")
                                                Log.e(TAG, "Error code: ${error.errorCode}")

                                                // Handle network-related errors
                                                val errorMessage =
                                                        when {
                                                            error.message?.contains(
                                                                    "Unable to connect"
                                                            ) == true -> {
                                                                "Network connection error. Please check your internet connection."
                                                            }
                                                            error.message?.contains("timeout") ==
                                                                    true -> {
                                                                "Connection timed out. Please try again later."
                                                            }
                                                            error.message?.contains("403") ==
                                                                    true -> {
                                                                "Access denied. You may not have permission to access this content."
                                                            }
                                                            error.message?.contains("404") ==
                                                                    true -> {
                                                                "Content not found. The requested audio may have been moved or removed."
                                                            }
                                                            else -> error.message
                                                                            ?: "Unknown playback error"
                                                        }

                                                // Try to recover from network errors by retrying
                                                if (error.message?.contains("Unable to connect") ==
                                                                true ||
                                                                error.message?.contains(
                                                                        "timeout"
                                                                ) == true
                                                ) {
                                                    Log.d(
                                                            TAG,
                                                            "Attempting to recover from network error..."
                                                    )
                                                    // Retry playback after a short delay
                                                    mainHandler.postDelayed(
                                                            {
                                                                try {
                                                                    // Only retry if we're still in
                                                                    // the error state
                                                                    if (exoPlayer?.playbackState ==
                                                                                    Player.STATE_IDLE
                                                                    ) {
                                                                        Log.d(
                                                                                TAG,
                                                                                "Retrying playback..."
                                                                        )
                                                                        exoPlayer?.prepare()
                                                                        exoPlayer?.play()
                                                                    }
                                                                } catch (e: Exception) {
                                                                    Log.e(
                                                                            TAG,
                                                                            "Error during retry: ${e.message}"
                                                                    )
                                                                }
                                                            },
                                                            3000
                                                    ) // 3 second delay before retry
                                                }

                                                mainHandler.post {
                                                    if (!resultSent) {
                                                        resultSent = true
                                                        result.error(
                                                                "PLAYBACK_ERROR",
                                                                errorMessage,
                                                                null
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                )
                            }

            // If we haven't sent a result after a timeout, send success to avoid hanging the
            // Flutter side
            mainHandler.postDelayed(
                    {
                        if (!resultSent) {
                            resultSent = true
                            result.success(true)
                        }
                    },
                    5000
            ) // 5 second timeout
        } catch (e: Exception) {
            result.error("INIT_ERROR", "Error initializing player: ${e.message}", null)
        }
    }

    private fun initVisualizer() {
        try {
            exoPlayer?.let { player ->
                // Get the audio session ID from ExoPlayer
                val audioSessionId = player.audioSessionId

                try {
                    // Initialize the Visualizer
                    visualizer =
                            Visualizer(audioSessionId).apply {
                                captureSize = CAPTURE_SIZE
                                setDataCaptureListener(
                                        object : Visualizer.OnDataCaptureListener {
                                            override fun onWaveFormDataCapture(
                                                    visualizer: Visualizer,
                                                    waveform: ByteArray,
                                                    samplingRate: Int
                                            ) {
                                                val currentTime = System.currentTimeMillis()

                                                // Ensure natural playback speed by enforcing timing
                                                val timeSinceLastUpdate =
                                                        currentTime - lastWaveformTime

                                                // Only process if enough time has passed
                                                if (timeSinceLastUpdate >= VISUALIZATION_RATE_MS) {
                                                    // Update the last waveform time
                                                    lastWaveformTime = currentTime

                                                    // Process the waveform data for natural
                                                    // visualization
                                                    // 1. Apply moving average to smooth the data
                                                    val smoothedWaveform =
                                                            applyMovingAverage(
                                                                    waveform,
                                                                    3
                                                            ) // Window size of 3

                                                    // 2. Apply logarithmic scaling to match human
                                                    // perception
                                                    val scaledWaveform =
                                                            applyLogarithmicScaling(
                                                                    smoothedWaveform
                                                            )

                                                    // 3. Downsample the data to reduce main thread
                                                    // load
                                                    val downsampledWaveform =
                                                            downsamplePcmData(
                                                                    scaledWaveform,
                                                                    2
                                                            ) // Downsample by factor of 2

                                                    // Use a separate thread for posting to the main
                                                    // thread
                                                    audioProcessingExecutor.execute {
                                                        mainHandler.post {
                                                            visualizerDataCallback?.invoke(
                                                                    downsampledWaveform,
                                                                    ByteArray(0)
                                                            )
                                                        }
                                                    }
                                                }
                                            }

                                            override fun onFftDataCapture(
                                                    visualizer: Visualizer,
                                                    fft: ByteArray,
                                                    samplingRate: Int
                                            ) {
                                                val currentTime = System.currentTimeMillis()

                                                // Ensure natural playback speed by enforcing timing
                                                val timeSinceLastUpdate = currentTime - lastFftTime

                                                // Only process if enough time has passed
                                                if (timeSinceLastUpdate >= VISUALIZATION_RATE_MS) {
                                                    // Update the last FFT time
                                                    lastFftTime = currentTime

                                                    // Process the FFT data for natural
                                                    // visualization
                                                    // 1. Apply Hann window to reduce spectral
                                                    // leakage
                                                    val windowedFft = applyHannWindow(fft)

                                                    // 2. Average frequency bands for smoother
                                                    // visualization
                                                    val bandAveragedFft =
                                                            averageFrequencyBands(
                                                                    windowedFft,
                                                                    32
                                                            ) // 32 frequency bands

                                                    // 3. Apply logarithmic scaling to match human
                                                    // perception
                                                    val scaledFft =
                                                            applyLogarithmicScaling(bandAveragedFft)

                                                    // Use a separate thread for posting to the main
                                                    // thread
                                                    audioProcessingExecutor.execute {
                                                        mainHandler.post {
                                                            visualizerDataCallback?.invoke(
                                                                    ByteArray(0),
                                                                    scaledFft
                                                            )
                                                        }
                                                    }
                                                }
                                            }
                                        },
                                        Visualizer.getMaxCaptureRate(),
                                        true,
                                        true
                                ) // Enable both waveform and FFT capture

                                // Enable the visualizer
                                enabled = true
                            }
                } catch (e: Exception) {
                    Log.w(TAG, "Visualizer initialization failed: ${e.message}")
                    // Continue without visualizer - we'll still have PCM data
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in initVisualizer: ${e.message}")
        }
    }

    // We no longer need this method as we're capturing FFT data directly from the Visualizer

    fun stopPlayback() {
        try {
            Log.d(TAG, "Stopping playback - beginning process")

            // First, stop PCM decoding and processing to prevent further data processing
            stopPcmDecoding()
            stopPcmProcessing()
            Log.d(TAG, "PCM decoding and processing stopped")

            // Then stop the ExoPlayer
            try {
                exoPlayer?.stop()
                Log.d(TAG, "ExoPlayer stopped")

                // Notify playback state listener
                playbackStateListener?.invoke(
                        PlaybackStateReceiver.STATE_STOPPED,
                        "Stopped",
                        null,
                        0,
                        0,
                        null, // artist
                        null // album
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping ExoPlayer: ${e.message}")
            }

            // Disable the visualizer to prevent callbacks
            try {
                visualizer?.enabled = false
                Log.d(TAG, "Visualizer disabled")
            } catch (e: Exception) {
                Log.e(TAG, "Error disabling visualizer: ${e.message}")
            }

            // Reset timestamps to prevent stale data
            lastWaveformTime = 0L
            lastFftTime = 0L
            lastPcmTime = 0L

            // Clear the executor queue
            try {
                if (audioProcessingExecutor.queue is LinkedBlockingQueue<*>) {
                    (audioProcessingExecutor.queue as LinkedBlockingQueue<*>).clear()
                    Log.d(TAG, "Audio processing queue cleared")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error clearing audio processing queue: ${e.message}")
            }

            // Log the stop
            Log.d(TAG, "Playback stopped and all processing terminated successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error in stopPlayback: ${e.message}")
            e.printStackTrace()
        }
    }

    fun setVisualizerDataCallback(callback: (ByteArray, ByteArray) -> Unit) {
        visualizerDataCallback = callback
    }

    fun releaseResources() {
        Log.d(TAG, "Releasing resources")

        // Release the visualizer
        visualizer?.release()
        visualizer = null

        // Release the player
        exoPlayer?.release()
        exoPlayer = null

        // Stop PCM decoding and processing
        stopPcmDecoding()
        stopPcmProcessing()

        // Don't shut down the executor, just clear the queue
        try {
            if (audioProcessingExecutor.queue is LinkedBlockingQueue<*>) {
                (audioProcessingExecutor.queue as LinkedBlockingQueue<*>).clear()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing audio processing queue: ${e.message}")
        }
    }

    /** Creates a MediaSourceFactory with caching support */
    private fun createCachingMediaSourceFactory(context: Context): MediaSourceFactory {
        // Create a cache if it doesn't exist yet
        if (simpleCache == null) {
            val cacheDir = File(context.cacheDir, "media")
            if (!cacheDir.exists()) {
                cacheDir.mkdirs()
            }

            val evictor = LeastRecentlyUsedCacheEvictor(CACHE_SIZE.toLong())
            val databaseProvider = StandaloneDatabaseProvider(context)
            simpleCache = SimpleCache(cacheDir, evictor, databaseProvider)

            Log.d(TAG, "Created media cache in ${cacheDir.absolutePath}")
        }

        // Create the default media source factory with caching
        // This will automatically use the appropriate data source factory based on the URI scheme
        // (DefaultDataSource handles both http:// and file:// URIs)
        val cacheDataSourceFactory =
                androidx.media3.datasource.cache.CacheDataSource.Factory()
                        .setCache(simpleCache!!)
                        .setUpstreamDataSourceFactory(
                                androidx.media3.datasource.DefaultDataSource.Factory(context)
                        )
                        .setCacheWriteDataSinkFactory(
                                null
                        ) // Disable writing to cache for now (optional)
                        .setFlags(
                                androidx.media3.datasource.cache.CacheDataSource
                                        .FLAG_IGNORE_CACHE_ON_ERROR
                        )

        return DefaultMediaSourceFactory(cacheDataSourceFactory)
    }

    /** Sets a callback to receive PCM audio data. */
    fun setPcmDataCallback(callback: (ByteArray) -> Unit) {
        pcmDataCallback = callback
    }

    /** Starts decoding the audio stream to PCM data using MediaCodec. */
    private fun startPcmDecoding(url: String) {
        Log.d(TAG, "Starting PCM decoding for URL: $url")
        try {
            // Stop any existing decoding
            stopPcmDecoding()

            // Clear the PCM buffers
            pcmInputBuffer.clear()
            pcmOutputBuffer.clear()
            Log.d(TAG, "PCM buffers cleared")

            // Make sure recording file is closed
            recordingFile?.close()
            recordingFile = null
            recordingTempFile = null

            // Set up MediaExtractor
            try {
                mediaExtractor =
                        MediaExtractor().apply {
                            // Handle file:// URLs properly
                            if (url.startsWith("file://")) {
                                val path = url.substring(7) // Remove "file://" prefix
                                Log.d(TAG, "Using file path for MediaExtractor: $path")
                                setDataSource(path)
                            } else {
                                Log.d(TAG, "Using URL for MediaExtractor: $url")
                                setDataSource(url)
                            }
                        }

                // Find the audio track
                val audioTrackIndex = findAudioTrack(mediaExtractor!!)
                if (audioTrackIndex < 0) {
                    Log.e(TAG, "No audio track found in the stream")
                    return
                }

                // Select the audio track
                mediaExtractor?.selectTrack(audioTrackIndex)

                // Get the audio format
                val format = mediaExtractor?.getTrackFormat(audioTrackIndex)
                val mime = format?.getString(MediaFormat.KEY_MIME)

                if (mime == null) {
                    Log.e(TAG, "Audio MIME type is null")
                    return
                }

                try {
                    // Create and configure the decoder
                    mediaCodec =
                            MediaCodec.createDecoderByType(mime).apply {
                                configure(format, null, null, 0)
                                start()
                            }

                    // Start the decoding thread
                    isDecoding.set(true)
                    decoderThread = Thread(::decodingLoop)
                    decoderThread?.start()
                } catch (codecEx: Exception) {
                    Log.e(TAG, "Error creating or configuring MediaCodec: ${codecEx.message}")
                    mediaCodec?.release()
                    mediaCodec = null
                }
            } catch (extractorEx: Exception) {
                Log.e(TAG, "Error with MediaExtractor: ${extractorEx.message}")
                mediaExtractor?.release()
                mediaExtractor = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting PCM decoding: ${e.message}")
            stopPcmDecoding()
        }
    }

    /** Stops the PCM decoding process and releases resources. */
    private fun stopPcmDecoding() {
        Log.d(TAG, "Stopping PCM decoding")

        // Signal the decoding thread to stop
        isDecoding.set(false)

        // Wait for the thread to finish
        try {
            val thread = decoderThread
            if (thread != null && thread.isAlive) {
                // Interrupt the thread first
                thread.interrupt()

                // Wait for thread to finish, with timeout
                thread.join(1000)

                if (thread.isAlive) {
                    Log.w(TAG, "Decoder thread did not terminate within timeout")
                    // Force interrupt again
                    try {
                        thread.interrupt()
                    } catch (e: Exception) {
                        Log.e(TAG, "Error interrupting decoder thread: ${e.message}")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error waiting for decoder thread to finish: ${e.message}")
        } finally {
            decoderThread = null
        }

        // Release MediaCodec resources - do this in a synchronized block to prevent race conditions
        synchronized(this) {
            try {
                val codec = mediaCodec
                if (codec != null) {
                    try {
                        codec.stop()
                    } catch (e: Exception) {
                        Log.e(TAG, "Error stopping MediaCodec: ${e.message}")
                    }

                    try {
                        codec.release()
                    } catch (e: Exception) {
                        Log.e(TAG, "Error releasing MediaCodec: ${e.message}")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error handling MediaCodec: ${e.message}")
            } finally {
                mediaCodec = null
            }

            // Release MediaExtractor resources
            try {
                val extractor = mediaExtractor
                if (extractor != null) {
                    extractor.release()
                } else {
                    // No extractor to release
                    Log.d(TAG, "No MediaExtractor to release")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error releasing MediaExtractor: ${e.message}")
            } finally {
                mediaExtractor = null
            }
        }

        // Log the stop
        Log.d(TAG, "PCM decoding stopped and resources released")
    }

    /** Finds the index of the first audio track in the media. */
    private fun findAudioTrack(extractor: MediaExtractor): Int {
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("audio/") == true) {
                return i
            }
        }
        return -1
    }

    /** Main decoding loop that runs on a background thread. */
    private fun decodingLoop() {
        try {
            // Use local variables to prevent NullPointerException if they're cleared during
            // execution
            val codec = mediaCodec
            if (codec == null) {
                Log.e(TAG, "MediaCodec is null in decodingLoop")
                return
            }

            val extractor = mediaExtractor
            if (extractor == null) {
                Log.e(TAG, "MediaExtractor is null in decodingLoop")
                return
            }

            val bufferInfo = MediaCodec.BufferInfo()
            val inputBuffers =
                    try {
                        codec.inputBuffers
                    } catch (e: IllegalStateException) {
                        Log.e(TAG, "Failed to get input buffers: ${e.message}")
                        return
                    }

            var outputBuffers =
                    try {
                        codec.outputBuffers
                    } catch (e: IllegalStateException) {
                        Log.e(TAG, "Failed to get output buffers: ${e.message}")
                        return
                    }

            var isEOS = false
            var frameCount = 0
            var totalBytesProcessed = 0

            while (isDecoding.get() && !Thread.interrupted()) {
                try {
                    // Check if we should continue processing
                    if (!isDecoding.get() || Thread.interrupted()) {
                        Log.d(TAG, "Decoding loop interrupted or stopped")
                        break
                    }

                    // Handle input
                    if (!isEOS) {
                        try {
                            val inputBufferIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                            if (inputBufferIndex >= 0) {
                                val inputBuffer = inputBuffers[inputBufferIndex]
                                val sampleSize = extractor.readSampleData(inputBuffer, 0)

                                if (sampleSize < 0) {
                                    // End of stream
                                    Log.d(TAG, "End of stream reached in decoder")
                                    codec.queueInputBuffer(
                                            inputBufferIndex,
                                            0,
                                            0,
                                            0,
                                            MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                    )
                                    isEOS = true
                                } else {
                                    codec.queueInputBuffer(
                                            inputBufferIndex,
                                            0,
                                            sampleSize,
                                            extractor.sampleTime,
                                            0
                                    )
                                    extractor.advance()
                                }
                            }
                        } catch (e: IllegalStateException) {
                            Log.e(TAG, "IllegalStateException in input processing: ${e.message}")
                            // MediaCodec might have been released, exit the loop
                            break
                        } catch (e: Exception) {
                            Log.e(TAG, "Error processing input buffer: ${e.message}")
                            e.printStackTrace()
                        }
                    }

                    // Check again if we should continue processing
                    if (!isDecoding.get() || Thread.interrupted()) {
                        Log.d(TAG, "Decoding loop interrupted or stopped after input processing")
                        break
                    }

                    // Handle output
                    try {
                        val outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
                        if (outputBufferIndex >= 0) {
                            try {
                                val outputBuffer = outputBuffers[outputBufferIndex]

                                // Process decoded PCM data
                                if (bufferInfo.size > 0) {
                                    outputBuffer.position(bufferInfo.offset)
                                    outputBuffer.limit(bufferInfo.offset + bufferInfo.size)

                                    // Log frame details occasionally
                                    frameCount++
                                    totalBytesProcessed += bufferInfo.size
                                    if (frameCount % 100 == 0) {
                                        Log.d(
                                                TAG,
                                                "Processed $frameCount frames, $totalBytesProcessed total bytes"
                                        )
                                    }

                                    // Process the PCM data
                                    processPcmData(outputBuffer, bufferInfo.size)
                                }

                                // Always clear the buffer and release it
                                outputBuffer.clear()
                                codec.releaseOutputBuffer(outputBufferIndex, false)

                                if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                                ) {
                                    Log.d(TAG, "End of stream flag received in output buffer")
                                    break
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "Error processing output buffer: ${e.message}")
                                e.printStackTrace()
                                // Continue with the next buffer
                            }
                        } else if (outputBufferIndex == MediaCodec.INFO_OUTPUT_BUFFERS_CHANGED) {
                            try {
                                Log.d(TAG, "Output buffers changed, getting new buffers")
                                outputBuffers = codec.outputBuffers
                            } catch (e: IllegalStateException) {
                                Log.e(TAG, "Failed to get updated output buffers: ${e.message}")
                                break
                            }
                        } else if (outputBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                            try {
                                val newFormat = codec.outputFormat
                                Log.d(TAG, "Output format changed to: $newFormat")
                            } catch (e: IllegalStateException) {
                                Log.e(TAG, "Failed to get output format: ${e.message}")
                                break
                            }
                        }
                    } catch (e: IllegalStateException) {
                        Log.e(TAG, "IllegalStateException in output processing: ${e.message}")
                        // MediaCodec might have been released, exit the loop
                        break
                    } catch (e: Exception) {
                        Log.e(
                                TAG,
                                "Error in decoding loop iteration: " +
                                        e.javaClass.simpleName +
                                        ": " +
                                        (e.message ?: "No message")
                        )
                        e.printStackTrace() // Print stack trace for debugging
                        // Sleep a bit to avoid tight loop in case of persistent errors
                        try {
                            Thread.sleep(100)
                        } catch (ie: InterruptedException) {
                            Log.d(TAG, "Decoding thread interrupted during sleep")
                            break
                        }
                    }
                } catch (e: InterruptedException) {
                    Log.d(TAG, "Decoding thread interrupted")
                    break
                } catch (e: Exception) {
                    Log.e(
                            TAG,
                            "Error in decoding loop iteration: " +
                                    e.javaClass.simpleName +
                                    ": " +
                                    (e.message ?: "No message")
                    )
                    e.printStackTrace() // Print stack trace for debugging
                    // Sleep a bit to avoid tight loop in case of persistent errors
                    try {
                        Thread.sleep(100)
                    } catch (ie: InterruptedException) {
                        Log.d(TAG, "Decoding thread interrupted during sleep")
                        break
                    }
                }
            }

            Log.d(
                    TAG,
                    "Decoding loop completed. Processed $frameCount frames, $totalBytesProcessed total bytes"
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error in decoding loop: ${e.message}")
            e.printStackTrace()
        } finally {
            // Make sure we clean up resources even if an exception occurs
            synchronized(this) {
                try {
                    val codec = mediaCodec
                    if (codec != null) {
                        try {
                            codec.stop()
                        } catch (e: Exception) {
                            Log.e(
                                    TAG,
                                    "Error stopping MediaCodec in decodingLoop finally: ${e.message}"
                            )
                        }
                    } else {
                        // No codec to stop
                        Log.d(TAG, "No MediaCodec to stop in decodingLoop finally")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in decodingLoop finally block: ${e.message}")
                }
            }
        }
    }

    /** Processes the decoded PCM data. */
    private fun processPcmData(buffer: ByteBuffer, size: Int) {
        try {
            // Log buffer details for debugging
            Log.d(
                    TAG,
                    "Processing PCM data: size=$size, buffer position=${buffer.position()}, limit=${buffer.limit()}, remaining=${buffer.remaining()}"
            )

            // Save the original buffer position and limit
            val originalPosition = buffer.position()
            val originalLimit = buffer.limit()

            // If recording is active, write to the recording file first
            if (isRecording && size > 0) {
                val file = recordingFile
                if (file != null) {
                    try {
                        // Create a temporary buffer to hold the data
                        val tempData = ByteArray(size)

                        // Reset buffer position to read from the beginning
                        buffer.position(originalPosition)

                        // Make sure we don't try to read more than what's available
                        val bytesToRead = Math.min(size, buffer.remaining())
                        Log.d(
                                TAG,
                                "Recording: bytesToRead=$bytesToRead, buffer remaining=${buffer.remaining()}"
                        )

                        if (bytesToRead > 0) {
                            try {
                                // Read the data into the temp buffer
                                buffer.get(tempData, 0, bytesToRead)

                                // Get the source format (what's actually coming from the player)
                                val sourceBitDepth =
                                        DEFAULT_BIT_DEPTH // Usually 16-bit from ExoPlayer
                                val sourceSampleRate = SAMPLE_RATE // Usually 44.1kHz from ExoPlayer
                                val sourceChannels = CHANNELS // Usually 2 channels from ExoPlayer
                                val sourceBytesPerSample =
                                        AudioPlayer.getBytesPerSample(sourceBitDepth)

                                // Get the target format (what the user selected)
                                val targetBitDepth = recordingBitDepth
                                val targetSampleRate = recordingSampleRate
                                val targetChannels = recordingChannels
                                val targetBytesPerSample =
                                        AudioPlayer.getBytesPerSample(targetBitDepth)

                                Log.d(
                                        TAG,
                                        "Recording conversion: source=${sourceSampleRate}Hz, ${sourceChannels}ch, ${sourceBitDepth}-bit -> " +
                                                "target=${targetSampleRate}Hz, ${targetChannels}ch, ${targetBitDepth}-bit"
                                )

                                // Check if we need to convert the audio format
                                if (sourceSampleRate == targetSampleRate &&
                                                sourceChannels == targetChannels &&
                                                sourceBitDepth == targetBitDepth
                                ) {
                                    // No conversion needed, write directly
                                    file.write(tempData, 0, bytesToRead)
                                    Log.d(TAG, "Direct write: ${bytesToRead} bytes")
                                } else {
                                    // Convert the audio data
                                    val convertedData =
                                            convertAudioFormat(
                                                    tempData,
                                                    bytesToRead,
                                                    sourceSampleRate,
                                                    sourceChannels,
                                                    sourceBitDepth,
                                                    targetSampleRate,
                                                    targetChannels,
                                                    targetBitDepth
                                            )

                                    // Write the converted data
                                    file.write(convertedData, 0, convertedData.size)
                                    Log.d(
                                            TAG,
                                            "Converted write: ${bytesToRead} bytes -> ${convertedData.size} bytes"
                                    )
                                }
                                file.flush() // Ensure data is written to disk

                                // Log to verify data is being written
                                Log.d(TAG, "Wrote " + bytesToRead + " bytes to recording file")
                            } catch (e: BufferUnderflowException) {
                                Log.e(
                                        TAG,
                                        "BufferUnderflowException: Buffer has " +
                                                buffer.remaining() +
                                                " bytes, tried to read " +
                                                bytesToRead
                                )
                                e.printStackTrace()
                            }
                        } else {
                            Log.w(TAG, "No bytes available to read from buffer")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error writing to recording file: ${e.message}")
                        e.printStackTrace()
                    }
                } else {
                    Log.e(TAG, "Recording file is null but isRecording is true")
                    // Reset recording state since the file is null
                    isRecording = false
                }
            }

            // Reset buffer position for circular buffer write
            buffer.position(originalPosition)
            buffer.limit(originalLimit)

            // Write to the input circular buffer
            val bytesWritten = pcmInputBuffer.write(buffer, size)
            Log.d(TAG, "Wrote $bytesWritten bytes to PCM input buffer")

            if (bytesWritten > 0) {
                // If we wrote data, make sure the processing thread is running
                startPcmProcessing()

                // Log the data flow
                if (bytesWritten < size) {
                    Log.w(TAG, "Buffer overflow: Only wrote $bytesWritten of $size bytes")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing PCM data: ${e.message}")
        }
    }

    /**
     * This method is no longer needed with the circular buffer approach. Kept as a no-op for
     * compatibility.
     */
    private fun queuePcmData() {
        // No-op - we now use circular buffers instead of queuing
    }

    /** Starts the PCM processing thread if it's not already running. */
    private fun startPcmProcessing() {
        if (isProcessing.compareAndSet(false, true)) {
            try {
                processingThread =
                        Thread {
                            try {
                                while (isProcessing.get() && !Thread.interrupted()) {
                                    try {
                                        // Check if we have data to process
                                        if (!pcmInputBuffer.isEmpty()) {
                                            // Read from input buffer into temp buffer
                                            // Use the natural chunk size to match audio playback
                                            // rate
                                            val bytesToRead =
                                                    Math.min(NATURAL_CHUNK_SIZE, tempBuffer.size)
                                            val bytesRead =
                                                    pcmInputBuffer.read(tempBuffer, 0, bytesToRead)

                                            if (bytesRead > 0) {
                                                // Write to output buffer
                                                pcmOutputBuffer.write(tempBuffer, 0, bytesRead)

                                                // Ensure natural playback speed by enforcing timing
                                                val currentTime = System.currentTimeMillis()
                                                val timeSinceLastUpdate = currentTime - lastPcmTime

                                                // If we're processing too quickly, sleep to match
                                                // natural playback rate
                                                if (timeSinceLastUpdate < VISUALIZATION_RATE_MS) {
                                                    val sleepTime =
                                                            VISUALIZATION_RATE_MS -
                                                                    timeSinceLastUpdate
                                                    Thread.sleep(sleepTime)
                                                }

                                                // Update the last PCM time
                                                val newTime = System.currentTimeMillis()
                                                val actualInterval = newTime - lastPcmTime
                                                lastPcmTime = newTime

                                                // Log the actual processing rate occasionally
                                                // (every ~5 seconds)
                                                if (Math.random() < 0.02) { // ~2% chance to log
                                                    Log.d(
                                                            TAG,
                                                            "PCM processing: ${bytesRead} bytes processed in ${actualInterval}ms (target: ${VISUALIZATION_RATE_MS}ms)"
                                                    )
                                                }

                                                // Create a copy of the data to send to the callback
                                                val dataToSend = ByteArray(bytesRead)
                                                System.arraycopy(
                                                        tempBuffer,
                                                        0,
                                                        dataToSend,
                                                        0,
                                                        bytesRead
                                                )

                                                // Calculate RMS value here to reduce work on the
                                                // main thread
                                                val rms = calculateRmsValue(dataToSend)

                                                // Apply processing to create a more natural
                                                // visualization
                                                // 1. Apply moving average to smooth the data
                                                val smoothedData =
                                                        applyMovingAverage(
                                                                dataToSend,
                                                                5
                                                        ) // Window size of 5

                                                // 2. Apply logarithmic scaling to match human
                                                // perception
                                                val scaledData =
                                                        applyLogarithmicScaling(smoothedData)

                                                // 3. Downsample the data to reduce the amount of
                                                // data sent to the main thread
                                                val downsampledData =
                                                        downsamplePcmData(
                                                                scaledData,
                                                                4
                                                        ) // Downsample by factor of 4

                                                // Use the executor to post to the main thread
                                                // This prevents overloading the main thread
                                                audioProcessingExecutor.execute {
                                                    mainHandler.post {
                                                        try {
                                                            // Send the downsampled data with the
                                                            // RMS value
                                                            pcmDataCallback?.invoke(downsampledData)
                                                        } catch (e: Exception) {
                                                            Log.e(
                                                                    TAG,
                                                                    "Error in PCM callback: ${e.message}"
                                                            )
                                                        }
                                                    }
                                                }
                                            }
                                        } else {
                                            // No data available, sleep a bit
                                            Thread.sleep(PROCESSING_INTERVAL_MS)
                                        }
                                    } catch (e: InterruptedException) {
                                        // Thread was interrupted, exit the loop
                                        Thread.currentThread().interrupt()
                                        break
                                    } catch (e: Exception) {
                                        Log.e(TAG, "Error in PCM processing loop: ${e.message}")
                                        // Sleep a bit to avoid tight loop in case of persistent
                                        // errors
                                        Thread.sleep(PROCESSING_INTERVAL_MS)
                                    }
                                }
                            } finally {
                                isProcessing.set(false)
                            }
                        }
                                .apply {
                                    name = "PCM-Processing-Thread"
                                    isDaemon = true
                                    priority = Thread.MAX_PRIORITY - 1 // High priority but not max
                                    start()
                                }
            } catch (e: Exception) {
                Log.e(TAG, "Error starting PCM processing thread: ${e.message}")
                isProcessing.set(false)
            }
        }
    }

    /** Stops the PCM processing thread and clears all buffers. */
    private fun stopPcmProcessing() {
        Log.d(TAG, "Stopping PCM processing")

        // Stop the processing thread
        isProcessing.set(false)

        try {
            val thread = processingThread
            if (thread != null && thread.isAlive) {
                thread.interrupt()
                thread.join(1000) // Wait for thread to finish, with timeout
                if (thread.isAlive) {
                    Log.w(TAG, "Processing thread did not terminate within timeout")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error waiting for processing thread to finish: ${e.message}")
        } finally {
            processingThread = null
        }

        // Clear all buffers
        try {
            pcmInputBuffer.clear()
            pcmOutputBuffer.clear()
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing PCM buffers: ${e.message}")
        }

        // Log the stop
        Log.d(TAG, "PCM processing stopped and buffers cleared")
    }

    // This method is already defined below with proper documentation

    fun pausePlayback() {
        exoPlayer?.pause()

        // Notify playback state listener
        playbackStateListener?.invoke(
                PlaybackStateReceiver.STATE_PAUSED,
                "Paused",
                null,
                getCurrentPosition(),
                getDuration(),
                null, // artist
                null // album
        )
    }

    fun resumePlayback() {
        exoPlayer?.play()

        // Notify playback state listener
        playbackStateListener?.invoke(
                PlaybackStateReceiver.STATE_PLAYING,
                "Now Playing",
                null,
                getCurrentPosition(),
                getDuration(),
                null, // artist
                null // album
        )
    }

    fun getCurrentPosition(): Long {
        return exoPlayer?.currentPosition ?: 0
    }

    fun getDuration(): Long {
        return exoPlayer?.duration ?: 0
    }

    fun seekTo(position: Long) {
        exoPlayer?.seekTo(position)
    }

    fun setVolume(volume: Float) {
        exoPlayer?.volume = volume
    }

    /**
     * Sets the playback speed.
     *
     * @param speed The playback speed (0.5 to 2.0)
     */
    fun setSpeed(speed: Float) {
        try {
            // Clamp speed to valid range
            val clampedSpeed = speed.coerceIn(0.5f, 2.0f)

            // Set the playback speed on ExoPlayer
            exoPlayer?.setPlaybackSpeed(clampedSpeed)

            Log.d(TAG, "Playback speed set to $clampedSpeed")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting playback speed: ${e.message}")
        }
    }

    /**
     * Checks if the player is currently playing.
     *
     * @return true if playing, false otherwise
     */
    fun isPlaying(): Boolean {
        return exoPlayer?.isPlaying ?: false
    }

    /**
     * Skips to the next track in a playlist. This is a placeholder implementation that will be
     * called by the service. The actual implementation is handled on the Flutter side.
     *
     * @return true if successful, false otherwise
     */
    fun skipToNext(): Boolean {
        // This is just a placeholder. The actual implementation is in the Flutter code.
        // The Flutter side will listen for the broadcast and handle the skip action.
        try {
            val intent =
                    Intent(PlaybackStateReceiver.ACTION_PLAYBACK_STATE_CHANGED).apply {
                        putExtra(
                                PlaybackStateReceiver.EXTRA_STATE,
                                PlaybackStateReceiver.STATE_SKIP_NEXT
                        )
                    }
            context.sendBroadcast(intent)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error sending skip next broadcast: ${e.message}")
            return false
        }
    }

    /**
     * Skips to the previous track in a playlist. This is a placeholder implementation that will be
     * called by the service. The actual implementation is handled on the Flutter side.
     *
     * @return true if successful, false otherwise
     */
    fun skipToPrevious(): Boolean {
        // This is just a placeholder. The actual implementation is in the Flutter code.
        // The Flutter side will listen for the broadcast and handle the skip action.
        try {
            val intent =
                    Intent(PlaybackStateReceiver.ACTION_PLAYBACK_STATE_CHANGED).apply {
                        putExtra(
                                PlaybackStateReceiver.EXTRA_STATE,
                                PlaybackStateReceiver.STATE_SKIP_PREVIOUS
                        )
                    }
            context.sendBroadcast(intent)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error sending skip previous broadcast: ${e.message}")
            return false
        }
    }

    /**
     * Starts recording the audio that's currently playing
     *
     * @param sampleRate Optional sample rate for the recording (default is SAMPLE_RATE)
     * @param channels Optional number of channels for the recording (default is CHANNELS)
     * @param bitDepth Optional bit depth for the recording (default is BYTES_PER_SAMPLE * 8)
     * @return true if recording started successfully, false otherwise
     */
    fun startRecording(
            sampleRate: Int = SAMPLE_RATE,
            channels: Int = CHANNELS,
            bitDepth: Int = DEFAULT_BIT_DEPTH,
            title: String? = null
    ): Boolean {
        if (isRecording) {
            Log.w(TAG, "Recording is already in progress")
            return false
        }

        if (exoPlayer == null || !isPlaying()) {
            Log.e(TAG, "Cannot start recording: No audio is playing")
            return false
        }

        try {
            // Create a temporary file for recording
            val cacheDir = context.cacheDir
            if (!cacheDir.exists()) {
                val dirCreated = cacheDir.mkdirs()
                if (!dirCreated) {
                    Log.e(TAG, "Failed to create cache directory: ${cacheDir.absolutePath}")
                    return false
                }
            }

            Log.d(
                    TAG,
                    "Cache directory: ${cacheDir.absolutePath}, exists: ${cacheDir.exists()}, canWrite: ${cacheDir.canWrite()}"
            )

            recordingTempFile = File.createTempFile("recording_", ".pcm", cacheDir)
            Log.d(TAG, "Created temp file: ${recordingTempFile?.absolutePath}")

            recordingFile = FileOutputStream(recordingTempFile)
            Log.d(TAG, "Opened FileOutputStream for temp file")

            // Write a small header to ensure the file isn't empty
            // This is just a placeholder that will be overwritten by actual PCM data
            val initialData = ByteArray(4)
            initialData[0] = 0x52 // 'R'
            initialData[1] = 0x45 // 'E'
            initialData[2] = 0x43 // 'C'
            initialData[3] = 0x00 // null terminator
            recordingFile?.write(initialData)
            recordingFile?.flush()
            Log.d(TAG, "Wrote initial header to recording file")

            // Store recording parameters
            recordingStartTime = System.currentTimeMillis()
            recordingSampleRate = sampleRate
            recordingChannels = channels
            recordingBitDepth = bitDepth
            recordingTitle = title
            isRecording = true

            // Log the recording parameters
            val bytesPerSample = AudioPlayer.getBytesPerSample(bitDepth)
            Log.d(
                    TAG,
                    "Starting recording with sample rate: $sampleRate, channels: $channels, bit depth: $bitDepth ($bytesPerSample bytes per sample)"
            )

            Log.d(TAG, "Started recording audio to temp file: ${recordingTempFile?.absolutePath}")
            Log.d(
                    TAG,
                    "Recording parameters: sampleRate=$sampleRate, channels=$channels, bitDepth=$bitDepth"
            )
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error starting recording: ${e.message}")
            cleanupRecording()
            return false
        }
    }

    /**
     * Stops recording and saves the recorded audio as a WAV file
     *
     * @param filePath Path where the WAV file should be saved
     * @return true if the recording was saved successfully, false otherwise
     */
    fun stopRecording(filePath: String): Boolean {
        if (!isRecording) {
            Log.w(TAG, "No recording in progress")
            return false
        }

        // Store the recording parameters for metadata
        val recordingDuration = System.currentTimeMillis() - recordingStartTime

        try {
            // Store recording parameters for metadata

            // Stop recording
            isRecording = false

            // Add recording to metadata
            val recordingId =
                    metadataManager.addRecording(
                            filePath = filePath,
                            title = recordingTitle,
                            sampleRate = recordingSampleRate,
                            channels = recordingChannels,
                            bitDepth = recordingBitDepth,
                            duration = recordingDuration
                    )

            Log.d(TAG, "Added recording to metadata with ID: $recordingId")

            try {
                recordingFile?.flush()
                recordingFile?.close()
            } catch (e: Exception) {
                Log.e(TAG, "Error closing recording file: ${e.message}")
            }
            recordingFile = null

            // Check if we have a temp file
            val tempFile = recordingTempFile
            if (tempFile == null) {
                Log.e(TAG, "Temp file is null")
                cleanupRecording()
                return false
            }

            if (!tempFile.exists()) {
                Log.e(TAG, "Temp file does not exist: ${tempFile.absolutePath}")
                cleanupRecording()
                return false
            }

            if (tempFile.length() == 0L) {
                Log.e(TAG, "Temp file is empty: ${tempFile.absolutePath}")
                cleanupRecording()
                return false
            }

            // Log recording statistics
            val recordingDuration = System.currentTimeMillis() - recordingStartTime
            val fileSize = tempFile.length()
            Log.d(TAG, "Stopped recording: $fileSize bytes recorded over ${recordingDuration}ms")

            // Ensure the output directory exists
            val outputFile = File(filePath)
            outputFile.parentFile?.mkdirs()

            // Check if we can write to the output file
            if (outputFile.exists() && !outputFile.canWrite()) {
                Log.e(TAG, "Cannot write to output file: $filePath")
                cleanupRecording()
                return false
            }

            // Convert PCM to WAV
            val success =
                    WavRecorder.convertPcmToWav(
                            tempFile.absolutePath,
                            filePath,
                            recordingSampleRate,
                            recordingChannels,
                            recordingBitDepth
                    )

            if (!success) {
                Log.e(TAG, "Failed to convert PCM to WAV")
            } else {
                Log.d(TAG, "Successfully saved recording to: $filePath")
            }

            // Clean up the temp file
            cleanupRecording()

            return success
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recording: ${e.message}")
            e.printStackTrace()
            cleanupRecording()
            return false
        }
    }

    /**
     * Cancels the current recording without saving
     *
     * @return true if recording was successfully canceled, false if no recording was in progress
     */
    fun cancelRecording(): Boolean {
        if (!isRecording) {
            return false
        }

        try {
            isRecording = false
            cleanupRecording()
            Log.d(TAG, "Recording canceled")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error canceling recording: ${e.message}")
            return false
        }
    }

    /** Cleans up recording resources */
    private fun cleanupRecording() {
        try {
            // Close the file if it's open
            recordingFile?.close()
            recordingFile = null

            // Delete the temp file if it exists
            recordingTempFile?.let { file ->
                if (file.exists()) {
                    file.delete()
                }
            }
            recordingTempFile = null
        } catch (e: Exception) {
            Log.e(TAG, "Error cleaning up recording: ${e.message}")
        }
    }

    /**
     * Ensures proper byte alignment for multi-byte samples
     *
     * @param data The PCM data
     * @param bytesPerSample Number of bytes per sample
     * @param dataSize Size of valid data in the buffer
     * @return Properly aligned PCM data
     */
    private fun ensureProperByteAlignment(
            data: ByteArray,
            bytesPerSample: Int,
            dataSize: Int
    ): ByteArray {
        // If the data length is not a multiple of bytesPerSample, pad it
        val validSize = Math.min(dataSize, data.size)
        if (validSize % bytesPerSample != 0) {
            val paddedSize = (validSize / bytesPerSample + 1) * bytesPerSample
            val paddedData = ByteArray(paddedSize)
            System.arraycopy(data, 0, paddedData, 0, validSize)
            Log.d(TAG, "Aligned 24-bit audio data: $validSize bytes -> $paddedSize bytes")
            return paddedData
        }

        // If the size is already aligned, just return a copy of the valid portion
        if (validSize < data.size) {
            val alignedData = ByteArray(validSize)
            System.arraycopy(data, 0, alignedData, 0, validSize)
            return alignedData
        }

        return data
    }

    /**
     * Converts audio data from one format to another
     *
     * @param data The PCM data to convert
     * @param dataSize Size of the data to process
     * @param sourceSampleRate Source sample rate
     * @param sourceChannels Source number of channels
     * @param sourceBitDepth Source bit depth
     * @param targetSampleRate Target sample rate
     * @param targetChannels Target number of channels
     * @param targetBitDepth Target bit depth
     * @return Converted audio data
     */
    private fun convertAudioFormat(
            data: ByteArray,
            dataSize: Int,
            sourceSampleRate: Int,
            sourceChannels: Int,
            sourceBitDepth: Int,
            targetSampleRate: Int,
            targetChannels: Int,
            targetBitDepth: Int
    ): ByteArray {
        try {
            Log.d(
                    TAG,
                    "Converting audio format: $sourceSampleRate Hz, $sourceChannels ch, $sourceBitDepth-bit -> " +
                            "$targetSampleRate Hz, $targetChannels ch, $targetBitDepth-bit"
            )

            // Step 1: Convert to a standard format (float array) for processing
            val sourceBytesPerSample = AudioPlayer.getBytesPerSample(sourceBitDepth)
            val sourceFrameSize = sourceBytesPerSample * sourceChannels
            val sourceFrameCount = dataSize / sourceFrameSize

            // Create float arrays for processing (normalized to -1.0 to 1.0)
            val sourceFloats = ByteArrayToFloatArray(data, dataSize, sourceBitDepth, sourceChannels)

            // Step 2: Perform sample rate conversion if needed
            val sampleRateConvertedFloats =
                    if (sourceSampleRate != targetSampleRate) {
                        convertSampleRate(
                                sourceFloats,
                                sourceFrameCount,
                                sourceChannels,
                                sourceSampleRate,
                                targetSampleRate
                        )
                    } else {
                        sourceFloats
                    }

            // Step 3: Perform channel conversion if needed
            val channelConvertedFloats =
                    if (sourceChannels != targetChannels) {
                        convertChannels(
                                sampleRateConvertedFloats,
                                sampleRateConvertedFloats.size / sourceChannels,
                                sourceChannels,
                                targetChannels
                        )
                    } else {
                        sampleRateConvertedFloats
                    }

            // Step 4: Convert back to byte array with the target bit depth
            return floatArrayToByteArray(channelConvertedFloats, targetBitDepth)
        } catch (e: Exception) {
            Log.e(TAG, "Error converting audio format: ${e.message}")
            e.printStackTrace()

            // If conversion fails, return the original data
            val validSize = Math.min(dataSize, data.size)
            val result = ByteArray(validSize)
            System.arraycopy(data, 0, result, 0, validSize)
            return result
        }
    }

    /** Converts a byte array to a float array */
    private fun ByteArrayToFloatArray(
            data: ByteArray,
            dataSize: Int,
            bitDepth: Int,
            channels: Int
    ): FloatArray {
        val bytesPerSample = AudioPlayer.getBytesPerSample(bitDepth)
        val frameSize = bytesPerSample * channels
        val frameCount = dataSize / frameSize
        val result = FloatArray(frameCount * channels)

        val buffer = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN)

        for (i in 0 until frameCount * channels) {
            if (buffer.remaining() < bytesPerSample) break

            // Convert based on bit depth
            val sample =
                    when (bitDepth) {
                        8 -> {
                            // 8-bit is unsigned, range 0 to 255
                            val unsignedByte = buffer.get().toInt() and 0xFF
                            (unsignedByte / 128.0f) - 1.0f // Convert to -1.0 to 1.0
                        }
                        16 -> {
                            // 16-bit is signed, range -32768 to 32767
                            buffer.short / 32768.0f
                        }
                        24 -> {
                            // 24-bit is signed, read 3 bytes and convert to int
                            // For little-endian: LSB first, then middle byte, then MSB
                            val b1 = buffer.get().toInt() and 0xFF // LSB
                            val b2 = buffer.get().toInt() and 0xFF // Middle byte
                            val b3 = buffer.get().toInt() and 0xFF // MSB

                            // Combine bytes in little-endian order (LSB first)
                            val sample24 = b1 or (b2 shl 8) or (b3 shl 16)

                            // Sign extend if negative (if bit 23 is set)
                            val signExtended =
                                    if ((sample24 and 0x800000) != 0) {
                                        sample24 or 0xFF000000.toInt()
                                    } else {
                                        sample24
                                    }

                            // Convert to float in range -1.0 to 1.0
                            // Divide by 2^23 (8388608.0f)
                            signExtended / 8388608.0f
                        }
                        32 -> {
                            // 32-bit is signed, range -2147483648 to 2147483647
                            buffer.int / 2147483648.0f
                        }
                        else -> {
                            // Default to 16-bit
                            buffer.short / 32768.0f
                        }
                    }

            result[i] = sample
        }

        return result
    }

    /** Converts a float array back to a byte array with the specified bit depth */
    private fun floatArrayToByteArray(floats: FloatArray, bitDepth: Int): ByteArray {
        val bytesPerSample = AudioPlayer.getBytesPerSample(bitDepth)
        val result = ByteArray(floats.size * bytesPerSample)
        val buffer = ByteBuffer.wrap(result).order(ByteOrder.LITTLE_ENDIAN)

        for (sample in floats) {
            // Clamp the sample to -1.0 to 1.0
            val clampedSample = Math.max(-1.0f, Math.min(1.0f, sample))

            when (bitDepth) {
                8 -> {
                    // 8-bit is unsigned, range 0 to 255
                    val unsignedByte = ((clampedSample + 1.0f) * 128.0f).toInt()
                    buffer.put(unsignedByte.toByte())
                }
                16 -> {
                    // 16-bit is signed, range -32768 to 32767
                    val shortSample = (clampedSample * 32767.0f).toInt().toShort()
                    buffer.putShort(shortSample)
                }
                24 -> {
                    // 24-bit is signed, write 3 bytes
                    val intSample = (clampedSample * 8388607.0f).toInt() // 2^23 - 1

                    // Write in little-endian order (LSB first)
                    buffer.put((intSample and 0xFF).toByte()) // LSB
                    buffer.put(((intSample shr 8) and 0xFF).toByte()) // Middle byte
                    buffer.put(((intSample shr 16) and 0xFF).toByte()) // MSB

                    // Log for debugging
                    if (intSample != 0 && Math.random() < 0.001
                    ) { // Log only 0.1% of non-zero samples
                        Log.d(
                                TAG,
                                "24-bit sample: $intSample -> bytes: " +
                                        "${(intSample and 0xFF).toString(16)} " +
                                        "${((intSample shr 8) and 0xFF).toString(16)} " +
                                        "${((intSample shr 16) and 0xFF).toString(16)}"
                        )
                    }
                }
                32 -> {
                    // 32-bit is signed, range -2147483648 to 2147483647
                    val intSample = (clampedSample * 2147483647.0f).toInt()
                    buffer.putInt(intSample)
                }
                else -> {
                    // Default to 16-bit
                    val shortSample = (clampedSample * 32767.0f).toInt().toShort()
                    buffer.putShort(shortSample)
                }
            }
        }

        return result
    }

    /** Converts audio from one sample rate to another using linear interpolation */
    private fun convertSampleRate(
            sourceFloats: FloatArray,
            sourceFrameCount: Int,
            channels: Int,
            sourceSampleRate: Int,
            targetSampleRate: Int
    ): FloatArray {
        // Calculate the target frame count based on the ratio of sample rates
        val ratio = targetSampleRate.toDouble() / sourceSampleRate.toDouble()
        val targetFrameCount = (sourceFrameCount * ratio).toInt()
        val result = FloatArray(targetFrameCount * channels)

        for (targetFrame in 0 until targetFrameCount) {
            // Calculate the corresponding source frame position (as a float)
            val sourceFrameFloat = targetFrame / ratio
            val sourceFrame1 = sourceFrameFloat.toInt()
            val sourceFrame2 = Math.min(sourceFrame1 + 1, sourceFrameCount - 1)
            val fraction = sourceFrameFloat - sourceFrame1

            // Interpolate each channel
            for (ch in 0 until channels) {
                val sample1 = sourceFloats[sourceFrame1 * channels + ch]
                val sample2 = sourceFloats[sourceFrame2 * channels + ch]

                // Linear interpolation
                result[targetFrame * channels + ch] =
                        sample1 + (sample2 - sample1) * fraction.toFloat()
            }
        }

        return result
    }

    /** Converts audio between different channel counts */
    private fun convertChannels(
            sourceFloats: FloatArray,
            sourceFrameCount: Int,
            sourceChannels: Int,
            targetChannels: Int
    ): FloatArray {
        val result = FloatArray(sourceFrameCount * targetChannels)

        for (frame in 0 until sourceFrameCount) {
            if (sourceChannels == 1 && targetChannels == 2) {
                // Mono to stereo: duplicate the mono channel
                val monoSample = sourceFloats[frame]
                result[frame * 2] = monoSample // Left channel
                result[frame * 2 + 1] = monoSample // Right channel
            } else if (sourceChannels == 2 && targetChannels == 1) {
                // Stereo to mono: average the two channels
                val leftSample = sourceFloats[frame * 2]
                val rightSample = sourceFloats[frame * 2 + 1]
                result[frame] = (leftSample + rightSample) * 0.5f
            } else {
                // For other conversions, just copy what we can and pad with zeros
                val channelsToCopy = Math.min(sourceChannels, targetChannels)
                for (ch in 0 until channelsToCopy) {
                    result[frame * targetChannels + ch] = sourceFloats[frame * sourceChannels + ch]
                }
                // Pad remaining channels with zeros
                for (ch in channelsToCopy until targetChannels) {
                    result[frame * targetChannels + ch] = 0.0f
                }
            }
        }

        return result
    }

    /**
     * Saves the current PCM buffer as a WAV file
     *
     * @param filePath Path where the WAV file should be saved
     * @return true if successful, false otherwise
     */
    fun savePcmAsWav(filePath: String): Boolean {
        // Make a copy of the PCM buffer to avoid threading issues
        val pcmCopy = ByteArray(PCM_BUFFER_SIZE * 2)
        var bytesRead = 0

        // Safely read from the PCM output buffer
        synchronized(pcmOutputBuffer) { bytesRead = pcmOutputBuffer.read(pcmCopy, 0, pcmCopy.size) }

        if (bytesRead <= 0) {
            Log.e(TAG, "No PCM data available to save")
            return false
        }

        // Create a properly sized array with just the data we read
        val pcmData = ByteArray(bytesRead)
        System.arraycopy(pcmCopy, 0, pcmData, 0, bytesRead)

        // Log the PCM data size
        Log.d(TAG, "Saving ${pcmData.size} bytes of PCM data to WAV file: $filePath")

        // Save as WAV file with the current recording parameters
        return WavRecorder.saveAsWav(
                pcmData,
                filePath,
                recordingSampleRate,
                recordingChannels,
                recordingBitDepth // Use the current recording bit depth
        )
    }

    /**
     * Gets all recordings as a JSON string
     *
     * @return JSON string containing all recordings
     */
    fun getRecordingsAsJson(): String {
        return metadataManager.getRecordingsAsJson().toString()
    }

    /**
     * Updates the title of a recording
     *
     * @param id ID of the recording to update
     * @param title New title for the recording
     * @return true if successful, false otherwise
     */
    fun updateRecordingTitle(id: String, title: String): Boolean {
        return metadataManager.updateRecording(id, title)
    }

    /**
     * Deletes a recording
     *
     * @param id ID of the recording to delete
     * @return true if successful, false otherwise
     */
    fun deleteRecording(id: String): Boolean {
        return metadataManager.deleteRecording(id)
    }

    /**
     * Calculates the RMS (Root Mean Square) value of PCM data.
     *
     * @param pcmData The PCM data as a byte array
     * @return The RMS value between 0.0 and 1.0
     */
    private fun calculateRmsValue(pcmData: ByteArray): Double {
        if (pcmData.isEmpty()) return 0.0

        try {
            var sum = 0.0
            val buffer = ByteBuffer.wrap(pcmData).order(ByteOrder.LITTLE_ENDIAN)
            val shorts = ShortArray(pcmData.size / 2)

            // Convert bytes to shorts (16-bit samples)
            for (i in shorts.indices) {
                if (buffer.remaining() >= 2) {
                    shorts[i] = buffer.short
                }
            }

            // Calculate sum of squares
            for (sample in shorts) {
                val normalizedSample = sample / 32768.0 // Normalize to -1.0 to 1.0
                sum += normalizedSample * normalizedSample
            }

            // Calculate RMS
            return Math.sqrt(sum / shorts.size)
        } catch (e: Exception) {
            Log.e(TAG, "Error calculating RMS: ${e.message}")
            return 0.0
        }
    }

    /**
     * Downsamples PCM data by a given factor to reduce data size.
     *
     * @param pcmData The original PCM data
     * @param factor The downsampling factor (e.g., 2 means take every other sample)
     * @return The downsampled PCM data
     */
    private fun downsamplePcmData(pcmData: ByteArray, factor: Int): ByteArray {
        if (factor <= 1 || pcmData.isEmpty()) return pcmData

        try {
            // For 16-bit PCM, we need to work with 2-byte samples
            val bytesPerSample = 2
            val channels = CHANNELS
            val bytesPerFrame = bytesPerSample * channels

            // Calculate the number of frames in the original data
            val frameCount = pcmData.size / bytesPerFrame

            // Calculate the number of frames after downsampling
            val downsampledFrameCount = Math.max(1, frameCount / factor)

            // Create the downsampled data array
            val downsampledData = ByteArray(downsampledFrameCount * bytesPerFrame)

            // Copy every nth frame
            for (i in 0 until downsampledFrameCount) {
                val srcPos = Math.min(i * factor * bytesPerFrame, pcmData.size - bytesPerFrame)
                val destPos = i * bytesPerFrame

                if (srcPos + bytesPerFrame <= pcmData.size &&
                                destPos + bytesPerFrame <= downsampledData.size
                ) {
                    System.arraycopy(pcmData, srcPos, downsampledData, destPos, bytesPerFrame)
                }
            }

            return downsampledData
        } catch (e: Exception) {
            Log.e(TAG, "Error downsampling PCM data: ${e.message}")
            return pcmData // Return original data if downsampling fails
        }
    }

    /**
     * Applies a moving average filter to smooth the PCM data.
     *
     * @param pcmData The PCM data as a byte array
     * @param windowSize The size of the moving average window
     * @return The smoothed PCM data
     */
    private fun applyMovingAverage(pcmData: ByteArray, windowSize: Int): ByteArray {
        if (pcmData.isEmpty() || windowSize <= 1) return pcmData

        try {
            // Convert byte array to short array (16-bit samples)
            val buffer = ByteBuffer.wrap(pcmData).order(ByteOrder.LITTLE_ENDIAN)
            val samples = ShortArray(pcmData.size / 2)
            for (i in samples.indices) {
                if (buffer.remaining() >= 2) {
                    samples[i] = buffer.short
                }
            }

            // Apply moving average to the samples
            val smoothedSamples = ShortArray(samples.size)
            for (i in samples.indices) {
                var sum = 0
                var count = 0

                // Calculate the average of the window centered at i
                for (j in
                        Math.max(0, i - windowSize / 2) until
                                Math.min(samples.size, i + windowSize / 2 + 1)) {
                    sum += samples[j]
                    count++
                }

                smoothedSamples[i] =
                        if (count > 0) (sum / count).toShort()
                        else 0 // This is already an Int division, so toShort() is fine
            }

            // Convert back to byte array
            val result = ByteArray(smoothedSamples.size * 2)
            val resultBuffer = ByteBuffer.wrap(result).order(ByteOrder.LITTLE_ENDIAN)
            for (sample in smoothedSamples) {
                resultBuffer.putShort(sample)
            }

            return result
        } catch (e: Exception) {
            Log.e(TAG, "Error applying moving average: ${e.message}")
            return pcmData // Return original data if smoothing fails
        }
    }

    /**
     * Applies logarithmic scaling to the PCM data to better match human perception.
     *
     * @param pcmData The PCM data as a byte array
     * @return The logarithmically scaled PCM data
     */
    private fun applyLogarithmicScaling(pcmData: ByteArray): ByteArray {
        if (pcmData.isEmpty()) return pcmData

        try {
            // Convert byte array to short array (16-bit samples)
            val buffer = ByteBuffer.wrap(pcmData).order(ByteOrder.LITTLE_ENDIAN)
            val samples = ShortArray(pcmData.size / 2)
            for (i in samples.indices) {
                if (buffer.remaining() >= 2) {
                    samples[i] = buffer.short
                }
            }

            // Apply logarithmic scaling to the samples
            val scaledSamples = ShortArray(samples.size)
            for (i in samples.indices) {
                val normalizedSample = samples[i] / 32768.0 // Normalize to -1.0 to 1.0
                val sign = if (normalizedSample >= 0) 1.0 else -1.0
                val magnitude = Math.abs(normalizedSample)

                // Apply logarithmic scaling (log10(x+1) gives a nice curve)
                val scaledMagnitude = Math.log10(1.0 + 9.0 * magnitude) / Math.log10(10.0)

                // Convert back to short range - first to Int, then to Short
                scaledSamples[i] = (sign * scaledMagnitude * 32767.0).toInt().toShort()
            }

            // Convert back to byte array
            val result = ByteArray(scaledSamples.size * 2)
            val resultBuffer = ByteBuffer.wrap(result).order(ByteOrder.LITTLE_ENDIAN)
            for (sample in scaledSamples) {
                resultBuffer.putShort(sample)
            }

            return result
        } catch (e: Exception) {
            Log.e(TAG, "Error applying logarithmic scaling: ${e.message}")
            return pcmData // Return original data if scaling fails
        }
    }

    /**
     * Applies a Hann window to the FFT data to reduce spectral leakage.
     *
     * @param fftData The FFT data as a byte array
     * @return The windowed FFT data
     */
    private fun applyHannWindow(fftData: ByteArray): ByteArray {
        if (fftData.isEmpty()) return fftData

        try {
            // Convert byte array to short array (16-bit samples)
            val buffer = ByteBuffer.wrap(fftData).order(ByteOrder.LITTLE_ENDIAN)
            val samples = ShortArray(fftData.size / 2)
            for (i in samples.indices) {
                if (buffer.remaining() >= 2) {
                    samples[i] = buffer.short
                }
            }

            // Apply Hann window to the samples
            val windowedSamples = ShortArray(samples.size)
            for (i in samples.indices) {
                // Hann window function: 0.5 * (1 - cos(2π * n / (N-1)))
                val windowCoefficient =
                        0.5 * (1.0 - Math.cos(2.0 * Math.PI * i / (samples.size - 1)))
                windowedSamples[i] = (samples[i] * windowCoefficient).toInt().toShort()
            }

            // Convert back to byte array
            val result = ByteArray(windowedSamples.size * 2)
            val resultBuffer = ByteBuffer.wrap(result).order(ByteOrder.LITTLE_ENDIAN)
            for (sample in windowedSamples) {
                resultBuffer.putShort(sample)
            }

            return result
        } catch (e: Exception) {
            Log.e(TAG, "Error applying Hann window: ${e.message}")
            return fftData // Return original data if windowing fails
        }
    }

    /**
     * Averages frequency bands to create a smoother frequency visualization.
     *
     * @param fftData The FFT data as a byte array
     * @param numBands The number of frequency bands to average into
     * @return The band-averaged FFT data
     */
    private fun averageFrequencyBands(fftData: ByteArray, numBands: Int): ByteArray {
        if (fftData.isEmpty() || numBands <= 0) return fftData

        try {
            // Convert byte array to short array (16-bit samples)
            val buffer = ByteBuffer.wrap(fftData).order(ByteOrder.LITTLE_ENDIAN)
            val samples = ShortArray(fftData.size / 2)
            for (i in samples.indices) {
                if (buffer.remaining() >= 2) {
                    samples[i] = buffer.short
                }
            }

            // The FFT data is in complex form (real/imaginary pairs)
            // We need to calculate the magnitude of each pair
            val magnitudes = DoubleArray(samples.size / 2)
            for (i in 0 until samples.size / 2) {
                val real = samples[i * 2].toDouble()
                val imag = samples[i * 2 + 1].toDouble()
                magnitudes[i] = Math.sqrt(real * real + imag * imag)
            }

            // Apply logarithmic band averaging (more bands in lower frequencies)
            val bandAveraged = DoubleArray(numBands)
            for (i in 0 until numBands) {
                // Calculate logarithmic band boundaries
                val startIndex =
                        (magnitudes.size * Math.pow(2.0, i.toDouble() / numBands) /
                                        Math.pow(2.0, 1.0))
                                .toInt()
                val endIndex =
                        (magnitudes.size * Math.pow(2.0, (i + 1).toDouble() / numBands) /
                                        Math.pow(2.0, 1.0))
                                .toInt() - 1

                // Average the magnitudes in this band
                var sum = 0.0
                var count = 0
                for (j in Math.max(0, startIndex) until Math.min(magnitudes.size, endIndex + 1)) {
                    sum += magnitudes[j]
                    count++
                }

                bandAveraged[i] = if (count > 0) sum / count else 0.0
            }

            // Convert back to byte array (we'll use a simplified format with just the band
            // averages)
            val result = ByteArray(numBands * 2) // 2 bytes per band
            val resultBuffer = ByteBuffer.wrap(result).order(ByteOrder.LITTLE_ENDIAN)
            for (value in bandAveraged) {
                // Scale to short range and clamp
                val scaledValue = Math.min(32767.0, Math.max(-32768.0, value))
                resultBuffer.putShort(scaledValue.toInt().toShort())
            }

            return result
        } catch (e: Exception) {
            Log.e(TAG, "Error averaging frequency bands: ${e.message}")
            return fftData // Return original data if averaging fails
        }
    }

    /**
     * Set the playback state listener
     * @param listener Callback with state, title, url, position, duration
     */
    fun setPlaybackStateListener(
            listener: (String, String?, String?, Long, Long, String?, String?) -> Unit
    ) {
        playbackStateListener = listener
    }
}
