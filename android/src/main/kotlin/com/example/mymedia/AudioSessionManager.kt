package com.example.mymedia

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.util.Log

/**
 * Manages audio focus and audio attributes for the app.
 */
class AudioSessionManager(private val context: Context) {
    private val TAG = "AudioSessionManager"
    
    // Audio manager
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    
    // Audio focus request (for Android O and above)
    private var audioFocusRequest: AudioFocusRequest? = null
    
    // Audio focus change listener
    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_GAIN -> {
                Log.d(TAG, "Audio focus gained")
                // Notify the plugin that audio focus was gained
                MymediaPlugin.instance?.onAudioFocusGained()
            }
            AudioManager.AUDIOFOCUS_LOSS -> {
                Log.d(TAG, "Audio focus lost")
                // Notify the plugin that audio focus was lost
                MymediaPlugin.instance?.onAudioFocusLost()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                Log.d(TAG, "Audio focus lost temporarily")
                // Notify the plugin that audio focus was lost temporarily
                MymediaPlugin.instance?.onAudioFocusLostTransient()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                Log.d(TAG, "Audio focus lost temporarily, can duck")
                // Notify the plugin that audio focus was lost temporarily and can duck
                MymediaPlugin.instance?.onAudioFocusLostTransientCanDuck()
            }
        }
    }
    
    /**
     * Configures the audio session with the given parameters.
     *
     * @param contentType The type of audio content (music, speech, etc.)
     * @param focusGainType The type of audio focus to request
     * @param pauseWhenDucked Whether to pause when ducked
     */
    fun configure(contentType: Int, focusGainType: Int, pauseWhenDucked: Boolean) {
        Log.d(TAG, "Configuring audio session: contentType=$contentType, focusGainType=$focusGainType, pauseWhenDucked=$pauseWhenDucked")
        
        // Store the configuration
        this.pauseWhenDucked = pauseWhenDucked
        this.focusGainType = focusGainType
        
        // Create audio attributes
        val audioAttributes = createAudioAttributes(contentType)
        
        // Store the audio attributes for later use
        this.audioAttributes = audioAttributes
    }
    
    /**
     * Creates audio attributes based on the content type.
     */
    private fun createAudioAttributes(contentType: Int): AudioAttributes {
        val usage = when (contentType) {
            CONTENT_TYPE_MUSIC -> AudioAttributes.USAGE_MEDIA
            CONTENT_TYPE_SPEECH -> AudioAttributes.USAGE_MEDIA
            CONTENT_TYPE_MOVIE -> AudioAttributes.USAGE_MEDIA
            CONTENT_TYPE_SONIFICATION -> AudioAttributes.USAGE_NOTIFICATION
            CONTENT_TYPE_GAME -> AudioAttributes.USAGE_GAME
            CONTENT_TYPE_VOICE_CALL -> AudioAttributes.USAGE_VOICE_COMMUNICATION
            else -> AudioAttributes.USAGE_MEDIA
        }
        
        val contentTypeAttr = when (contentType) {
            CONTENT_TYPE_MUSIC -> AudioAttributes.CONTENT_TYPE_MUSIC
            CONTENT_TYPE_SPEECH -> AudioAttributes.CONTENT_TYPE_SPEECH
            CONTENT_TYPE_MOVIE -> AudioAttributes.CONTENT_TYPE_MOVIE
            CONTENT_TYPE_SONIFICATION -> AudioAttributes.CONTENT_TYPE_SONIFICATION
            CONTENT_TYPE_GAME -> AudioAttributes.CONTENT_TYPE_SONIFICATION
            CONTENT_TYPE_VOICE_CALL -> AudioAttributes.CONTENT_TYPE_SPEECH
            else -> AudioAttributes.CONTENT_TYPE_MUSIC
        }
        
        return AudioAttributes.Builder()
            .setUsage(usage)
            .setContentType(contentTypeAttr)
            .build()
    }
    
    /**
     * Requests audio focus.
     *
     * @return true if audio focus was granted, false otherwise
     */
    fun requestAudioFocus(): Boolean {
        Log.d(TAG, "Requesting audio focus")
        
        // If we don't want audio focus, return true
        if (focusGainType == FOCUS_GAIN_NONE) {
            return true
        }
        
        // Convert our focus gain type to Android's
        val focusGain = when (focusGainType) {
            FOCUS_GAIN_TRANSIENT -> AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
            FOCUS_GAIN_TRANSIENT_MAY_DUCK -> AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            FOCUS_GAIN_TRANSIENT_EXCLUSIVE -> AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE
            else -> AudioManager.AUDIOFOCUS_GAIN
        }
        
        // Request audio focus
        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // For Android O and above, use the new API
            val focusRequest = AudioFocusRequest.Builder(focusGain)
                .setAudioAttributes(audioAttributes!!)
                .setOnAudioFocusChangeListener(audioFocusChangeListener)
                .build()
            
            // Store the request for later
            audioFocusRequest = focusRequest
            
            // Request focus
            audioManager.requestAudioFocus(focusRequest)
        } else {
            // For older versions, use the deprecated API
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                audioFocusChangeListener,
                AudioManager.STREAM_MUSIC,
                focusGain
            )
        }
        
        // Check the result
        return result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }
    
    /**
     * Abandons audio focus.
     */
    fun abandonAudioFocus() {
        Log.d(TAG, "Abandoning audio focus")
        
        // If we don't have audio focus, do nothing
        if (focusGainType == FOCUS_GAIN_NONE) {
            return
        }
        
        // Abandon audio focus
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // For Android O and above, use the new API
            val focusRequest = audioFocusRequest
            if (focusRequest != null) {
                audioManager.abandonAudioFocusRequest(focusRequest)
            }
        } else {
            // For older versions, use the deprecated API
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(audioFocusChangeListener)
        }
    }
    
    companion object {
        // Content types
        const val CONTENT_TYPE_MUSIC = 0
        const val CONTENT_TYPE_SPEECH = 1
        const val CONTENT_TYPE_MOVIE = 2
        const val CONTENT_TYPE_SONIFICATION = 3
        const val CONTENT_TYPE_GAME = 4
        const val CONTENT_TYPE_VOICE_CALL = 5
        
        // Focus gain types
        const val FOCUS_GAIN = 0
        const val FOCUS_GAIN_TRANSIENT = 1
        const val FOCUS_GAIN_TRANSIENT_MAY_DUCK = 2
        const val FOCUS_GAIN_TRANSIENT_EXCLUSIVE = 3
        const val FOCUS_GAIN_NONE = 4
    }
    
    // Configuration
    private var pauseWhenDucked = false
    private var focusGainType = FOCUS_GAIN
    private var audioAttributes: AudioAttributes? = null
    
    /**
     * Returns whether to pause when ducked.
     */
    fun shouldPauseWhenDucked(): Boolean {
        return pauseWhenDucked
    }
}
