package com.potdroid.android.worker

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.potdroid.android.data.DebugSettings
import com.potdroid.android.data.PotDroidDatabase
import com.potdroid.android.data.UploadStatus
import com.potdroid.android.network.ApiClient
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.File
import java.time.Instant

class CandidateUploadWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val dao = PotDroidDatabase.get(applicationContext).candidatePotholeDao()
        val api = ApiClient(DebugSettings(applicationContext)).candidatePotholeApi()
        var hadFailure = false

        dao.pendingUploads().forEach { candidate ->
            val uploading = candidate.copy(uploadStatus = UploadStatus.Uploading, lastError = null)
            dao.update(uploading)

            try {
                val imageFile = File(candidate.imagePath)
                val response = api.createCandidate(
                    image = MultipartBody.Part.createFormData(
                        "candidate_pothole[image]",
                        imageFile.name,
                        imageFile.asRequestBody("image/jpeg".toMediaType()),
                    ),
                    latitude = candidate.latitude.body(),
                    longitude = candidate.longitude.body(),
                    heading = candidate.heading?.body(),
                    speed = candidate.speed?.body(),
                    detectorConfidence = candidate.detectorConfidence.body(),
                    detectorModelVersion = candidate.detectorModelVersion.body(),
                    capturedAt = Instant.ofEpochMilli(candidate.capturedAtMillis).toString().body(),
                    boundingBoxLeft = candidate.boundingBoxLeft.body(),
                    boundingBoxTop = candidate.boundingBoxTop.body(),
                    boundingBoxRight = candidate.boundingBoxRight.body(),
                    boundingBoxBottom = candidate.boundingBoxBottom.body(),
                )

                if (response.isSuccessful) {
                    dao.update(uploading.copy(uploadStatus = UploadStatus.Uploaded, remoteId = response.body()?.data?.id))
                } else {
                    hadFailure = true
                    dao.update(uploading.copy(uploadStatus = UploadStatus.Failed, lastError = "HTTP ${response.code()}"))
                }
            } catch (error: Exception) {
                hadFailure = true
                dao.update(uploading.copy(uploadStatus = UploadStatus.Failed, lastError = error.message))
            }
        }

        return if (hadFailure) Result.retry() else Result.success()
    }

    private fun Any.body() = toString().toRequestBody("text/plain".toMediaType())
}
