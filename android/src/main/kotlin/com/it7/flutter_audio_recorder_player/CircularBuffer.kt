package com.example.mymedia

import android.util.Log
import java.nio.ByteBuffer
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * A fixed-size circular buffer for audio data. This class provides thread-safe read and write
 * operations.
 */
class CircularBuffer(private val capacity: Int) {
    private val buffer = ByteArray(capacity)
    private var readPosition = 0
    private var writePosition = 0
    private var available = 0
    private val lock = ReentrantLock()

    companion object {
        private const val TAG = "CircularBuffer"
    }

    /**
     * Writes data to the buffer.
     * @param data The data to write
     * @param offset The offset in the data array
     * @param length The number of bytes to write
     * @return The number of bytes actually written
     */
    fun write(data: ByteArray, offset: Int, length: Int): Int {
        if (length <= 0) return 0

        return lock.withLock {
            if (available == capacity) {
                // Buffer is full, can't write
                return@withLock 0
            }

            val bytesToWrite = minOf(length, capacity - available)

            // Write in two parts if necessary (wrap around)
            val firstPart = minOf(bytesToWrite, capacity - writePosition)
            System.arraycopy(data, offset, buffer, writePosition, firstPart)

            if (firstPart < bytesToWrite) {
                // Wrap around
                val secondPart = bytesToWrite - firstPart
                System.arraycopy(data, offset + firstPart, buffer, 0, secondPart)
                writePosition = secondPart
            } else {
                writePosition = (writePosition + firstPart) % capacity
            }

            available += bytesToWrite
            bytesToWrite
        }
    }

    /**
     * Reads data from the buffer.
     * @param data The array to read into
     * @param offset The offset in the data array
     * @param length The maximum number of bytes to read
     * @return The number of bytes actually read
     */
    fun read(data: ByteArray, offset: Int, length: Int): Int {
        if (length <= 0) return 0

        return lock.withLock {
            if (available == 0) {
                // Buffer is empty, can't read
                return@withLock 0
            }

            val bytesToRead = minOf(length, available)

            // Read in two parts if necessary (wrap around)
            val firstPart = minOf(bytesToRead, capacity - readPosition)
            System.arraycopy(buffer, readPosition, data, offset, firstPart)

            if (firstPart < bytesToRead) {
                // Wrap around
                val secondPart = bytesToRead - firstPart
                System.arraycopy(buffer, 0, data, offset + firstPart, secondPart)
                readPosition = secondPart
            } else {
                readPosition = (readPosition + firstPart) % capacity
            }

            available -= bytesToRead
            bytesToRead
        }
    }

    /**
     * Reads data from the buffer into a ByteBuffer.
     * @param buffer The ByteBuffer to read into
     * @param length The maximum number of bytes to read
     * @return The number of bytes actually read
     */
    fun read(buffer: ByteBuffer, length: Int): Int {
        val tempBuffer = ByteArray(length)
        val bytesRead = read(tempBuffer, 0, length)
        if (bytesRead > 0) {
            buffer.put(tempBuffer, 0, bytesRead)
        }
        return bytesRead
    }

    /**
     * Writes data from a ByteBuffer to the circular buffer.
     * @param buffer The ByteBuffer to write from
     * @param length The number of bytes to write
     * @return The number of bytes actually written
     */
    fun write(buffer: ByteBuffer, length: Int): Int {
        // Save the original position
        val originalPosition = buffer.position()

        // Create a temporary buffer to hold the data
        val tempBuffer = ByteArray(length)

        // Make sure we don't try to read more than what's available
        val bytesToRead = Math.min(length, buffer.remaining())
        if (bytesToRead <= 0) {
            return 0
        }

        try {
            // Read the data into the temp buffer
            buffer.get(tempBuffer, 0, bytesToRead)

            // Write the data to the circular buffer
            val bytesWritten = write(tempBuffer, 0, bytesToRead)

            return bytesWritten
        } catch (e: Exception) {
            Log.e(TAG, "Error writing from ByteBuffer: ${e.message}")
            return 0
        } finally {
            // Always reset the buffer position
            buffer.position(originalPosition)
        }
    }

    /** Clears the buffer. */
    fun clear() {
        lock.withLock {
            readPosition = 0
            writePosition = 0
            available = 0
        }
    }

    /** Returns the number of bytes available to read. */
    fun available(): Int {
        return lock.withLock { available }
    }

    /** Returns the number of bytes that can be written. */
    fun remaining(): Int {
        return lock.withLock { capacity - available }
    }

    /** Returns true if the buffer is empty. */
    fun isEmpty(): Boolean {
        return lock.withLock { available == 0 }
    }

    /** Returns true if the buffer is full. */
    fun isFull(): Boolean {
        return lock.withLock { available == capacity }
    }
}
