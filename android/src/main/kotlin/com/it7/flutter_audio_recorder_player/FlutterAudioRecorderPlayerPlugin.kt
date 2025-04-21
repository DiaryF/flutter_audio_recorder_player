package com.it7.flutter_audio_recorder_player

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.util.Base64
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** FlutterAudioRecorderPlayerPlugin */
class FlutterAudioRecorderPlayerPlugin : FlutterPlugin, MethodCallHandler {
  // Static instance for callbacks from AudioSessionManager
  companion object {
    private const val TAG = "FlutterAudioRecorderPlayerPlugin"
    private const val NOTIFICATION_ID = 1001
    private const val CHANNEL_ID = "com.it7.flutter_audio_recorder_player.channel.audio"

    // Static instance for callbacks
    var instance: FlutterAudioRecorderPlayerPlugin? = null
  }
  /// The MethodChannel that will the communication between Flutter and native Android
  private lateinit var channel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private lateinit var context: Context
  private var audioPlayer: AudioPlayer? = null
  private var eventSink: EventChannel.EventSink? = null
  private var playbackStateReceiver: PlaybackStateReceiver? = null

  // Audio session channels and event sinks
  private var interruptionChannel: EventChannel? = null
  private var becomingNoisyChannel: EventChannel? = null
  private var interruptionEventSink: EventChannel.EventSink? = null
  private var becomingNoisyEventSink: EventChannel.EventSink? = null

  // Audio session manager
  private lateinit var audioSessionManager: AudioSessionManager

  // Notification service
  private lateinit var notificationService: NotificationService

  // WAV file handler for audio editing features
  private val wavFileHandler = WavFileHandler()

  /** Shows a playback notification */
  private fun showPlaybackNotification(title: String, url: String) {
    // Create notification channel for Android O and above
    val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel =
              NotificationChannel(CHANNEL_ID, "Audio Playback", NotificationManager.IMPORTANCE_LOW)
                      .apply {
                        description = "Audio playback controls"
                        setShowBadge(false)
                      }

      notificationManager.createNotificationChannel(channel)
      Log.d(TAG, "Notification channel created: $CHANNEL_ID")
    }

    // Create content intent (opens app when notification is clicked)
    val packageName = context.packageName
    val launchIntent = context.packageManager.getLaunchIntentForPackage(packageName)

    val flags =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
              PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
              PendingIntent.FLAG_UPDATE_CURRENT
            }

    val contentIntent = PendingIntent.getActivity(context, 0, launchIntent, flags)

    // Create notification
    val notification =
            NotificationCompat.Builder(context, CHANNEL_ID)
                    .setContentTitle(title)
                    .setContentText("Now Playing")
                    .setSmallIcon(R.drawable.ic_notification)
                    .setLargeIcon(
                            try {
                              // Try to get the app icon
                              val appIcon =
                                      context.packageManager.getApplicationIcon(context.packageName)
                              val bitmap =
                                      Bitmap.createBitmap(
                                              appIcon.intrinsicWidth,
                                              appIcon.intrinsicHeight,
                                              Bitmap.Config.ARGB_8888
                                      )
                              val canvas = Canvas(bitmap)
                              appIcon.setBounds(0, 0, canvas.width, canvas.height)
                              appIcon.draw(canvas)
                              bitmap
                            } catch (e: Exception) {
                              Log.e(TAG, "Error creating bitmap from app icon: ${e.message}")
                              null
                            }
                    )
                    .setContentIntent(contentIntent)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setOngoing(true)
                    .build()

    // Show the notification
    notificationManager.notify(NOTIFICATION_ID, notification)
    Log.d(TAG, "Showing notification for: $title")
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    val appContext = flutterPluginBinding.applicationContext
    val methodChannel =
            MethodChannel(
                    flutterPluginBinding.binaryMessenger,
                    "com.it7.flutter_audio_recorder_player/methods"
            )
    val evtChannel =
            EventChannel(
                    flutterPluginBinding.binaryMessenger,
                    "com.it7.flutter_audio_recorder_player/events"
            )

    // Create audio session event channels
    val interruptionChannel =
            EventChannel(
                    flutterPluginBinding.binaryMessenger,
                    "com.it7.flutter_audio_recorder_player/audio_interruptions"
            )
    val becomingNoisyChannel =
            EventChannel(
                    flutterPluginBinding.binaryMessenger,
                    "com.it7.flutter_audio_recorder_player/becoming_noisy"
            )

    // Create notification channels
    val notificationMethodChannel =
            MethodChannel(
                    flutterPluginBinding.binaryMessenger,
                    "com.it7.flutter_audio_recorder_player/notification"
            )
    val notificationEventChannel =
            EventChannel(
                    flutterPluginBinding.binaryMessenger,
                    "com.it7.flutter_audio_recorder_player/notification_events"
            )

    onAttachedToEngine(
            appContext,
            methodChannel,
            evtChannel,
            interruptionChannel,
            becomingNoisyChannel,
            notificationMethodChannel,
            notificationEventChannel
    )
  }

  // This method is used for testing
  internal fun onAttachedToEngine(
          appContext: Context,
          methodChannel: MethodChannel,
          evtChannel: EventChannel,
          interruptionChannel: EventChannel,
          becomingNoisyChannel: EventChannel,
          notificationMethodChannel: MethodChannel,
          notificationEventChannel: EventChannel
  ) {
    context = appContext
    channel = methodChannel
    eventChannel = evtChannel
    this.interruptionChannel = interruptionChannel
    this.becomingNoisyChannel = becomingNoisyChannel

    // Set the static instance
    instance = this

    channel.setMethodCallHandler(this)
    setupEventChannel()

    // Initialize the audio session manager
    audioSessionManager = AudioSessionManager(context)

    // Initialize the notification service
    notificationService = NotificationService(context)
    notificationService.initialize(notificationMethodChannel, notificationEventChannel)

    // Initialize the audio player
    audioPlayer = AudioPlayer(context)
    audioPlayer?.setVisualizerDataCallback { waveform, fft -> sendVisualizationData(waveform, fft) }
    audioPlayer?.setPcmDataCallback { pcmData -> sendPcmData(pcmData) }

    // Register the playback state receiver
    playbackStateReceiver = PlaybackStateReceiver { action, data ->
      if (action == PlaybackStateReceiver.ACTION_PLAYBACK_STATE_CHANGED) {
        sendPlaybackStateUpdate(data)
      }
    }

    // Register the receiver with the context
    val intentFilter =
            android.content.IntentFilter(PlaybackStateReceiver.ACTION_PLAYBACK_STATE_CHANGED)
    context.registerReceiver(playbackStateReceiver, intentFilter)

    // Register the notification action receiver
    val notificationActionFilter =
            android.content.IntentFilter(
                    "com.it7.flutter_audio_recorder_player.NOTIFICATION_ACTION"
            )
    context.registerReceiver(NotificationActionReceiver(), notificationActionFilter)
  }

  private fun setupEventChannel() {
    // Main event channel
    eventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
              override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
              }

              override fun onCancel(arguments: Any?) {
                eventSink = null
              }
            }
    )

    // Audio interruptions channel
    interruptionChannel?.setStreamHandler(
            object : EventChannel.StreamHandler {
              override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                interruptionEventSink = events
              }

              override fun onCancel(arguments: Any?) {
                interruptionEventSink = null
              }
            }
    )

    // Becoming noisy channel
    becomingNoisyChannel?.setStreamHandler(
            object : EventChannel.StreamHandler {
              override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                becomingNoisyEventSink = events
              }

              override fun onCancel(arguments: Any?) {
                becomingNoisyEventSink = null
              }
            }
    )
  }

  private fun sendVisualizationData(waveform: ByteArray, fft: ByteArray) {
    if (eventSink == null) return

    try {
      val data = mutableMapOf<String, Any>()
      data["type"] = "visualization"
      data["timestamp"] = System.currentTimeMillis()

      if (waveform.isNotEmpty()) {
        data["waveform"] = Base64.encodeToString(waveform, Base64.NO_WRAP)
        Log.d("FlutterAudioRecorderPlayerPlugin", "Sending waveform data: ${waveform.size} bytes")
      }

      if (fft.isNotEmpty()) {
        data["fft"] = Base64.encodeToString(fft, Base64.NO_WRAP)
        Log.d("FlutterAudioRecorderPlayerPlugin", "Sending FFT data: ${fft.size} bytes")
      }

      // Always send data even if waveform and fft are empty
      // This helps maintain a continuous stream of events
      eventSink?.success(data)
    } catch (e: Exception) {
      Log.e("FlutterAudioRecorderPlayerPlugin", "Error sending visualization data: ${e.message}")
    }
  }

  private fun sendPcmData(pcmData: ByteArray) {
    if (eventSink == null) return

    try {
      // Calculate RMS value for the PCM data
      val rms = calculateRms(pcmData)

      val data = mutableMapOf<String, Any>()
      data["pcm"] = Base64.encodeToString(pcmData, Base64.NO_WRAP)
      data["type"] = "pcm"
      data["rms"] = rms
      data["timestamp"] = System.currentTimeMillis()

      eventSink?.success(data)
    } catch (e: Exception) {
      Log.e("FlutterAudioRecorderPlayerPlugin", "Error sending PCM data: ${e.message}")
    }
  }

  private fun sendPlaybackStateUpdate(stateData: Map<String, Any>) {
    if (eventSink == null) return

    try {
      val data = mutableMapOf<String, Any>()
      data["type"] = "playbackState"
      data["state"] =
              stateData[PlaybackStateReceiver.EXTRA_STATE] ?: PlaybackStateReceiver.STATE_STOPPED
      data["title"] = stateData[PlaybackStateReceiver.EXTRA_TITLE] ?: "Unknown"
      data["position"] = stateData[PlaybackStateReceiver.EXTRA_POSITION] ?: 0L
      data["duration"] = stateData[PlaybackStateReceiver.EXTRA_DURATION] ?: 0L
      data["timestamp"] = System.currentTimeMillis()

      eventSink?.success(data)
    } catch (e: Exception) {
      Log.e(TAG, "Error sending playback state update: ${e.message}")
    }
  }

  /** Calculates the RMS (Root Mean Square) value of PCM data. */
  private fun calculateRms(pcmData: ByteArray): Double {
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
      Log.e("FlutterAudioRecorderPlayerPlugin", "Error calculating RMS: ${e.message}")
      return 0.0
    }
  }

  // Audio focus callbacks
  fun onAudioFocusGained() {
    // Send an interruption event to Flutter
    sendInterruptionEvent(false, "none")
  }

  fun onAudioFocusLost() {
    // Pause playback
    audioPlayer?.pausePlayback()

    // Send an interruption event to Flutter
    sendInterruptionEvent(true, "pause")
  }

  fun onAudioFocusLostTransient() {
    // Pause playback
    audioPlayer?.pausePlayback()

    // Send an interruption event to Flutter
    sendInterruptionEvent(true, "pause")
  }

  fun onAudioFocusLostTransientCanDuck() {
    // Lower volume if we shouldn't pause when ducked
    if (!audioSessionManager.shouldPauseWhenDucked()) {
      audioPlayer?.setVolume(0.5f)

      // Send an interruption event to Flutter
      sendInterruptionEvent(true, "duck")
    } else {
      // Pause playback
      audioPlayer?.pausePlayback()

      // Send an interruption event to Flutter
      sendInterruptionEvent(true, "pause")
    }
  }

  private fun sendInterruptionEvent(begin: Boolean, type: String) {
    if (interruptionEventSink == null) return

    try {
      val data = mutableMapOf<String, Any>()
      data["type"] = "interruption"
      data["begin"] = begin
      data["interruptionType"] = type

      interruptionEventSink?.success(data)
    } catch (e: Exception) {
      Log.e(TAG, "Error sending interruption event: ${e.message}")
    }
  }

  private fun sendBecomingNoisyEvent() {
    if (becomingNoisyEventSink == null) return

    try {
      val data = mutableMapOf<String, Any>()
      data["type"] = "becomingNoisy"

      becomingNoisyEventSink?.success(data)
    } catch (e: Exception) {
      Log.e(TAG, "Error sending becoming noisy event: ${e.message}")
    }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "initialize" -> {
        // Initialize the audio session manager
        result.success(null)
      }
      "configure" -> {
        val contentType =
                call.argument<Int>("contentType") ?: AudioSessionManager.CONTENT_TYPE_MUSIC
        val focusGainType = call.argument<Int>("focusStrategy") ?: AudioSessionManager.FOCUS_GAIN
        val pauseWhenDucked = call.argument<Boolean>("pauseWhenDucked") ?: false

        // Configure the audio session
        audioSessionManager.configure(contentType, focusGainType, pauseWhenDucked)

        result.success(null)
      }
      "setActive" -> {
        val active = call.argument<Boolean>("active") ?: false

        if (active) {
          // Request audio focus
          val success = audioSessionManager.requestAudioFocus()
          result.success(success)
        } else {
          // Abandon audio focus
          audioSessionManager.abandonAudioFocus()
          result.success(true)
        }
      }
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "startPlayback" -> {
        val url = call.argument<String>("url")
        val title = call.argument<String>("title") ?: "Now Playing"
        if (url != null) {
          try {
            // Start playback first
            audioPlayer?.startPlayback(
                    url,
                    object : MethodChannel.Result {
                      override fun success(data: Any?) {
                        try {
                          // Start the service with the URL and title
                          val serviceIntent =
                                  android.content.Intent(context, AudioService::class.java).apply {
                                    putExtra("url", url)
                                    putExtra("title", title)
                                    action = AudioService.ACTION_PLAY
                                    // Add a flag to indicate this is a new playback
                                    putExtra("isNewPlayback", true)
                                  }

                          // Start the service in the foreground
                          if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O
                          ) {
                            context.startForegroundService(serviceIntent)
                          } else {
                            context.startService(serviceIntent)
                          }

                          // Connect the AudioPlayer to the AudioService
                          try {
                            val serviceIntent =
                                    android.content.Intent(context, AudioService::class.java)
                            val connection =
                                    object : android.content.ServiceConnection {
                                      override fun onServiceConnected(
                                              name: android.content.ComponentName?,
                                              service: android.os.IBinder?
                                      ) {
                                        val binder = service as? AudioService.LocalBinder
                                        val audioService = binder?.getService()
                                        audioService?.setAudioPlayer(audioPlayer!!)
                                        Log.d(TAG, "Connected AudioPlayer to AudioService")
                                      }

                                      override fun onServiceDisconnected(
                                              name: android.content.ComponentName?
                                      ) {
                                        Log.d(TAG, "AudioService disconnected")
                                      }
                                    }

                            // Bind to the service
                            context.bindService(
                                    serviceIntent,
                                    connection,
                                    android.content.Context.BIND_AUTO_CREATE
                            )
                          } catch (e: Exception) {
                            Log.e(TAG, "Error connecting to AudioService: ${e.message}")
                          }

                          // Return success to Flutter
                          result.success(true)
                        } catch (e: Exception) {
                          Log.e(TAG, "Error starting service: ${e.message}")
                          result.error(
                                  "SERVICE_ERROR",
                                  "Error starting service: ${e.message}",
                                  null
                          )
                        }
                      }

                      override fun error(code: String, message: String?, details: Any?) {
                        result.error(code, message, details)
                      }

                      override fun notImplemented() {
                        result.notImplemented()
                      }
                    }
            )
          } catch (e: Exception) {
            Log.e(TAG, "Error starting playback: ${e.message}")
            result.error("PLAYBACK_ERROR", "Error starting playback: ${e.message}", null)
          }
        } else {
          result.error("INVALID_ARGUMENT", "URL cannot be null", null)
        }
      }
      "stopPlayback" -> {
        try {
          // Stop the audio player
          audioPlayer?.stopPlayback()

          // Send stop action to the service
          val serviceIntent =
                  android.content.Intent(context, AudioService::class.java).apply {
                    action = AudioService.ACTION_STOP
                  }
          context.startService(serviceIntent)

          result.success(null)
        } catch (e: Exception) {
          Log.e(TAG, "Error stopping playback: ${e.message}")
          result.error("PLAYBACK_ERROR", "Error stopping playback: ${e.message}", null)
        }
      }
      "isPlaying" -> {
        result.success(audioPlayer?.isPlaying())
      }
      "pausePlayback" -> {
        try {
          // Pause the audio player
          audioPlayer?.pausePlayback()

          // Send pause action to the service
          val serviceIntent =
                  android.content.Intent(context, AudioService::class.java).apply {
                    action = AudioService.ACTION_PAUSE
                  }
          context.startService(serviceIntent)

          result.success(null)
        } catch (e: Exception) {
          Log.e(TAG, "Error pausing playback: ${e.message}")
          result.error("PLAYBACK_ERROR", "Error pausing playback: ${e.message}", null)
        }
      }
      "resumePlayback" -> {
        try {
          // Resume the audio player
          audioPlayer?.resumePlayback()

          // Send play action to the service
          val serviceIntent =
                  android.content.Intent(context, AudioService::class.java).apply {
                    action = AudioService.ACTION_PLAY
                  }
          context.startService(serviceIntent)

          result.success(null)
        } catch (e: Exception) {
          Log.e(TAG, "Error resuming playback: ${e.message}")
          result.error("PLAYBACK_ERROR", "Error resuming playback: ${e.message}", null)
        }
      }
      "getPosition" -> {
        result.success(audioPlayer?.getCurrentPosition())
      }
      "getDuration" -> {
        result.success(audioPlayer?.getDuration())
      }
      "seekTo" -> {
        val position = call.argument<Number>("position")
        if (position != null) {
          audioPlayer?.seekTo(position.toLong())
          result.success(null)
        } else {
          result.error("INVALID_ARGUMENT", "Position cannot be null", null)
        }
      }
      "setVolume" -> {
        val volume = call.argument<Double>("volume")
        if (volume != null) {
          audioPlayer?.setVolume(volume.toFloat())
          result.success(null)
        } else {
          result.error("INVALID_ARGUMENT", "Volume cannot be null", null)
        }
      }
      "setSpeed" -> {
        val speed = call.argument<Double>("speed")
        if (speed != null) {
          audioPlayer?.setSpeed(speed.toFloat())
          result.success(null)
        } else {
          result.error("INVALID_ARGUMENT", "Speed cannot be null", null)
        }
      }
      "savePcmAsWav" -> {
        val filePath = call.argument<String>("filePath")
        if (filePath != null) {
          val success = audioPlayer?.savePcmAsWav(filePath) ?: false
          result.success(success)
        } else {
          result.error("INVALID_ARGUMENT", "File path cannot be null", null)
        }
      }
      "startRecording" -> {
        val sampleRate = call.argument<Int>("sampleRate")
        val channels = call.argument<Int>("channels")
        val bitDepth = call.argument<Int>("bitDepth")
        val title = call.argument<String>("title")

        val success =
                audioPlayer?.startRecording(
                        sampleRate ?: 44100,
                        channels ?: 2,
                        bitDepth ?: 16,
                        title
                )
                        ?: false

        result.success(success)
      }
      "stopRecording" -> {
        val filePath = call.argument<String>("filePath")
        if (filePath != null) {
          val success = audioPlayer?.stopRecording(filePath) ?: false
          result.success(success)
        } else {
          result.error("INVALID_ARGUMENT", "File path cannot be null", null)
        }
      }
      "cancelRecording" -> {
        val success = audioPlayer?.cancelRecording() ?: false
        result.success(success)
      }
      "getRecordings" -> {
        val recordingsJson = audioPlayer?.getRecordingsAsJson()?.toString() ?: "[]"
        result.success(recordingsJson)
      }
      "updateRecordingTitle" -> {
        val id = call.argument<String>("id")
        val title = call.argument<String>("title")

        if (id != null && title != null) {
          val success = audioPlayer?.updateRecordingTitle(id, title) ?: false
          result.success(success)
        } else {
          result.error("INVALID_ARGUMENT", "Recording ID and title are required", null)
        }
      }
      "deleteRecording" -> {
        val id = call.argument<String>("id")

        if (id != null) {
          val success = audioPlayer?.deleteRecording(id) ?: false
          result.success(success)
        } else {
          result.error("INVALID_ARGUMENT", "Recording ID is required", null)
        }
      }
      // WAV file editing methods
      "generateWaveformData" -> {
        val filePath = call.argument<String>("filePath")
        val samplesCount = call.argument<Int>("samplesCount") ?: 100

        if (filePath != null) {
          try {
            val waveformData = wavFileHandler.generateWaveformData(filePath, samplesCount)
            if (waveformData != null) {
              result.success(Base64.encodeToString(waveformData, Base64.NO_WRAP))
            } else {
              result.error("WAVEFORM_ERROR", "Failed to generate waveform data", null)
            }
          } catch (e: Exception) {
            Log.e(TAG, "Error generating waveform data: ${e.message}")
            result.error("WAVEFORM_ERROR", "Error generating waveform data: ${e.message}", null)
          }
        } else {
          result.error("INVALID_ARGUMENT", "File path cannot be null", null)
        }
      }
      "parseWavHeader" -> {
        val filePath = call.argument<String>("filePath")

        if (filePath != null) {
          try {
            val header = wavFileHandler.parseWavHeader(filePath)
            if (header != null) {
              val headerInfo =
                      mapOf(
                              "sampleRate" to header.sampleRate,
                              "channels" to header.channels,
                              "bitsPerSample" to header.bitsPerSample,
                              "dataSize" to header.dataSize,
                              "durationMs" to header.durationMs
                      )
              result.success(headerInfo)
            } else {
              result.error("HEADER_ERROR", "Failed to parse WAV header", null)
            }
          } catch (e: Exception) {
            Log.e(TAG, "Error parsing WAV header: ${e.message}")
            result.error("HEADER_ERROR", "Error parsing WAV header: ${e.message}", null)
          }
        } else {
          result.error("INVALID_ARGUMENT", "File path cannot be null", null)
        }
      }
      "trimWavFile" -> {
        val inputPath = call.argument<String>("inputPath")
        val outputPath = call.argument<String>("outputPath")
        val startMs = call.argument<Int>("startMs") ?: 0
        val endMs = call.argument<Int>("endMs") ?: 0

        if (inputPath != null && outputPath != null) {
          try {
            val success = wavFileHandler.trimWavFile(inputPath, outputPath, startMs, endMs)
            result.success(success)
          } catch (e: Exception) {
            Log.e(TAG, "Error trimming WAV file: ${e.message}")
            result.error("TRIM_ERROR", "Error trimming WAV file: ${e.message}", null)
          }
        } else {
          result.error("INVALID_ARGUMENT", "Input and output paths cannot be null", null)
        }
      }
      "joinWavFiles" -> {
        val inputPaths = call.argument<List<String>>("inputPaths")
        val outputPath = call.argument<String>("outputPath")

        if (inputPaths != null && outputPath != null) {
          try {
            val success = wavFileHandler.joinWavFiles(inputPaths, outputPath)
            result.success(success)
          } catch (e: Exception) {
            Log.e(TAG, "Error joining WAV files: ${e.message}")
            result.error("JOIN_ERROR", "Error joining WAV files: ${e.message}", null)
          }
        } else {
          result.error("INVALID_ARGUMENT", "Input paths and output path cannot be null", null)
        }
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
    interruptionChannel?.setStreamHandler(null)
    becomingNoisyChannel?.setStreamHandler(null)
    audioPlayer?.releaseResources()
    audioPlayer = null

    // Unregister the receivers
    try {
      if (playbackStateReceiver != null) {
        context.unregisterReceiver(playbackStateReceiver)
        playbackStateReceiver = null
      }

      // Try to unregister the notification action receiver
      try {
        context.unregisterReceiver(NotificationActionReceiver())
      } catch (e: Exception) {
        // Ignore, it might not be registered
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error unregistering receiver: ${e.message}")
    }
  }

  /** Get the notification service */
  fun getNotificationService(): NotificationService {
    return notificationService
  }
}
