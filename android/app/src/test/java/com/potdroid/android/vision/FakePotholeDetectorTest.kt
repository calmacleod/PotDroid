package com.potdroid.android.vision

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class FakePotholeDetectorTest {
    @Test
    fun returnsDetectionWhenConfidenceMeetsThreshold() = runTest {
        val detector = FakePotholeDetector(confidence = 0.91f, threshold = 0.7f)

        val detection = detector.detect(bitmap = null)

        assertNotNull(detection)
        assertEquals("fake-detector-v1", detection!!.modelVersion)
        assertEquals(0.91f, detection.confidence)
    }

    @Test
    fun returnsNullWhenConfidenceIsBelowThreshold() = runTest {
        val detector = FakePotholeDetector(confidence = 0.51f, threshold = 0.7f)

        assertNull(detector.detect(bitmap = null))
    }
}
