package com.potdroid.android.vision

import android.content.Context
import android.graphics.Bitmap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.Tensor
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import kotlin.math.roundToInt

private const val INPUT_SCALE = 255f

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
    context: Context,
    private val threshold: Float = DEFAULT_THRESHOLD,
) : PotholeDetector, AutoCloseable {
    private val interpreter = Interpreter(loadModelFile(context, MODEL_ASSET))
    private val inputTensor = interpreter.getInputTensor(0)
    private val inputShape = inputTensor.shape()
    private val inputHeight = inputShape[1]
    private val inputWidth = inputShape[2]
    private val inputDataType = inputTensor.dataType()

    override suspend fun detect(bitmap: Bitmap?): PotholeDetection? = withContext(Dispatchers.Default) {
        if (bitmap == null) return@withContext null

        if (interpreter.outputTensorCount == YOLO_OUTPUT_COUNT) {
            return@withContext detectYolo(bitmap)
        }

        detectSsd(bitmap)
    }

    override fun close() {
        interpreter.close()
    }

    private fun detectSsd(bitmap: Bitmap): PotholeDetection? {
        val outputIndexes = OutputIndexes.from(interpreter)
        val maxDetections = interpreter.getOutputTensor(outputIndexes.scores).shape()[1]
        val boxes = Array(1) { Array(maxDetections) { FloatArray(4) } }
        val classes = Array(1) { FloatArray(maxDetections) }
        val scores = Array(1) { FloatArray(maxDetections) }
        val count = FloatArray(1)

        val outputs = mapOf(
            outputIndexes.boxes to boxes,
            outputIndexes.classes to classes,
            outputIndexes.scores to scores,
            outputIndexes.count to count,
        )

        interpreter.runForMultipleInputsOutputs(arrayOf(preprocess(bitmap)), outputs)

        return bestPotholeDetection(
            boxes = boxes[0],
            classes = classes[0],
            scores = scores[0],
            labels = SSD_LABELS,
            threshold = threshold,
            modelVersion = MODEL_VERSION,
            capturedAtMillis = System.currentTimeMillis(),
        )
    }

    private fun detectYolo(bitmap: Bitmap): PotholeDetection? {
        val outputTensor = interpreter.getOutputTensor(0)
        val outputBuffer = ByteBuffer
            .allocateDirect(outputTensor.numBytes())
            .order(ByteOrder.nativeOrder())
        interpreter.run(preprocess(bitmap), outputBuffer)
        outputBuffer.rewind()

        return bestYoloPotholeDetection(
            output = outputTensor.toFloatArray(outputBuffer),
            outputShape = outputTensor.shape(),
            inputWidth = inputWidth,
            inputHeight = inputHeight,
            threshold = threshold,
            modelVersion = MODEL_VERSION,
            capturedAtMillis = System.currentTimeMillis(),
        )
    }

    private fun preprocess(bitmap: Bitmap): ByteBuffer {
        val resized = Bitmap.createScaledBitmap(bitmap, inputWidth, inputHeight, true)
        val pixels = IntArray(inputWidth * inputHeight)
        resized.getPixels(pixels, 0, inputWidth, 0, 0, inputWidth, inputHeight)

        val bytesPerChannel = inputDataType.byteSize()
        val inputBuffer = ByteBuffer
            .allocateDirect(inputWidth * inputHeight * RGB_CHANNELS * bytesPerChannel)
            .order(ByteOrder.nativeOrder())
        val quantization = inputTensor.quantizationParams()

        pixels.forEach { pixel ->
            val red = (pixel shr 16) and 0xFF
            val green = (pixel shr 8) and 0xFF
            val blue = pixel and 0xFF

            inputBuffer.putColorChannel(red, inputDataType, quantization)
            inputBuffer.putColorChannel(green, inputDataType, quantization)
            inputBuffer.putColorChannel(blue, inputDataType, quantization)
        }

        inputBuffer.rewind()
        return inputBuffer
    }

    private data class OutputIndexes(
        val boxes: Int,
        val classes: Int,
        val scores: Int,
        val count: Int,
    ) {
        companion object {
            fun from(interpreter: Interpreter): OutputIndexes {
                val outputName = interpreter.getOutputTensor(0).name()
                return if (outputName.contains("StatefulPartitionedCall")) {
                    OutputIndexes(boxes = 1, classes = 3, scores = 0, count = 2)
                } else {
                    OutputIndexes(boxes = 0, classes = 1, scores = 2, count = 3)
                }
            }
        }
    }

    companion object {
        const val MODEL_ASSET = "pot_yolo_int8.tflite"
        const val MODEL_VERSION = "pot-yolo-int8-780aff5"
        const val DEFAULT_THRESHOLD = 0.65f
        private const val RGB_CHANNELS = 3
        private const val YOLO_OUTPUT_COUNT = 1
        private val SSD_LABELS = listOf("null", "object", "Pothole")
    }
}

internal fun bestPotholeDetection(
    boxes: Array<FloatArray>,
    classes: FloatArray,
    scores: FloatArray,
    labels: List<String>,
    threshold: Float,
    modelVersion: String,
    capturedAtMillis: Long,
): PotholeDetection? {
    val bestIndex = scores.indices
        .filter { scores[it] >= threshold && labels.getOrNull(classes[it].toInt()).equals("Pothole", ignoreCase = true) }
        .maxByOrNull { scores[it] } ?: return null

    val box = boxes[bestIndex]
    return PotholeDetection(
        confidence = scores[bestIndex],
        boundingBox = BoundingBox(
            left = box[1].coerceIn(0f, 1f),
            top = box[0].coerceIn(0f, 1f),
            right = box[3].coerceIn(0f, 1f),
            bottom = box[2].coerceIn(0f, 1f),
        ),
        modelVersion = modelVersion,
        capturedAtMillis = capturedAtMillis,
    )
}

internal fun bestYoloPotholeDetection(
    output: FloatArray,
    outputShape: IntArray,
    inputWidth: Int,
    inputHeight: Int,
    threshold: Float,
    modelVersion: String,
    capturedAtMillis: Long,
): PotholeDetection? {
    val dimensions = outputShape.dropWhile { it == 1 }
    val attributesFirst = dimensions.size == 2 && dimensions[0] == YOLO_ATTRIBUTES
    val attributesLast = dimensions.size == 2 && dimensions[1] == YOLO_ATTRIBUTES
    if (!attributesFirst && !attributesLast) return null

    val candidateCount = if (attributesFirst) dimensions[1] else dimensions[0]
    var bestDetection: PotholeDetection? = null

    for (index in 0 until candidateCount) {
        val score = yoloValue(output, attributesFirst, candidateCount, index, YOLO_CONFIDENCE_INDEX)
        if (score < threshold || score <= (bestDetection?.confidence ?: 0f)) continue

        val centerX = yoloValue(output, attributesFirst, candidateCount, index, 0)
        val centerY = yoloValue(output, attributesFirst, candidateCount, index, 1)
        val width = yoloValue(output, attributesFirst, candidateCount, index, 2)
        val height = yoloValue(output, attributesFirst, candidateCount, index, 3)

        bestDetection = PotholeDetection(
            confidence = score,
            boundingBox = BoundingBox(
                left = normalizeYoloCoordinate(centerX - width / 2f, inputWidth),
                top = normalizeYoloCoordinate(centerY - height / 2f, inputHeight),
                right = normalizeYoloCoordinate(centerX + width / 2f, inputWidth),
                bottom = normalizeYoloCoordinate(centerY + height / 2f, inputHeight),
            ),
            modelVersion = modelVersion,
            capturedAtMillis = capturedAtMillis,
        )
    }

    return bestDetection
}

private const val YOLO_ATTRIBUTES = 5
private const val YOLO_CONFIDENCE_INDEX = 4

private fun yoloValue(
    output: FloatArray,
    attributesFirst: Boolean,
    candidateCount: Int,
    candidateIndex: Int,
    attributeIndex: Int,
): Float =
    if (attributesFirst) {
        output[attributeIndex * candidateCount + candidateIndex]
    } else {
        output[candidateIndex * YOLO_ATTRIBUTES + attributeIndex]
    }

private fun normalizeYoloCoordinate(value: Float, inputSize: Int): Float {
    val normalized = if (value > 1f) value / inputSize else value
    return normalized.coerceIn(0f, 1f)
}

private fun ByteBuffer.putColorChannel(
    value: Int,
    dataType: DataType,
    quantization: Tensor.QuantizationParams,
) {
    when (dataType) {
        DataType.FLOAT32 -> putFloat(value / INPUT_SCALE)
        DataType.UINT8, DataType.INT8 -> {
            val realValue = if (quantization.getScale() < NORMALIZED_INPUT_SCALE_CUTOFF) value / 255f else value.toFloat()
            val quantized = (realValue / quantization.getScale() + quantization.getZeroPoint()).roundToInt()
            val minimum = if (dataType == DataType.UINT8) 0 else Byte.MIN_VALUE.toInt()
            val maximum = if (dataType == DataType.UINT8) 255 else Byte.MAX_VALUE.toInt()
            put(quantized.coerceIn(minimum, maximum).toByte())
        }
        else -> throw IllegalArgumentException("Unsupported model input data type: $dataType")
    }
}

private const val NORMALIZED_INPUT_SCALE_CUTOFF = 0.1f

private fun Tensor.toFloatArray(buffer: ByteBuffer): FloatArray {
    val quantization = quantizationParams()
    return FloatArray(numElements()) {
        when (dataType()) {
            DataType.FLOAT32 -> buffer.getFloat()
            DataType.UINT8 -> ((buffer.get().toInt() and 0xFF) - quantization.getZeroPoint()) * quantization.getScale()
            DataType.INT8 -> (buffer.get().toInt() - quantization.getZeroPoint()) * quantization.getScale()
            else -> throw IllegalArgumentException("Unsupported model output data type: ${dataType()}")
        }
    }
}

private fun loadModelFile(context: Context, assetName: String): MappedByteBuffer {
    val fileDescriptor = context.assets.openFd(assetName)
    return FileInputStream(fileDescriptor.fileDescriptor).channel.use { channel ->
        channel.map(FileChannel.MapMode.READ_ONLY, fileDescriptor.startOffset, fileDescriptor.declaredLength)
    }
}
