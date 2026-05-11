package com.potdroid.android.data

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.potdroid.android.vision.BoundingBox

enum class UploadStatus {
    Pending,
    Uploading,
    Uploaded,
    Failed,
}

@Entity(tableName = "candidate_potholes")
data class CandidatePotholeEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val imagePath: String,
    val latitude: Double,
    val longitude: Double,
    val heading: Double?,
    val speed: Double?,
    val detectorConfidence: Float,
    val detectorModelVersion: String,
    val boundingBoxLeft: Float,
    val boundingBoxTop: Float,
    val boundingBoxRight: Float,
    val boundingBoxBottom: Float,
    val capturedAtMillis: Long,
    val accelerometerData: String? = null,
    val uploadStatus: UploadStatus = UploadStatus.Pending,
    val remoteId: Long? = null,
    val lastError: String? = null,
) {
    val boundingBox: BoundingBox
        get() = BoundingBox(boundingBoxLeft, boundingBoxTop, boundingBoxRight, boundingBoxBottom)
}
