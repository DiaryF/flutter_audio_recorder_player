package com.example.mymedia

import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Utility class for saving PCM data as WAV files */
object WavRecorder {
    private const val TAG = "WavRecorder"

    /**
     * Saves PCM data as a WAV file
     *
     * @param pcmData Raw PCM audio data
     * @param filePath Path where the WAV file should be saved
     * @param sampleRate Sample rate of the audio (e.g., 44100)
     * @param channels Number of audio channels (1 for mono, 2 for stereo)
     * @param bitDepth Bit depth of the audio (usually 16)
     * @return true if successful, false otherwise
     */
    fun saveAsWav(
            pcmData: ByteArray,
            filePath: String,
            sampleRate: Int,
            channels: Int,
            bitDepth: Int
    ): Boolean {
        try {
            val outputFile = File(filePath)

            // Create parent directories if they don't exist
            outputFile.parentFile?.mkdirs()

            val fos = FileOutputStream(outputFile)

            // Calculate sizes for the WAV header
            val dataSize = pcmData.size

            // Create and write the WAV header
            val header = createWavHeader(dataSize, sampleRate, bitDepth, channels)
            fos.write(header)

            // Write the PCM data
            fos.write(pcmData)
            fos.close()

            Log.d(TAG, "WAV file saved successfully: $filePath")
            return true
        } catch (e: IOException) {
            Log.e(TAG, "Error saving WAV file: ${e.message}")
            return false
        }
    }

    /**
     * Converts a PCM file to a WAV file
     *
     * @param pcmFilePath Path to the PCM file
     * @param wavFilePath Path where the WAV file should be saved
     * @param sampleRate Sample rate of the audio (e.g., 44100)
     * @param channels Number of audio channels (1 for mono, 2 for stereo)
     * @param bitDepth Bit depth of the audio (usually 16)
     * @return true if successful, false otherwise
     */
    fun convertPcmToWav(
            pcmFilePath: String,
            wavFilePath: String,
            sampleRate: Int,
            channels: Int,
            bitDepth: Int
    ): Boolean {
        var pcmInputStream: FileInputStream? = null
        var fos: FileOutputStream? = null

        try {
            Log.d(TAG, "Converting PCM to WAV: $pcmFilePath -> $wavFilePath")
            Log.d(TAG, "Parameters: sampleRate=$sampleRate, channels=$channels, bitDepth=$bitDepth")

            val pcmFile = File(pcmFilePath)
            if (!pcmFile.exists()) {
                Log.e(TAG, "PCM file does not exist: $pcmFilePath")
                return false
            }

            val dataSize = pcmFile.length().toInt()
            if (dataSize <= 0) {
                Log.e(TAG, "PCM file is empty: $pcmFilePath")
                return false
            }

            Log.d(TAG, "PCM file size: $dataSize bytes")

            val outputFile = File(wavFilePath)

            // Create parent directories if they don't exist
            val parentDir = outputFile.parentFile
            if (parentDir != null && !parentDir.exists()) {
                val dirCreated = parentDir.mkdirs()
                if (!dirCreated) {
                    Log.e(TAG, "Failed to create parent directories for: $wavFilePath")
                    return false
                }
            }

            // Check if we can write to the output directory
            if (parentDir != null && !parentDir.canWrite()) {
                Log.e(TAG, "Cannot write to output directory: ${parentDir.absolutePath}")
                return false
            }

            fos = FileOutputStream(outputFile)

            // Create and write the WAV header
            val header = createWavHeader(dataSize, sampleRate, bitDepth, channels)
            fos.write(header)

            // Copy the PCM data
            pcmInputStream = pcmFile.inputStream()
            val buffer = ByteArray(8192)
            var bytesRead: Int
            var totalBytesWritten = 0

            while (pcmInputStream.read(buffer).also { bytesRead = it } != -1) {
                fos.write(buffer, 0, bytesRead)
                totalBytesWritten += bytesRead
            }

            Log.d(TAG, "PCM data copied: $totalBytesWritten bytes")
            Log.d(TAG, "PCM file converted to WAV successfully: $wavFilePath")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error converting PCM to WAV: ${e.message}")
            e.printStackTrace()
            return false
        } finally {
            try {
                pcmInputStream?.close()
            } catch (e: Exception) {
                Log.e(TAG, "Error closing PCM input stream: ${e.message}")
            }

            try {
                fos?.close()
            } catch (e: Exception) {
                Log.e(TAG, "Error closing WAV output stream: ${e.message}")
            }
        }
    }

    /** Creates a WAV header according to the WAV file format specification */
    private fun createWavHeader(
            dataSize: Int,
            sampleRate: Int,
            bitDepth: Int,
            channels: Int
    ): ByteArray {
        val header = ByteArray(44)
        val buffer = ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN)

        // Calculate bytes per sample correctly
        val bytesPerSample =
                when (bitDepth) {
                    8 -> 1
                    16 -> 2
                    24 -> 3
                    32 -> 4
                    else -> bitDepth / 8
                }

        Log.d(
                TAG,
                "Creating WAV header with: sampleRate=$sampleRate, channels=$channels, bitDepth=$bitDepth, bytesPerSample=$bytesPerSample"
        )

        // RIFF chunk descriptor
        buffer.put("RIFF".toByteArray()) // ChunkID (4 bytes)
        buffer.putInt(36 + dataSize) // ChunkSize (4 bytes): 36 + SubChunk2Size
        buffer.put("WAVE".toByteArray()) // Format (4 bytes)

        // "fmt " subchunk
        buffer.put("fmt ".toByteArray()) // Subchunk1ID (4 bytes)
        buffer.putInt(16) // Subchunk1Size (4 bytes): 16 for PCM
        buffer.putShort(1) // AudioFormat (2 bytes): 1 for PCM
        buffer.putShort(channels.toShort()) // NumChannels (2 bytes)
        buffer.putInt(sampleRate) // SampleRate (4 bytes)
        buffer.putInt(sampleRate * channels * bytesPerSample) // ByteRate (4 bytes)
        buffer.putShort((channels * bytesPerSample).toShort()) // BlockAlign (2 bytes)
        buffer.putShort(bitDepth.toShort()) // BitsPerSample (2 bytes)

        // "data" subchunk
        buffer.put("data".toByteArray()) // Subchunk2ID (4 bytes)
        buffer.putInt(dataSize) // Subchunk2Size (4 bytes)

        return header
    }

    /**
     * Converts float PCM data (range -1.0 to 1.0) to 16-bit PCM byte array
     *
     * @param floatPcmData Float array containing PCM data in range -1.0 to 1.0
     * @return Byte array containing 16-bit PCM data
     */
    fun floatToShortPcm(floatPcmData: FloatArray): ByteArray {
        val buffer = ByteBuffer.allocate(floatPcmData.size * 2).order(ByteOrder.LITTLE_ENDIAN)

        for (sample in floatPcmData) {
            // Convert float (-1.0 to 1.0) to short (-32768 to 32767)
            // First convert to Int, then to Short to avoid ambiguity
            val shortSample = (sample * 32767.0f).toInt().toShort()
            buffer.putShort(shortSample)
        }

        return buffer.array()
    }
}
