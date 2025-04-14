package com.example.mymedia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Broadcast receiver for handling playback state changes
 */
class PlaybackStateReceiver(private val callback: (String, Map<String, Any>) -> Unit) : BroadcastReceiver() {
    companion object {
        private const val TAG = "PlaybackStateReceiver"
        
        // Action constants
        const val ACTION_PLAYBACK_STATE_CHANGED = "com.example.mymedia.ACTION_PLAYBACK_STATE_CHANGED"
        
        // Extra constants
        const val EXTRA_STATE = "state"
        const val EXTRA_TITLE = "title"
        const val EXTRA_URL = "url"
        const val EXTRA_POSITION = "position"
        const val EXTRA_DURATION = "duration"
        
        // State constants
        const val STATE_PLAYING = "playing"
        const val STATE_PAUSED = "paused"
        const val STATE_STOPPED = "stopped"
        const val STATE_BUFFERING = "buffering"
        const val STATE_ERROR = "error"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_PLAYBACK_STATE_CHANGED) {
            val state = intent.getStringExtra(EXTRA_STATE) ?: STATE_STOPPED
            val title = intent.getStringExtra(EXTRA_TITLE) ?: "Unknown"
            val url = intent.getStringExtra(EXTRA_URL) ?: ""
            val position = intent.getLongExtra(EXTRA_POSITION, 0)
            val duration = intent.getLongExtra(EXTRA_DURATION, 0)
            
            Log.d(TAG, "Received playback state change: $state, title: $title")
            
            val data = mapOf(
                EXTRA_STATE to state,
                EXTRA_TITLE to title,
                EXTRA_URL to url,
                EXTRA_POSITION to position,
                EXTRA_DURATION to duration
            )
            
            callback(ACTION_PLAYBACK_STATE_CHANGED, data)
        }
    }
}
