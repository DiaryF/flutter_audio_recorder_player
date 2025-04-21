package com.it7.flutter_audio_recorder_player

import android.content.Context
import android.util.Log
import java.io.File
import java.io.FileWriter
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.*
import org.json.JSONArray
import org.json.JSONObject

/** Class to handle recording metadata */
class RecordingMetadata(private val context: Context) {
  private val TAG = "RecordingMetadata"
  private val METADATA_FILENAME = "recording_metadata.json"
  private val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)

  /** Data class to represent a recording's metadata */
  data class Recording(
          val id: String,
          val filePath: String,
          val title: String,
          val dateCreated: Date,
          val duration: Long,
          val sampleRate: Int,
          val channels: Int,
          val bitDepth: Int,
          val fileSize: Long
  )

  /**
   * Adds metadata for a new recording
   *
   * @param filePath Path to the recording file
   * @param title Title of the recording (optional)
   * @param sampleRate Sample rate of the recording
   * @param channels Number of channels in the recording
   * @param bitDepth Bit depth of the recording
   * @param duration Duration of the recording in milliseconds
   * @return The ID of the new recording, or null if there was an error
   */
  fun addRecording(
          filePath: String,
          title: String? = null,
          sampleRate: Int,
          channels: Int,
          bitDepth: Int,
          duration: Long
  ): String? {
    return addRecording(
            null,
            filePath,
            title,
            sampleRate,
            channels,
            bitDepth,
            duration,
            System.currentTimeMillis()
    )
  }

  /**
   * Adds metadata for a new recording with a specific ID and timestamp
   *
   * @param id Custom ID for the recording (if null, a UUID will be generated)
   * @param filePath Path to the recording file
   * @param title Title of the recording (optional)
   * @param sampleRate Sample rate of the recording
   * @param channels Number of channels in the recording
   * @param bitDepth Bit depth of the recording
   * @param duration Duration of the recording in milliseconds
   * @param timestamp Timestamp when the recording was created
   * @return The ID of the new recording, or null if there was an error
   */
  fun addRecording(
          id: String?,
          filePath: String,
          title: String? = null,
          sampleRate: Int = 44100,
          channels: Int = 2,
          bitDepth: Int = 16,
          duration: Long = 0,
          timestamp: Long = System.currentTimeMillis()
  ): String? {
    try {
      val file = File(filePath)
      if (!file.exists()) {
        Log.e(TAG, "Recording file does not exist: $filePath")
        return null
      }

      // Generate a unique ID for the recording
      val id = UUID.randomUUID().toString()

      // Use the filename as the title if none was provided
      val recordingTitle = title ?: file.name

      // Create the recording metadata
      val recording =
              Recording(
                      id = id,
                      filePath = filePath,
                      title = recordingTitle,
                      dateCreated = Date(),
                      duration = duration,
                      sampleRate = sampleRate,
                      channels = channels,
                      bitDepth = bitDepth,
                      fileSize = file.length()
              )

      // Add the recording to the metadata file
      val recordings = getRecordings().toMutableList()
      recordings.add(recording)
      saveRecordings(recordings)

      return id
    } catch (e: Exception) {
      Log.e(TAG, "Error adding recording metadata: ${e.message}")
      return null
    }
  }

  /**
   * Gets all recordings
   *
   * @return List of all recordings
   */
  fun getRecordings(): List<Recording> {
    try {
      val metadataFile = getMetadataFile()
      if (!metadataFile.exists()) {
        return emptyList()
      }

      val jsonString = metadataFile.readText()
      val jsonArray = JSONArray(jsonString)
      val recordings = mutableListOf<Recording>()

      for (i in 0 until jsonArray.length()) {
        val jsonObject = jsonArray.getJSONObject(i)
        val recording = parseRecordingFromJson(jsonObject)
        recordings.add(recording)
      }

      return recordings
    } catch (e: Exception) {
      Log.e(TAG, "Error getting recordings: ${e.message}")
      return emptyList()
    }
  }

  /**
   * Gets a recording by ID
   *
   * @param id ID of the recording to get
   * @return The recording, or null if not found
   */
  fun getRecording(id: String): Recording? {
    return getRecordings().find { it.id == id }
  }

  /**
   * Updates a recording's metadata
   *
   * @param id ID of the recording to update
   * @param title New title for the recording (optional)
   * @return true if the recording was updated, false otherwise
   */
  fun updateRecording(id: String, title: String? = null): Boolean {
    try {
      val recordings = getRecordings().toMutableList()
      val index = recordings.indexOfFirst { it.id == id }

      if (index == -1) {
        Log.e(TAG, "Recording not found: $id")
        return false
      }

      val recording = recordings[index]

      // Only update the title if it was provided
      if (title != null) {
        recordings[index] = recording.copy(title = title)
      }

      saveRecordings(recordings)
      return true
    } catch (e: Exception) {
      Log.e(TAG, "Error updating recording: ${e.message}")
      return false
    }
  }

  /**
   * Deletes a recording's metadata
   *
   * @param id ID of the recording to delete
   * @return true if the recording was deleted, false otherwise
   */
  fun deleteRecording(id: String): Boolean {
    try {
      val recordings = getRecordings().toMutableList()
      val initialSize = recordings.size

      recordings.removeIf { it.id == id }

      if (recordings.size == initialSize) {
        Log.e(TAG, "Recording not found: $id")
        return false
      }

      saveRecordings(recordings)
      return true
    } catch (e: Exception) {
      Log.e(TAG, "Error deleting recording: ${e.message}")
      return false
    }
  }

  /**
   * Gets all recordings as a JSON array
   *
   * @return JSON array of all recordings
   */
  fun getRecordingsAsJson(): JSONArray {
    val recordings = getRecordings()
    val jsonArray = JSONArray()

    for (recording in recordings) {
      jsonArray.put(recordingToJson(recording))
    }

    return jsonArray
  }

  /**
   * Saves recordings to the metadata file
   *
   * @param recordings List of recordings to save
   */
  private fun saveRecordings(recordings: List<Recording>) {
    try {
      val metadataFile = getMetadataFile()
      val jsonArray = JSONArray()

      for (recording in recordings) {
        jsonArray.put(recordingToJson(recording))
      }

      FileWriter(metadataFile).use { writer -> writer.write(jsonArray.toString(2)) }
    } catch (e: IOException) {
      Log.e(TAG, "Error saving recordings: ${e.message}")
    }
  }

  /**
   * Converts a recording to a JSON object
   *
   * @param recording Recording to convert
   * @return JSON object representing the recording
   */
  private fun recordingToJson(recording: Recording): JSONObject {
    val jsonObject = JSONObject()
    jsonObject.put("id", recording.id)
    jsonObject.put("filePath", recording.filePath)
    jsonObject.put("title", recording.title)
    jsonObject.put("dateCreated", dateFormat.format(recording.dateCreated))
    jsonObject.put("duration", recording.duration)
    jsonObject.put("sampleRate", recording.sampleRate)
    jsonObject.put("channels", recording.channels)
    jsonObject.put("bitDepth", recording.bitDepth)
    jsonObject.put("fileSize", recording.fileSize)
    return jsonObject
  }

  /**
   * Parses a recording from a JSON object
   *
   * @param jsonObject JSON object to parse
   * @return Recording parsed from the JSON object
   */
  private fun parseRecordingFromJson(jsonObject: JSONObject): Recording {
    val id = jsonObject.getString("id")
    val filePath = jsonObject.getString("filePath")
    val title = jsonObject.getString("title")
    val dateCreatedStr = jsonObject.getString("dateCreated")
    val dateCreated = dateFormat.parse(dateCreatedStr) ?: Date()
    val duration = jsonObject.getLong("duration")
    val sampleRate = jsonObject.getInt("sampleRate")
    val channels = jsonObject.getInt("channels")
    val bitDepth = jsonObject.getInt("bitDepth")
    val fileSize = jsonObject.getLong("fileSize")

    return Recording(
            id = id,
            filePath = filePath,
            title = title,
            dateCreated = dateCreated,
            duration = duration,
            sampleRate = sampleRate,
            channels = channels,
            bitDepth = bitDepth,
            fileSize = fileSize
    )
  }

  /**
   * Gets the metadata file
   *
   * @return File object for the metadata file
   */
  private fun getMetadataFile(): File {
    val filesDir = context.filesDir
    return File(filesDir, METADATA_FILENAME)
  }
}
