package com.weitu.gallery.metadata

import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream

/**
 * Minimal WebP (RIFF) container reader/writer for the `XMP ` chunk.
 *
 * PixyMeta does not support WebP at all (it only handles BMP/GIF/JPEG/PNG/TIFF),
 * so metadata edition for WebP files is handled here by injecting or replacing the
 * `XMP ` chunk directly in the RIFF container.
 *
 * Image data chunks (`VP8 `/`VP8L`/`VP8X`/`ANMF`/`ALPH`) and every other chunk are
 * copied verbatim, so this never re-encodes the picture and never loses quality.
 */
object WebPXmpHelper {
    private val RIFF = "RIFF".toByteArray(Charsets.US_ASCII)
    private val WEBP = "WEBP".toByteArray(Charsets.US_ASCII)
    // caution: the XMP chunk fourcc is "XMP " with a trailing space
    private val XMP_CHUNK = "XMP ".toByteArray(Charsets.US_ASCII)

    private const val RIFF_HEADER_SIZE = 12

    private class Chunk(val fourcc: ByteArray, val data: ByteArray) {
        val paddedSize: Int get() = data.size + (data.size and 1)
    }

    fun isWebP(bytes: ByteArray): Boolean {
        if (bytes.size < RIFF_HEADER_SIZE) return false
        if (!bytes.copyOfRange(0, 4).contentEquals(RIFF)) return false
        return bytes.copyOfRange(8, 12).contentEquals(WEBP)
    }

    /** Returns the XMP packet stored in the `XMP ` chunk, or null if there is none. */
    fun getXmp(bytes: ByteArray): String? {
        if (!isWebP(bytes)) return null
        return chunks(bytes).firstOrNull { it.fourcc.contentEquals(XMP_CHUNK) }
            ?.data
            ?.toString(Charsets.UTF_8)
    }

    fun getXmp(input: InputStream): String? = getXmp(input.readBytes())

    /**
     * Writes [xmpString] as the `XMP ` chunk of the WebP file read from [input].
     * A null or blank value removes any existing XMP chunk.
     */
    fun setXmp(input: InputStream, output: OutputStream, xmpString: String?) {
        val bytes = input.readBytes()
        if (!isWebP(bytes)) {
            throw IllegalArgumentException("not a WebP file")
        }
        val chunks = chunks(bytes).toMutableList()
        chunks.removeAll { it.fourcc.contentEquals(XMP_CHUNK) }
        if (!xmpString.isNullOrEmpty()) {
            // per the WebP container spec, metadata chunks come after the image data
            chunks.add(Chunk(XMP_CHUNK, xmpString.toByteArray(Charsets.UTF_8)))
        }
        writeRiff(output, chunks)
    }

    private fun chunks(bytes: ByteArray): List<Chunk> {
        val result = ArrayList<Chunk>()
        var pos = RIFF_HEADER_SIZE
        while (pos + 8 <= bytes.size) {
            val fourcc = bytes.copyOfRange(pos, pos + 4)
            val size = readUInt32LE(bytes, pos + 4)
            // bail out on bogus or truncated chunk instead of writing a broken file
            if (size < 0 || size > bytes.size - pos - 8) break
            result.add(Chunk(fourcc, bytes.copyOfRange(pos + 8, pos + 8 + size)))
            pos += 8 + size + (size and 1)
        }
        return result
    }

    private fun writeRiff(output: OutputStream, chunks: List<Chunk>) {
        // the RIFF size field counts everything after the 8 byte "RIFF"+size header
        var payloadSize = 4 // "WEBP"
        for (chunk in chunks) {
            payloadSize += 8 + chunk.paddedSize
        }
        val buffer = ByteArrayOutputStream(payloadSize + 8)
        buffer.write(RIFF)
        buffer.write(writeUInt32LE(payloadSize))
        buffer.write(WEBP)
        for (chunk in chunks) {
            buffer.write(chunk.fourcc)
            buffer.write(writeUInt32LE(chunk.data.size))
            buffer.write(chunk.data)
            // chunks are padded to an even size
            if (chunk.data.size and 1 == 1) buffer.write(0)
        }
        buffer.writeTo(output)
    }

    private fun readUInt32LE(bytes: ByteArray, offset: Int): Int =
        (bytes[offset].toInt() and 0xFF) or
            ((bytes[offset + 1].toInt() and 0xFF) shl 8) or
            ((bytes[offset + 2].toInt() and 0xFF) shl 16) or
            ((bytes[offset + 3].toInt() and 0xFF) shl 24)

    private fun writeUInt32LE(value: Int): ByteArray = byteArrayOf(
        (value and 0xFF).toByte(),
        ((value ushr 8) and 0xFF).toByte(),
        ((value ushr 16) and 0xFF).toByte(),
        ((value ushr 24) and 0xFF).toByte(),
    )
}
