package com.potdroid.android.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class CandidatePotholeDaoTest {
    private lateinit var database: PotDroidDatabase
    private lateinit var dao: CandidatePotholeDao

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        database = Room.inMemoryDatabaseBuilder(context, PotDroidDatabase::class.java).build()
        dao = database.candidatePotholeDao()
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun pendingUploadsIncludesFailedAndPendingRows() = runTest {
        dao.insert(candidate(uploadStatus = UploadStatus.Pending))
        dao.insert(candidate(uploadStatus = UploadStatus.Failed))
        dao.insert(candidate(uploadStatus = UploadStatus.Uploaded))

        val pending = dao.pendingUploads()

        assertEquals(2, pending.size)
    }

    private fun candidate(uploadStatus: UploadStatus) = CandidatePotholeEntity(
        imagePath = "/tmp/pothole.jpg",
        latitude = 45.4215,
        longitude = -75.6972,
        heading = null,
        speed = null,
        detectorConfidence = 0.91f,
        detectorModelVersion = "fake-detector-v1",
        boundingBoxLeft = 0.1f,
        boundingBoxTop = 0.2f,
        boundingBoxRight = 0.3f,
        boundingBoxBottom = 0.4f,
        capturedAtMillis = System.currentTimeMillis(),
        uploadStatus = uploadStatus,
    )
}
