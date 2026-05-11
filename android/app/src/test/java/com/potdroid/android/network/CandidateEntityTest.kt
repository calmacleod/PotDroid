package com.potdroid.android.network

import com.potdroid.android.data.CandidatePotholeEntity
import com.potdroid.android.data.UploadStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CandidateEntityTest {
    @Test
    fun exposesBoundingBoxValueObject() {
        val candidate = CandidatePotholeEntity(
            imagePath = "/tmp/pothole.jpg",
            latitude = 45.4215,
            longitude = -75.6972,
            heading = null,
            speed = null,
            detectorConfidence = 0.9f,
            detectorModelVersion = "fake-detector-v1",
            boundingBoxLeft = 0.1f,
            boundingBoxTop = 0.2f,
            boundingBoxRight = 0.3f,
            boundingBoxBottom = 0.4f,
            capturedAtMillis = 1_779_999_999,
            accelerometerData = """{"peak_magnitude":7.2,"samples":[]}""",
            uploadStatus = UploadStatus.Pending,
        )

        assertEquals(0.1f, candidate.boundingBox.left)
        assertTrue(candidate.accelerometerData!!.contains("peak_magnitude"))
        assertEquals(UploadStatus.Pending, candidate.uploadStatus)
    }
}
