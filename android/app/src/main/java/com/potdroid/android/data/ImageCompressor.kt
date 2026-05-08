package com.potdroid.android.data

import android.graphics.Bitmap
import java.io.ByteArrayOutputStream

class ImageCompressor(
    private val maxBytes: Int = 900_000,
) {
    fun compressJpeg(bitmap: Bitmap): ByteArray {
        var quality = 88
        var bytes = encode(bitmap, quality)

        while (bytes.size > maxBytes && quality > 45) {
            quality -= 8
            bytes = encode(bitmap, quality)
        }

        return bytes
    }

    private fun encode(bitmap: Bitmap, quality: Int): ByteArray {
        val output = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, quality, output)
        return output.toByteArray()
    }
}
