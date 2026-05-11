package com.potdroid.android.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class AccelerometerSample(
    @SerialName("elapsed_millis") val elapsedMillis: Long,
    val x: Float,
    val y: Float,
    val z: Float,
    val magnitude: Float,
)

@Serializable
data class AccelerometerSnapshot(
    @SerialName("sensor_type") val sensorType: String,
    @SerialName("sensor_name") val sensorName: String,
    @SerialName("includes_gravity") val includesGravity: Boolean,
    @SerialName("sample_rate_hz") val sampleRateHz: Float?,
    @SerialName("window_start_elapsed_millis") val windowStartElapsedMillis: Long,
    @SerialName("window_end_elapsed_millis") val windowEndElapsedMillis: Long,
    @SerialName("peak_magnitude") val peakMagnitude: Float,
    @SerialName("bump_threshold") val bumpThreshold: Float,
    @SerialName("bump_detected") val bumpDetected: Boolean,
    val samples: List<AccelerometerSample>,
)

data class AccelerometerDisplayState(
    val available: Boolean = false,
    val sensorType: String = "accelerometer",
    val x: Float = 0f,
    val y: Float = 0f,
    val z: Float = 0f,
    val magnitude: Float = 0f,
    val peakMagnitude: Float = 0f,
    val recentMagnitudes: List<Float> = emptyList(),
)
