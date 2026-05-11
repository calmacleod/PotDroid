package com.potdroid.android.data

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlin.math.sqrt

class AccelerometerMonitor(context: Context) : SensorEventListener {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val sensor = sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
        ?: sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val samples = ArrayDeque<AccelerometerSample>()
    private val _state = MutableStateFlow(AccelerometerDisplayState(available = sensor != null))

    val state: StateFlow<AccelerometerDisplayState> = _state

    fun start() {
        sensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
    }

    fun stop() {
        sensorManager.unregisterListener(this)
    }

    fun snapshot(windowMillis: Long = DEFAULT_SNAPSHOT_WINDOW_MS): AccelerometerSnapshot? {
        val currentSensor = sensor ?: return null
        val now = SystemClock.elapsedRealtime()
        val windowStart = now - windowMillis
        val windowSamples = synchronized(samples) {
            samples.filter { it.elapsedMillis >= windowStart }
        }
        if (windowSamples.isEmpty()) return null

        val sampleRateHz = if (windowSamples.size > 1) {
            val elapsed = (windowSamples.last().elapsedMillis - windowSamples.first().elapsedMillis).coerceAtLeast(1)
            ((windowSamples.size - 1) * 1_000f) / elapsed
        } else {
            null
        }

        val peakMagnitude = windowSamples.maxOf { it.magnitude }
        val bumpThreshold = bumpThreshold(currentSensor)

        return AccelerometerSnapshot(
            sensorType = sensorTypeName(currentSensor.type),
            sensorName = currentSensor.name,
            includesGravity = currentSensor.type == Sensor.TYPE_ACCELEROMETER,
            sampleRateHz = sampleRateHz,
            windowStartElapsedMillis = windowSamples.first().elapsedMillis,
            windowEndElapsedMillis = windowSamples.last().elapsedMillis,
            peakMagnitude = peakMagnitude,
            bumpThreshold = bumpThreshold,
            bumpDetected = peakMagnitude >= bumpThreshold,
            samples = windowSamples,
        )
    }

    override fun onSensorChanged(event: SensorEvent) {
        val sample = AccelerometerSample(
            elapsedMillis = SystemClock.elapsedRealtime(),
            x = event.values.getOrElse(0) { 0f },
            y = event.values.getOrElse(1) { 0f },
            z = event.values.getOrElse(2) { 0f },
            magnitude = magnitude(event.values),
        )

        val recentMagnitudes = synchronized(samples) {
            samples.addLast(sample)
            val cutoff = sample.elapsedMillis - RETAINED_WINDOW_MS
            while (samples.firstOrNull()?.elapsedMillis?.let { it < cutoff } == true) {
                samples.removeFirst()
            }
            samples.map { it.magnitude }
        }

        _state.value = AccelerometerDisplayState(
            available = true,
            sensorType = sensorTypeName(event.sensor.type),
            x = sample.x,
            y = sample.y,
            z = sample.z,
            magnitude = sample.magnitude,
            peakMagnitude = recentMagnitudes.maxOrNull() ?: sample.magnitude,
            recentMagnitudes = recentMagnitudes.takeLast(DISPLAY_SAMPLE_COUNT),
        )
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun magnitude(values: FloatArray): Float {
        val x = values.getOrElse(0) { 0f }
        val y = values.getOrElse(1) { 0f }
        val z = values.getOrElse(2) { 0f }
        return sqrt((x * x) + (y * y) + (z * z))
    }

    private fun sensorTypeName(type: Int): String =
        if (type == Sensor.TYPE_LINEAR_ACCELERATION) "linear_acceleration" else "accelerometer"

    private fun bumpThreshold(sensor: Sensor): Float =
        if (sensor.type == Sensor.TYPE_LINEAR_ACCELERATION) LINEAR_BUMP_THRESHOLD else RAW_ACCELEROMETER_BUMP_THRESHOLD

    private companion object {
        const val RETAINED_WINDOW_MS = 5_000L
        const val DEFAULT_SNAPSHOT_WINDOW_MS = 3_000L
        const val DISPLAY_SAMPLE_COUNT = 60
        const val LINEAR_BUMP_THRESHOLD = 5f
        const val RAW_ACCELEROMETER_BUMP_THRESHOLD = 14f
    }
}
