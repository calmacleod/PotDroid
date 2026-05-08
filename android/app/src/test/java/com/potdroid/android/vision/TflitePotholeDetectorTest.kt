package com.potdroid.android.vision

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class TflitePotholeDetectorTest {
    @Test
    fun decodesAttributesFirstYoloOutput() {
        val output = floatArrayOf(
            320f, 160f,
            320f, 160f,
            64f, 32f,
            128f, 64f,
            0.72f, 0.95f,
        )

        val detection = bestYoloPotholeDetection(
            output = output,
            outputShape = intArrayOf(1, 5, 2),
            inputWidth = 640,
            inputHeight = 640,
            threshold = 0.7f,
            modelVersion = "test-model",
            capturedAtMillis = 123L,
        )

        assertNotNull(detection)
        assertEquals(0.95f, detection!!.confidence)
        assertEquals(BoundingBox(left = 0.225f, top = 0.2f, right = 0.275f, bottom = 0.3f), detection.boundingBox)
    }

    @Test
    fun ignoresYoloOutputBelowThreshold() {
        val detection = bestYoloPotholeDetection(
            output = floatArrayOf(320f, 320f, 64f, 128f, 0.42f),
            outputShape = intArrayOf(1, 5, 1),
            inputWidth = 640,
            inputHeight = 640,
            threshold = 0.7f,
            modelVersion = "test-model",
            capturedAtMillis = 123L,
        )

        assertNull(detection)
    }

    @Test
    fun picksHighestConfidencePotholeDetection() {
        val detection = bestPotholeDetection(
            boxes = arrayOf(
                floatArrayOf(0.1f, 0.2f, 0.3f, 0.4f),
                floatArrayOf(0.2f, 0.3f, 0.8f, 0.9f),
            ),
            classes = floatArrayOf(1f, 2f),
            scores = floatArrayOf(0.99f, 0.82f),
            labels = listOf("null", "object", "Pothole"),
            threshold = 0.7f,
            modelVersion = "test-model",
            capturedAtMillis = 123L,
        )

        assertNotNull(detection)
        assertEquals(0.82f, detection!!.confidence)
        assertEquals("test-model", detection.modelVersion)
        assertEquals(123L, detection.capturedAtMillis)
        assertEquals(BoundingBox(left = 0.3f, top = 0.2f, right = 0.9f, bottom = 0.8f), detection.boundingBox)
    }

    @Test
    fun ignoresNonPotholeClassesAndLowConfidencePotholes() {
        val detection = bestPotholeDetection(
            boxes = arrayOf(
                floatArrayOf(0.1f, 0.2f, 0.3f, 0.4f),
                floatArrayOf(0.2f, 0.3f, 0.8f, 0.9f),
            ),
            classes = floatArrayOf(1f, 2f),
            scores = floatArrayOf(0.99f, 0.42f),
            labels = listOf("null", "object", "Pothole"),
            threshold = 0.7f,
            modelVersion = "test-model",
            capturedAtMillis = 123L,
        )

        assertNull(detection)
    }
}
