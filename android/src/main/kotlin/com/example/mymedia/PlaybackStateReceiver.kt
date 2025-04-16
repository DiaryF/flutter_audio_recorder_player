package com.example.mymedia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Broadcast receiver for handling playback state changes */
class PlaybackStateReceiver(private val callback: (String, Map<String, Any>) -> Unit) :
        BroadcastReceiver() {
    companion object {
        private const val TAG = "PlaybackStateReceiver"

        // Action constants
        const val ACTION_PLAYBACK_STATE_CHANGED =
                "com.example.mymedia.ACTION_PLAYBACK_STATE_CHANGED"

        // Extra constants
        const val EXTRA_STATE = "state"
        const val EXTRA_TITLE = "title"
        const val EXTRA_URL = "url"
        const val EXTRA_POSITION = "position"
        const val EXTRA_DURATION = "duration"
        const val EXTRA_ARTIST = "artist"
        const val EXTRA_ALBUM = "album"

        // State constants
        const val STATE_PLAYING = "playing"
        const val STATE_PAUSED = "paused"
        const val STATE_STOPPED = "stopped"
        const val STATE_BUFFERING = "buffering"
        const val STATE_ERROR = "error"
        const val STATE_SKIP_NEXT = "skip_next"
        const val STATE_SKIP_PREVIOUS = "skip_previous"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_PLAYBACK_STATE_CHANGED) {
            val state = intent.getStringExtra(EXTRA_STATE) ?: STATE_STOPPED
            val title = intent.getStringExtra(EXTRA_TITLE) ?: "Unknown"
            val url = intent.getStringExtra(EXTRA_URL) ?: ""
            val position = intent.getLongExtra(EXTRA_POSITION, 0)
            val duration = intent.getLongExtra(EXTRA_DURATION, 0)
            val artist = intent.getStringExtra(EXTRA_ARTIST)
            val album = intent.getStringExtra(EXTRA_ALBUM)

            Log.d(TAG, "Received playback state change: $state, title: $title")

            val data =
                    mutableMapOf(
                            EXTRA_STATE to state,
                            EXTRA_TITLE to title,
                            EXTRA_URL to url,
                            EXTRA_POSITION to position,
                            EXTRA_DURATION to duration
                    )

            // Add optional fields if they exist
            if (artist != null) data[EXTRA_ARTIST] = artist
            if (album != null) data[EXTRA_ALBUM] = album

            callback(ACTION_PLAYBACK_STATE_CHANGED, data)
        }
    }
}
