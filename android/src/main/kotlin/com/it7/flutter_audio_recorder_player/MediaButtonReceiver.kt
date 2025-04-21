package com.it7.flutter_audio_recorder_player

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.KeyEvent

/** Receiver for media button events */
class MediaButtonReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "MediaButtonReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received media button event: ${intent.action}")

        if (Intent.ACTION_MEDIA_BUTTON == intent.action) {
            val event = intent.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT)

            if (event != null && event.action == KeyEvent.ACTION_DOWN) {
                when (event.keyCode) {
                    KeyEvent.KEYCODE_MEDIA_PLAY -> {
                        // Forward to service
                        val serviceIntent = Intent(context, AudioService::class.java)
                        serviceIntent.action = AudioService.ACTION_PLAY
                        context.startService(serviceIntent)
                    }
                    KeyEvent.KEYCODE_MEDIA_PAUSE -> {
                        // Forward to service
                        val serviceIntent = Intent(context, AudioService::class.java)
                        serviceIntent.action = AudioService.ACTION_PAUSE
                        context.startService(serviceIntent)
                    }
                    KeyEvent.KEYCODE_MEDIA_STOP -> {
                        // Forward to service
                        val serviceIntent = Intent(context, AudioService::class.java)
                        serviceIntent.action = AudioService.ACTION_STOP
                        context.startService(serviceIntent)
                    }
                }
            }
        }
    }
}
