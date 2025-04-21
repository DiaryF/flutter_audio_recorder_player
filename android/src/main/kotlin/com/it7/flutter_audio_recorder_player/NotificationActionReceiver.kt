package com.it7.flutter_audio_recorder_player

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Receiver for notification actions
 */
class NotificationActionReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "NotificationActionReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.it7.flutter_audio_recorder_player.NOTIFICATION_ACTION") {
            val action = intent.getStringExtra("action")
            if (action != null) {
                Log.d(TAG, "Received notification action: $action")
                
                // Forward action to the plugin
                val plugin = FlutterAudioRecorderPlayerPlugin.instance
                plugin?.getNotificationService()?.sendAction(action)
            }
        }
    }
}
