package com.it7.flutter_audio_recorder_player

import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * Handles WAV file operations including parsing, visualization data extraction,
 * trimming, and joining.
 */
class WavFileHandler {
    companion object {
        private const val TAG = "WavFileHandler"
        
        // WAV header constants
        private const val RIFF_HEADER = "RIFF"
        private const val WAVE_HEADER = "WAVE"
        private const val FMT_HEADER = "fmt "
        private const val DATA_HEADER = "data"
        
        // Default values for WAV format
        private const val DEFAULT_SAMPLE_RATE = 44100
        private const val DEFAULT_CHANNELS = 2
        private const val DEFAULT_BITS_PER_SAMPLE = 16
    }
    
    /**
     * Represents a WAV file header
     */
    data class WavHeader(
        val sampleRate: Int,
        val channels: Int,
        val bitsPerSample: Int,
        val dataSize: Int,
        val audioFormat: Int,
        val headerSize: Int
    ) {
        val bytesPerSample: Int = bitsPerSample / 8
        val bytesPerFrame: Int = bytesPerSample * channels
        val frameCount: Int = dataSize / bytesPerFrame
        val durationMs: Int = (frameCount * 1000L / sampleRate).toInt()
    }
    
    /**
     * Parses a WAV file and returns its header information
     */
    fun parseWavHeader(filePath: String): WavHeader? {
        try {
            val file = File(filePath)
            if (!file.exists()) {
                Log.e(TAG, "File does not exist: $filePath")
                return null
            }
            
            FileInputStream(file).use { fis ->
                val buffer = ByteBuffer.allocate(44) // Standard WAV header size
                buffer.order(ByteOrder.LITTLE_ENDIAN)
                
                val bytesRead = fis.channel.read(buffer)
                if (bytesRead < 44) {
                    Log.e(TAG, "File too small to be a valid WAV file")
                    return null
                }
                
                buffer.flip()
                
                // Read RIFF header
                val riffHeader = String(buffer.array(), 0, 4)
                if (riffHeader != RIFF_HEADER) {
                    Log.e(TAG, "Not a valid RIFF file")
                    return null
                }
                
                // Skip file size
                buffer.position(8)
                
                // Read WAVE header
                val waveHeader = String(buffer.array(), 8, 4)
                if (waveHeader != WAVE_HEADER) {
                    Log.e(TAG, "Not a valid WAVE file")
                    return null
                }
                
                // Read FMT header
                val fmtHeader = String(buffer.array(), 12, 4)
                if (fmtHeader != FMT_HEADER) {
                    Log.e(TAG, "Format chunk not found")
                    return null
                }
                
                // Skip to format data
                buffer.position(20)
                
                // Read format data
                val audioFormat = buffer.short.toInt() and 0xFFFF
                val channels = buffer.short.toInt() and 0xFFFF
                val sampleRate = buffer.int
                buffer.position(34)
                val bitsPerSample = buffer.short.toInt() and 0xFFFF
                
                // Find data chunk
                var dataSize = 0
                var headerSize = 44
                
                // If this is a standard 44-byte header, read the data size directly
                val dataHeader = String(buffer.array(), 36, 4)
                if (dataHeader == DATA_HEADER) {
                    buffer.position(40)
                    dataSize = buffer.int
                } else {
                    // Otherwise, we need to search for the data chunk
                    headerSize = findDataChunk(file, dataSize)
                    if (headerSize <= 0) {
                        Log.e(TAG, "Data chunk not found")
                        return null
                    }
                }
                
                return WavHeader(
                    sampleRate = sampleRate,
                    channels = channels,
                    bitsPerSample = bitsPerSample,
                    dataSize = dataSize,
                    audioFormat = audioFormat,
                    headerSize = headerSize
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing WAV header: ${e.message}")
            e.printStackTrace()
            return null
        }
    }
    
    /**
     * Finds the data chunk in a WAV file and returns the header size
     */
    private fun findDataChunk(file: File, dataSize: Int): Int {
        var headerSize = 12 // RIFF header size
        var foundData = false
        
        try {
            FileInputStream(file).use { fis ->
                val channel = fis.channel
                val buffer = ByteBuffer.allocate(8)
                buffer.order(ByteOrder.LITTLE_ENDIAN)
                
                // Skip RIFF header
                channel.position(12)
                
                while (channel.position() < file.length()) {
                    buffer.clear()
                    channel.read(buffer)
                    buffer.flip()
                    
                    val chunkId = String(buffer.array(), 0, 4)
                    val chunkSize = buffer.getInt(4)
                    
                    headerSize += 8 + chunkSize
                    
                    if (chunkId == DATA_HEADER) {
                        foundData = true
                        return headerSize - chunkSize
                    }
                    
                    // Move to next chunk
                    channel.position(headerSize)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error finding data chunk: ${e.message}")
            e.printStackTrace()
        }
        
        return if (foundData) headerSize else -1
    }
    
    /**
     * Generates waveform data from a WAV file
     * 
     * @param filePath Path to the WAV file
     * @param samplesCount Number of samples to generate
     * @return ByteArray containing the waveform data (values from 0-255)
     */
    fun generateWaveformData(filePath: String, samplesCount: Int): ByteArray? {
        try {
            val header = parseWavHeader(filePath) ?: return null
            val file = File(filePath)
            
            if (header.frameCount <= 0) {
                Log.e(TAG, "Invalid frame count in WAV file")
                return null
            }
            
            // Calculate how many frames to skip between samples
            val framesPerSample = max(1, header.frameCount / samplesCount)
            val actualSamples = min(samplesCount, header.frameCount)
            
            val result = ByteArray(actualSamples)
            
            FileInputStream(file).use { fis ->
                val channel = fis.channel
                
                // Skip header
                channel.position(header.headerSize.toLong())
                
                val sampleBuffer = ByteBuffer.allocate(header.bytesPerFrame)
                sampleBuffer.order(ByteOrder.LITTLE_ENDIAN)
                
                for (i in 0 until actualSamples) {
                    // Position the channel at the right frame
                    val framePosition = header.headerSize + (i * framesPerSample * header.bytesPerFrame)
                    if (framePosition >= file.length()) {
                        break
                    }
                    
                    channel.position(framePosition.toLong())
                    
                    // Read one frame
                    sampleBuffer.clear()
                    channel.read(sampleBuffer)
                    sampleBuffer.flip()
                    
                    // Calculate the peak amplitude in this frame
                    var peakAmplitude = 0
                    
                    for (ch in 0 until header.channels) {
                        val sampleOffset = ch * header.bytesPerSample
                        
                        val amplitude = when (header.bitsPerSample) {
                            8 -> {
                                val sample = sampleBuffer.get(sampleOffset).toInt() and 0xFF
                                abs(sample - 128) * 2 // Convert 0-255 to -128-127 and get absolute
                            }
                            16 -> {
                                val sample = sampleBuffer.getShort(sampleOffset).toInt()
                                abs(sample) / 256 // Scale down to 0-255
                            }
                            24 -> {
                                val b1 = sampleBuffer.get(sampleOffset).toInt() and 0xFF
                                val b2 = sampleBuffer.get(sampleOffset + 1).toInt() and 0xFF
                                val b3 = sampleBuffer.get(sampleOffset + 2).toInt() and 0xFF
                                val sample = (b3 shl 16) or (b2 shl 8) or b1
                                abs(sample) / 65536 // Scale down to 0-255
                            }
                            32 -> {
                                val sample = sampleBuffer.getInt(sampleOffset)
                                abs(sample) / 16777216 // Scale down to 0-255
                            }
                            else -> 0
                        }
                        
                        peakAmplitude = max(peakAmplitude, amplitude)
                    }
                    
                    // Ensure the amplitude is within 0-255
                    result[i] = min(255, peakAmplitude).toByte()
                }
            }
            
            return result
        } catch (e: Exception) {
            Log.e(TAG, "Error generating waveform data: ${e.message}")
            e.printStackTrace()
            return null
        }
    }
    
    /**
     * Trims a WAV file to the specified start and end times
     * 
     * @param inputPath Path to the input WAV file
     * @param outputPath Path to save the trimmed WAV file
     * @param startMs Start time in milliseconds
     * @param endMs End time in milliseconds
     * @return True if successful, false otherwise
     */
    fun trimWavFile(inputPath: String, outputPath: String, startMs: Int, endMs: Int): Boolean {
        try {
            val header = parseWavHeader(inputPath) ?: return false
            val inputFile = File(inputPath)
            val outputFile = File(outputPath)
            
            // Calculate frame positions
            val startFrame = (startMs * header.sampleRate / 1000).toLong()
            val endFrame = (endMs * header.sampleRate / 1000).toLong()
            
            if (startFrame >= endFrame || startFrame < 0 || endFrame > header.frameCount) {
                Log.e(TAG, "Invalid trim parameters: start=$startFrame, end=$endFrame, total=${header.frameCount}")
                return false
            }
            
            val framesToCopy = endFrame - startFrame
            val bytesToCopy = framesToCopy * header.bytesPerFrame
            
            FileInputStream(inputFile).use { fis ->
                FileOutputStream(outputFile).use { fos ->
                    val inputChannel = fis.channel
                    val outputChannel = fos.channel
                    
                    // Copy the header
                    val headerBuffer = ByteBuffer.allocate(header.headerSize)
                    inputChannel.position(0)
                    inputChannel.read(headerBuffer)
                    headerBuffer.flip()
                    outputChannel.write(headerBuffer)
                    
                    // Update the data size in the header
                    outputChannel.position(40) // Position of data size in header
                    val dataSizeBuffer = ByteBuffer.allocate(4)
                    dataSizeBuffer.order(ByteOrder.LITTLE_ENDIAN)
                    dataSizeBuffer.putInt(bytesToCopy.toInt())
                    dataSizeBuffer.flip()
                    outputChannel.write(dataSizeBuffer)
                    
                    // Update the file size in the header
                    outputChannel.position(4) // Position of file size in header
                    val fileSizeBuffer = ByteBuffer.allocate(4)
                    fileSizeBuffer.order(ByteOrder.LITTLE_ENDIAN)
                    fileSizeBuffer.putInt(bytesToCopy.toInt() + header.headerSize - 8)
                    fileSizeBuffer.flip()
                    outputChannel.write(fileSizeBuffer)
                    
                    // Copy the audio data
                    val startPosition = header.headerSize + startFrame * header.bytesPerFrame
                    inputChannel.position(startPosition)
                    outputChannel.position(header.headerSize.toLong())
                    
                    // Use a buffer for efficient copying
                    val bufferSize = min(1024 * 1024, bytesToCopy.toInt()) // 1MB buffer or smaller
                    val buffer = ByteBuffer.allocate(bufferSize)
                    
                    var bytesRemaining = bytesToCopy
                    while (bytesRemaining > 0) {
                        val bytesToRead = min(bufferSize.toLong(), bytesRemaining)
                        buffer.clear()
                        buffer.limit(bytesToRead.toInt())
                        
                        val bytesRead = inputChannel.read(buffer)
                        if (bytesRead <= 0) break
                        
                        buffer.flip()
                        outputChannel.write(buffer)
                        
                        bytesRemaining -= bytesRead
                    }
                }
            }
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error trimming WAV file: ${e.message}")
            e.printStackTrace()
            return false
        }
    }
    
    /**
     * Joins multiple WAV files into a single file
     * 
     * @param inputPaths List of paths to the input WAV files
     * @param outputPath Path to save the joined WAV file
     * @return True if successful, false otherwise
     */
    fun joinWavFiles(inputPaths: List<String>, outputPath: String): Boolean {
        if (inputPaths.isEmpty()) {
            Log.e(TAG, "No input files provided")
            return false
        }
        
        try {
            // Parse the first file to get the format
            val firstHeader = parseWavHeader(inputPaths[0]) ?: return false
            
            // Check that all files have the same format
            for (i in 1 until inputPaths.size) {
                val header = parseWavHeader(inputPaths[i]) ?: return false
                
                if (header.sampleRate != firstHeader.sampleRate ||
                    header.channels != firstHeader.channels ||
                    header.bitsPerSample != firstHeader.bitsPerSample) {
                    Log.e(TAG, "All files must have the same audio format")
                    return false
                }
            }
            
            // Calculate total data size
            var totalDataSize = 0
            val headers = mutableListOf<WavHeader>()
            
            for (path in inputPaths) {
                val header = parseWavHeader(path) ?: return false
                headers.add(header)
                totalDataSize += header.dataSize
            }
            
            val outputFile = File(outputPath)
            
            FileOutputStream(outputFile).use { fos ->
                val outputChannel = fos.channel
                
                // Write the WAV header
                writeWavHeader(outputChannel, firstHeader.sampleRate, firstHeader.channels, 
                               firstHeader.bitsPerSample, totalDataSize)
                
                // Copy data from each file
                for (i in inputPaths.indices) {
                    val inputFile = File(inputPaths[i])
                    val header = headers[i]
                    
                    FileInputStream(inputFile).use { fis ->
                        val inputChannel = fis.channel
                        
                        // Skip the header
                        inputChannel.position(header.headerSize.toLong())
                        
                        // Copy the data
                        val bufferSize = min(1024 * 1024, header.dataSize) // 1MB buffer or smaller
                        val buffer = ByteBuffer.allocate(bufferSize)
                        
                        var bytesRemaining = header.dataSize.toLong()
                        while (bytesRemaining > 0) {
                            val bytesToRead = min(bufferSize.toLong(), bytesRemaining)
                            buffer.clear()
                            buffer.limit(bytesToRead.toInt())
                            
                            val bytesRead = inputChannel.read(buffer)
                            if (bytesRead <= 0) break
                            
                            buffer.flip()
                            outputChannel.write(buffer)
                            
                            bytesRemaining -= bytesRead
                        }
                    }
                }
            }
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error joining WAV files: ${e.message}")
            e.printStackTrace()
            return false
        }
    }
    
    /**
     * Writes a WAV header to the output channel
     */
    private fun writeWavHeader(
        channel: FileChannel,
        sampleRate: Int,
        channels: Int,
        bitsPerSample: Int,
        dataSize: Int
    ) {
        val headerSize = 44
        val byteRate = sampleRate * channels * bitsPerSample / 8
        val blockAlign = channels * bitsPerSample / 8
        
        val buffer = ByteBuffer.allocate(headerSize)
        buffer.order(ByteOrder.LITTLE_ENDIAN)
        
        // RIFF header
        buffer.put(RIFF_HEADER.toByteArray())
        buffer.putInt(dataSize + headerSize - 8) // File size - 8
        buffer.put(WAVE_HEADER.toByteArray())
        
        // FMT chunk
        buffer.put(FMT_HEADER.toByteArray())
        buffer.putInt(16) // Size of fmt chunk
        buffer.putShort(1) // Audio format (1 = PCM)
        buffer.putShort(channels.toShort())
        buffer.putInt(sampleRate)
        buffer.putInt(byteRate)
        buffer.putShort(blockAlign.toShort())
        buffer.putShort(bitsPerSample.toShort())
        
        // Data chunk
        buffer.put(DATA_HEADER.toByteArray())
        buffer.putInt(dataSize)
        
        buffer.flip()
        channel.write(buffer)
    }
}
