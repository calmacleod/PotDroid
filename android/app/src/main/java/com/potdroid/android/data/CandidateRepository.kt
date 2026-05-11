package com.potdroid.android.data

import android.content.Context
import android.graphics.Bitmap
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.potdroid.android.vision.PotholeDetection
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
import java.time.Instant

class CandidateRepository(
    private val context: Context,
    private val dao: CandidatePotholeDao,
    private val imageCompressor: ImageCompressor = ImageCompressor(),
) {
    suspend fun saveDetection(
        bitmap: Bitmap,
        detection: PotholeDetection,
        latitude: Double,
        longitude: Double,
        heading: Double?,
        speed: Double?,
        accelerometerSnapshot: AccelerometerSnapshot?,
    ): Long {
        val imageFile = File(context.filesDir, "candidates/${Instant.now().toEpochMilli()}.jpg")
        imageFile.parentFile?.mkdirs()
        imageFile.writeBytes(imageCompressor.compressJpeg(bitmap))

        val id = dao.insert(
            CandidatePotholeEntity(
                imagePath = imageFile.absolutePath,
                latitude = latitude,
                longitude = longitude,
                heading = heading,
                speed = speed,
                detectorConfidence = detection.confidence,
                detectorModelVersion = detection.modelVersion,
                boundingBoxLeft = detection.boundingBox.left,
                boundingBoxTop = detection.boundingBox.top,
                boundingBoxRight = detection.boundingBox.right,
                boundingBoxBottom = detection.boundingBox.bottom,
                capturedAtMillis = detection.capturedAtMillis,
                accelerometerData = accelerometerSnapshot?.let { json.encodeToString(it) },
            )
        )

        WorkManager.getInstance(context).enqueue(OneTimeWorkRequestBuilder<com.potdroid.android.worker.CandidateUploadWorker>().build())
        return id
    }

    private companion object {
        val json = Json { encodeDefaults = true }
    }
}
