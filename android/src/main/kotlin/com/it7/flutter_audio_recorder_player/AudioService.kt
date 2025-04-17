package com.example.mymedia

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.media.MediaBrowserServiceCompat
import androidx.media.app.NotificationCompat.MediaStyle
import androidx.media.session.MediaButtonReceiver
import java.util.ArrayList

/** Media browser service for background audio playback with notifications */
class AudioService : MediaBrowserServiceCompat() {
    private val binder = LocalBinder()
    private var audioPlayer: AudioPlayer? = null
    private var currentTitle = "Now Playing"
    private var currentArtist: String? = null
    private var currentAlbum: String? = null
    private var albumArt: android.graphics.Bitmap? = null
    private var isPlaying = false
    private lateinit var notificationManager: NotificationManager
    private lateinit var mediaSession: MediaSessionCompat

    companion object {
        private const val TAG = "AudioService"
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "com.example.mymedia.channel.audio"

        const val ACTION_PLAY = "com.example.mymedia.PLAY"
        const val ACTION_PAUSE = "com.example.mymedia.PAUSE"
        const val ACTION_STOP = "com.example.mymedia.STOP"
        const val ACTION_SKIP_FORWARD = "com.example.mymedia.SKIP_FORWARD"
        const val ACTION_SKIP_BACKWARD = "com.example.mymedia.SKIP_BACKWARD"

        // Root ID for media browser
        private const val ROOT_ID = "root_id"
    }

    inner class LocalBinder : Binder() {
        fun getService(): AudioService = this@AudioService
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "AudioService created")

        // Initialize notification manager
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create notification channel
        createNotificationChannel()

        // Initialize media session
        mediaSession =
                MediaSessionCompat(this, "MymediaSession").apply {
                    // Set initial PlaybackState
                    setPlaybackState(
                            PlaybackStateCompat.Builder()
                                    .setState(PlaybackStateCompat.STATE_NONE, 0, 1.0f)
                                    .setActions(
                                            PlaybackStateCompat.ACTION_PLAY or
                                                    PlaybackStateCompat.ACTION_PAUSE or
                                                    PlaybackStateCompat.ACTION_STOP
                                    )
                                    .build()
                    )

                    // Set callback
                    setCallback(
                            object : MediaSessionCompat.Callback() {
                                override fun onPlay() {
                                    Log.d(TAG, "MediaSession: onPlay")
                                    audioPlayer?.resumePlayback()
                                    updatePlaybackState(PlaybackStateCompat.STATE_PLAYING)
                                }

                                override fun onPause() {
                                    Log.d(TAG, "MediaSession: onPause")
                                    audioPlayer?.pausePlayback()
                                    updatePlaybackState(PlaybackStateCompat.STATE_PAUSED)
                                }

                                override fun onStop() {
                                    Log.d(TAG, "MediaSession: onStop")
                                    audioPlayer?.stopPlayback()
                                    updatePlaybackState(PlaybackStateCompat.STATE_STOPPED)
                                    stopSelf()
                                }
                            }
                    )

                    // Set active
                    isActive = true
                }

        // Set the session token for the media browser service
        sessionToken = mediaSession.sessionToken
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "AudioService started with intent: ${intent?.action}")

        // Handle media button events
        MediaButtonReceiver.handleIntent(mediaSession, intent)

        // Get URL and title from intent
        val url = intent?.getStringExtra("url")
        val title = intent?.getStringExtra("title")

        if (title != null) {
            currentTitle = title

            // Update metadata
            val metadataBuilder =
                    MediaMetadataCompat.Builder()
                            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
                            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_TITLE, title)
                            .putString(
                                    MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE,
                                    "Now Playing"
                            )

            mediaSession.setMetadata(metadataBuilder.build())
        }

        // Check if this is a new playback request
        val isNewPlayback = intent?.getBooleanExtra("isNewPlayback", false) ?: false

        when (intent?.action) {
            ACTION_PLAY -> {
                if (isNewPlayback && url != null) {
                    // This is a new playback request, don't control the player directly
                    // The player is already started by the plugin
                    isPlaying = true
                    updatePlaybackState(PlaybackStateCompat.STATE_PLAYING)
                } else {
                    // This is a resume request from notification
                    isPlaying = true
                    audioPlayer?.resumePlayback()
                    updatePlaybackState(PlaybackStateCompat.STATE_PLAYING)
                }
            }
            ACTION_PAUSE -> {
                isPlaying = false
                audioPlayer?.pausePlayback()
                updatePlaybackState(PlaybackStateCompat.STATE_PAUSED)
            }
            ACTION_SKIP_FORWARD -> {
                // Skip forward 10 seconds
                val currentPosition = audioPlayer?.getCurrentPosition() ?: 0
                audioPlayer?.seekTo(currentPosition + 10000) // 10 seconds in milliseconds
                updatePlaybackState(
                        if (isPlaying) PlaybackStateCompat.STATE_PLAYING
                        else PlaybackStateCompat.STATE_PAUSED
                )
            }
            ACTION_SKIP_BACKWARD -> {
                // Skip backward 10 seconds
                val currentPosition = audioPlayer?.getCurrentPosition() ?: 0
                audioPlayer?.seekTo(
                        Math.max(0, currentPosition - 10000)
                ) // 10 seconds in milliseconds
                updatePlaybackState(
                        if (isPlaying) PlaybackStateCompat.STATE_PLAYING
                        else PlaybackStateCompat.STATE_PAUSED
                )
            }
            ACTION_STOP -> {
                isPlaying = false
                audioPlayer?.stopPlayback()
                updatePlaybackState(PlaybackStateCompat.STATE_STOPPED)
                stopForeground(true)
                stopSelf()
                return START_NOT_STICKY
            }
        }

        // Start foreground immediately to avoid ANR
        val notification = createNotification()
        Log.d(TAG, "Starting foreground with notification")
        startForeground(NOTIFICATION_ID, notification)

        return START_STICKY
    }

    override fun onBind(intent: Intent): IBinder? {
        return if (SERVICE_INTERFACE == intent.action) {
            super.onBind(intent)
        } else {
            binder
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "AudioService destroyed")
        mediaSession.release()
        super.onDestroy()
    }

    /** Create notification channel for Android O and above */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel =
                    NotificationChannel(
                                    CHANNEL_ID,
                                    "Audio Playback",
                                    NotificationManager.IMPORTANCE_LOW
                            )
                            .apply {
                                description = "Audio playback controls"
                                setShowBadge(false)
                            }

            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created: $CHANNEL_ID")
        }
    }

    /** Create a media style notification */
    private fun createNotification(): Notification {
        // Create skip backward action
        val skipBackwardAction =
                NotificationCompat.Action(
                        R.drawable.ic_skip_previous,
                        "Skip Backward",
                        createActionPendingIntent(ACTION_SKIP_BACKWARD)
                )

        // Create play/pause action
        val playPauseAction =
                if (isPlaying) {
                    // Create pause action
                    NotificationCompat.Action(
                            R.drawable.ic_pause,
                            "Pause",
                            createActionPendingIntent(ACTION_PAUSE)
                    )
                } else {
                    // Create play action
                    NotificationCompat.Action(
                            R.drawable.ic_play,
                            "Play",
                            createActionPendingIntent(ACTION_PLAY)
                    )
                }

        // Create skip forward action
        val skipForwardAction =
                NotificationCompat.Action(
                        R.drawable.ic_skip_next,
                        "Skip Forward",
                        createActionPendingIntent(ACTION_SKIP_FORWARD)
                )

        // Create stop action
        val stopAction =
                NotificationCompat.Action(
                        R.drawable.ic_stop,
                        "Stop",
                        createActionPendingIntent(ACTION_STOP)
                )

        // Create content intent (opens app when notification is clicked)
        val contentIntent = createContentPendingIntent()

        // Create media style
        val mediaStyle =
                MediaStyle()
                        .setMediaSession(mediaSession.sessionToken)
                        .setShowActionsInCompactView(
                                0,
                                1,
                                2
                        ) // Show skip backward, play/pause, and skip forward in compact view

        // Create notification
        val builder =
                NotificationCompat.Builder(this, CHANNEL_ID)
                        .setContentTitle(currentTitle)
                        .setContentText(currentArtist ?: "Now Playing")
                        .setSmallIcon(R.drawable.ic_notification)

        // Use album art if available, otherwise use app icon
        if (albumArt != null) {
            builder.setLargeIcon(albumArt)
        } else {
            // Get the app icon as a drawable
            val appIcon =
                    try {
                        packageManager.getApplicationIcon(packageName)
                    } catch (e: Exception) {
                        null
                    }

            // Convert drawable to bitmap if available
            if (appIcon != null) {
                val bitmap =
                        try {
                            android.graphics.drawable.BitmapDrawable(
                                            resources,
                                            android.graphics.Bitmap.createBitmap(
                                                            appIcon.intrinsicWidth,
                                                            appIcon.intrinsicHeight,
                                                            android.graphics.Bitmap.Config.ARGB_8888
                                                    )
                                                    .apply {
                                                        val canvas = android.graphics.Canvas(this)
                                                        appIcon.setBounds(
                                                                0,
                                                                0,
                                                                canvas.width,
                                                                canvas.height
                                                        )
                                                        appIcon.draw(canvas)
                                                    }
                                    )
                                    .bitmap
                        } catch (e: Exception) {
                            Log.e(TAG, "Error creating bitmap from app icon: ${e.message}")
                            null
                        }

                if (bitmap != null) {
                    builder.setLargeIcon(bitmap)
                }
            }
        }

        // Add remaining notification properties
        builder.setContentIntent(contentIntent)
                .setStyle(mediaStyle)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .addAction(skipBackwardAction)
                .addAction(playPauseAction)
                .addAction(skipForwardAction)
                .addAction(stopAction)
                .setOngoing(true)

        val notification = builder.build()
        Log.d(TAG, "Created notification with title: $currentTitle")
        return notification
    }

    /** Create a PendingIntent for notification actions */
    private fun createActionPendingIntent(action: String): PendingIntent {
        val intent = Intent(this, AudioService::class.java).apply { this.action = action }

        val flags =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }

        return PendingIntent.getService(
                this,
                when (action) {
                    ACTION_PLAY -> 1
                    ACTION_PAUSE -> 2
                    ACTION_STOP -> 3
                    else -> 0
                },
                intent,
                flags
        )
    }

    /** Create a PendingIntent for notification content click */
    private fun createContentPendingIntent(): PendingIntent {
        val packageName = applicationContext.packageName
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)

        val flags =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }

        return PendingIntent.getActivity(this, 0, launchIntent, flags)
    }

    /** Update the playback state */
    private fun updatePlaybackState(state: Int) {
        val stateBuilder =
                PlaybackStateCompat.Builder()
                        .setActions(
                                PlaybackStateCompat.ACTION_PLAY or
                                        PlaybackStateCompat.ACTION_PAUSE or
                                        PlaybackStateCompat.ACTION_STOP
                        )
                        .setState(state, audioPlayer?.getCurrentPosition()?.toLong() ?: 0, 1.0f)

        mediaSession.setPlaybackState(stateBuilder.build())

        // Update notification based on state
        isPlaying = state == PlaybackStateCompat.STATE_PLAYING

        // Send a broadcast intent with the current playback state
        val stateString =
                when (state) {
                    PlaybackStateCompat.STATE_PLAYING -> PlaybackStateReceiver.STATE_PLAYING
                    PlaybackStateCompat.STATE_PAUSED -> PlaybackStateReceiver.STATE_PAUSED
                    PlaybackStateCompat.STATE_STOPPED -> PlaybackStateReceiver.STATE_STOPPED
                    PlaybackStateCompat.STATE_BUFFERING -> PlaybackStateReceiver.STATE_BUFFERING
                    PlaybackStateCompat.STATE_ERROR -> PlaybackStateReceiver.STATE_ERROR
                    else -> PlaybackStateReceiver.STATE_STOPPED
                }

        val intent =
                Intent(PlaybackStateReceiver.ACTION_PLAYBACK_STATE_CHANGED).apply {
                    putExtra(PlaybackStateReceiver.EXTRA_STATE, stateString)
                    putExtra(PlaybackStateReceiver.EXTRA_TITLE, currentTitle)
                    putExtra(
                            PlaybackStateReceiver.EXTRA_POSITION,
                            audioPlayer?.getCurrentPosition() ?: 0
                    )
                    putExtra(PlaybackStateReceiver.EXTRA_DURATION, audioPlayer?.getDuration() ?: 0)
                }
        sendBroadcast(intent)
        Log.d(TAG, "Sent broadcast with state: $stateString")

        // Update notification
        val notification = createNotification()
        notificationManager.notify(NOTIFICATION_ID, notification)
        Log.d(TAG, "Updated notification for state: $state")
    }

    /** Set the audio player instance */
    fun setAudioPlayer(player: AudioPlayer) {
        audioPlayer = player
        Log.d(TAG, "Audio player set in service")

        // Set up a listener for playback state changes
        audioPlayer?.setPlaybackStateListener { state, title, url, position, duration, artist, album
            ->
            // Update the media session and notification
            when (state) {
                PlaybackStateReceiver.STATE_PLAYING -> {
                    isPlaying = true
                    updatePlaybackState(PlaybackStateCompat.STATE_PLAYING)
                }
                PlaybackStateReceiver.STATE_PAUSED -> {
                    isPlaying = false
                    updatePlaybackState(PlaybackStateCompat.STATE_PAUSED)
                }
                PlaybackStateReceiver.STATE_STOPPED -> {
                    isPlaying = false
                    updatePlaybackState(PlaybackStateCompat.STATE_STOPPED)
                }
                PlaybackStateReceiver.STATE_BUFFERING -> {
                    updatePlaybackState(PlaybackStateCompat.STATE_BUFFERING)
                }
                PlaybackStateReceiver.STATE_ERROR -> {
                    updatePlaybackState(PlaybackStateCompat.STATE_ERROR)
                }
            }

            // Update the notification title and metadata
            if (title != null) {
                currentTitle = title
                currentArtist = artist
                currentAlbum = album

                // Try to load album art if available (in a real implementation, you would
                // fetch this from the media metadata or a URL)
                // For now, we'll just use the app icon

                updateNotification(title, isPlaying)
            }

            // Send a broadcast intent with the playback state
            val intent =
                    Intent(PlaybackStateReceiver.ACTION_PLAYBACK_STATE_CHANGED).apply {
                        putExtra(PlaybackStateReceiver.EXTRA_STATE, state)
                        putExtra(PlaybackStateReceiver.EXTRA_TITLE, title)
                        putExtra(PlaybackStateReceiver.EXTRA_URL, url)
                        putExtra(PlaybackStateReceiver.EXTRA_POSITION, position)
                        putExtra(PlaybackStateReceiver.EXTRA_DURATION, duration)
                        putExtra(PlaybackStateReceiver.EXTRA_ARTIST, artist)
                        putExtra(PlaybackStateReceiver.EXTRA_ALBUM, album)
                    }
            sendBroadcast(intent)
        }
    }

    /** Update the notification with new title and playing state */
    fun updateNotification(title: String, playing: Boolean) {
        currentTitle = title
        isPlaying = playing

        // Update metadata
        val metadataBuilder =
                MediaMetadataCompat.Builder()
                        .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
                        .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_TITLE, title)
                        .putString(
                                MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE,
                                currentArtist ?: "Now Playing"
                        )

        // Add artist and album if available
        if (currentArtist != null) {
            metadataBuilder.putString(MediaMetadataCompat.METADATA_KEY_ARTIST, currentArtist)
        }

        if (currentAlbum != null) {
            metadataBuilder.putString(MediaMetadataCompat.METADATA_KEY_ALBUM, currentAlbum)
        }

        // Add album art if available
        if (albumArt != null) {
            metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, albumArt)
        }

        mediaSession.setMetadata(metadataBuilder.build())

        // Update notification
        val notification = createNotification()
        notificationManager.notify(NOTIFICATION_ID, notification)
        Log.d(TAG, "Updated notification with title: $title, playing: $playing")
    }

    // MediaBrowserServiceCompat implementation

    override fun onGetRoot(
            clientPackageName: String,
            clientUid: Int,
            rootHints: Bundle?
    ): BrowserRoot? {
        return BrowserRoot(ROOT_ID, null)
    }

    override fun onLoadChildren(
            parentId: String,
            result: Result<MutableList<MediaBrowserCompat.MediaItem>>
    ) {
        // Return an empty list for now
        result.sendResult(ArrayList())
    }
}
