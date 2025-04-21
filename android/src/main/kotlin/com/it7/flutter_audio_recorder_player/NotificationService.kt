package com.it7.flutter_audio_recorder_player

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Service for managing audio playback notifications
 */
class NotificationService(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "NotificationService"
        private const val NOTIFICATION_ID = 1002 // Different from AudioService's ID
        private const val DEFAULT_CHANNEL_ID = "com.it7.flutter_audio_recorder_player.channel.notification"
        
        // Action constants
        const val ACTION_PLAY = "play"
        const val ACTION_PAUSE = "pause"
        const val ACTION_STOP = "stop"
        const val ACTION_NEXT = "next"
        const val ACTION_PREVIOUS = "previous"
    }

    // Notification manager
    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    
    // Channel ID
    private var channelId = DEFAULT_CHANNEL_ID
    
    // Event sink for sending notification actions back to Flutter
    private var eventSink: EventChannel.EventSink? = null
    
    // Whether the service is initialized
    private var initialized = false

    /**
     * Initialize the method channel handler
     */
    fun initialize(channel: MethodChannel, eventChannel: EventChannel) {
        // Set method call handler
        channel.setMethodCallHandler(this)
        
        // Set event channel handler
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                Log.d(TAG, "Notification event channel listening")
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                Log.d(TAG, "Notification event channel cancelled")
            }
        })
    }

    /**
     * Handle method calls from Flutter
     */
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val channelId = call.argument<String>("channelId") ?: DEFAULT_CHANNEL_ID
                val channelName = call.argument<String>("channelName") ?: "Audio Playback"
                val channelDescription = call.argument<String>("channelDescription") ?: "Audio playback controls"
                
                // Create notification channel
                createNotificationChannel(channelId, channelName, channelDescription)
                
                // Store channel ID
                this.channelId = channelId
                
                // Mark as initialized
                initialized = true
                
                // Return success
                result.success(true)
                Log.d(TAG, "Notification service initialized with channel ID: $channelId")
            }
            "showNotification" -> {
                if (!initialized) {
                    result.error("NOT_INITIALIZED", "Notification service not initialized", null)
                    return
                }
                
                val title = call.argument<String>("title") ?: "Now Playing"
                val artist = call.argument<String>("artist")
                val album = call.argument<String>("album")
                val artUri = call.argument<String>("artUri")
                val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                val position = call.argument<Int>("position") ?: 0
                val duration = call.argument<Int>("duration") ?: 0
                val showControls = call.argument<Boolean>("showControls") ?: true
                
                // Show notification
                showNotification(title, artist, album, isPlaying, showControls)
                
                // Return success
                result.success(true)
            }
            "hideNotification" -> {
                if (!initialized) {
                    result.error("NOT_INITIALIZED", "Notification service not initialized", null)
                    return
                }
                
                // Hide notification
                notificationManager.cancel(NOTIFICATION_ID)
                
                // Return success
                result.success(true)
                Log.d(TAG, "Notification hidden")
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Create notification channel for Android O and above
     */
    private fun createNotificationChannel(channelId: String, channelName: String, channelDescription: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = channelDescription
                setShowBadge(false)
            }
            
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created: $channelId")
        }
    }

    /**
     * Show a playback notification
     */
    private fun showNotification(
        title: String,
        artist: String?,
        album: String?,
        isPlaying: Boolean,
        showControls: Boolean
    ) {
        // Create content intent (opens app when notification is clicked)
        val packageName = context.packageName
        val launchIntent = context.packageManager.getLaunchIntentForPackage(packageName)
        
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        
        val contentIntent = PendingIntent.getActivity(context, 0, launchIntent, flags)
        
        // Create notification builder
        val builder = NotificationCompat.Builder(context, channelId)
            .setContentTitle(title)
            .setContentText(artist ?: album ?: "Now Playing")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(contentIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
        
        // Add large icon (app icon)
        try {
            val appIcon = context.packageManager.getApplicationIcon(context.packageName)
            val bitmap = Bitmap.createBitmap(
                appIcon.intrinsicWidth,
                appIcon.intrinsicHeight,
                Bitmap.Config.ARGB_8888
            )
            val canvas = Canvas(bitmap)
            appIcon.setBounds(0, 0, canvas.width, canvas.height)
            appIcon.draw(canvas)
            builder.setLargeIcon(bitmap)
        } catch (e: Exception) {
            Log.e(TAG, "Error creating bitmap from app icon: ${e.message}")
        }
        
        // Add controls if requested
        if (showControls) {
            // Create media style
            val mediaStyle = androidx.media.app.NotificationCompat.MediaStyle()
                .setShowActionsInCompactView(0, 1, 2)
            
            // Add style to builder
            builder.setStyle(mediaStyle)
            
            // Add actions based on playback state
            if (isPlaying) {
                // Add pause action
                builder.addAction(
                    R.drawable.ic_pause,
                    "Pause",
                    createActionIntent(ACTION_PAUSE)
                )
            } else {
                // Add play action
                builder.addAction(
                    R.drawable.ic_play,
                    "Play",
                    createActionIntent(ACTION_PLAY)
                )
            }
            
            // Add previous and next actions
            builder.addAction(
                R.drawable.ic_skip_previous,
                "Previous",
                createActionIntent(ACTION_PREVIOUS)
            )
            
            builder.addAction(
                R.drawable.ic_skip_next,
                "Next",
                createActionIntent(ACTION_NEXT)
            )
            
            // Add stop action
            builder.addAction(
                R.drawable.ic_stop,
                "Stop",
                createActionIntent(ACTION_STOP)
            )
        }
        
        // Show notification
        notificationManager.notify(NOTIFICATION_ID, builder.build())
        Log.d(TAG, "Showing notification for: $title")
    }

    /**
     * Create a PendingIntent for notification actions
     */
    private fun createActionIntent(action: String): PendingIntent {
        val intent = Intent("com.it7.flutter_audio_recorder_player.NOTIFICATION_ACTION").apply {
            putExtra("action", action)
        }
        
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        
        return PendingIntent.getBroadcast(
            context,
            when (action) {
                ACTION_PLAY -> 1
                ACTION_PAUSE -> 2
                ACTION_STOP -> 3
                ACTION_NEXT -> 4
                ACTION_PREVIOUS -> 5
                else -> 0
            },
            intent,
            flags
        )
    }

    /**
     * Send action to Flutter
     */
    fun sendAction(action: String) {
        eventSink?.success(action)
        Log.d(TAG, "Sent action to Flutter: $action")
    }
}
