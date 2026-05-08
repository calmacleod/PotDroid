package com.potdroid.android.vision

import android.graphics.Bitmap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class BoundingBox(
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float,
)

data class PotholeDetection(
    val confidence: Float,
    val boundingBox: BoundingBox,
    val modelVersion: String,
    val capturedAtMillis: Long,
)

interface PotholeDetector {
    suspend fun detect(bitmap: Bitmap?): PotholeDetection?
}

class FakePotholeDetector(
    private val confidence: Float = 0.92f,
    private val threshold: Float = 0.7f,
) : PotholeDetector {
    override suspend fun detect(bitmap: Bitmap?): PotholeDetection? {
        if (confidence < threshold) return null

        return PotholeDetection(
            confidence = confidence,
            boundingBox = BoundingBox(0.25f, 0.45f, 0.75f, 0.92f),
            modelVersion = MODEL_VERSION,
            capturedAtMillis = System.currentTimeMillis(),
        )
    }

    companion object {
        const val MODEL_VERSION = "fake-detector-v1"
    }
}

class TflitePotholeDetector(
    private val threshold: Float = 0.7f,
) : PotholeDetector {
    override suspend fun detect(bitmap: Bitmap?): PotholeDetection? = withContext(Dispatchers.Default) {
        if (bitmap == null) return@withContext null
        // The model file is intentionally not bundled yet. This class is the production slot
        // for a TensorFlow Lite Task Vision detector once a trained pothole model is selected.
        null
    }
}
