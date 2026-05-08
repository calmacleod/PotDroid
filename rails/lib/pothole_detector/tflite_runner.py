#!/usr/bin/env python3
import argparse
import json
import sys


MODEL_VERSION = "pot-yolo-int8-780aff5"
NORMALIZED_INPUT_SCALE_CUTOFF = 0.1
YOLO_ATTRIBUTES = 5
YOLO_CONFIDENCE_INDEX = 4


class MissingDependencyError(RuntimeError):
    pass


try:
    import numpy as np
except ImportError:
    np = None


def load_interpreter():
    try:
        from ai_edge_litert.interpreter import Interpreter

        return Interpreter
    except ImportError:
        pass

    try:
        from tflite_runtime.interpreter import Interpreter

        return Interpreter
    except ImportError:
        pass

    try:
        from tensorflow.lite.python.interpreter import Interpreter

        return Interpreter
    except ImportError as error:
        raise MissingDependencyError(
            "missing TFLite runtime; install ai-edge-litert, tflite-runtime, or tensorflow"
        ) from error


def load_image(path, width, height, input_detail):
    try:
        from PIL import Image, ImageOps
    except ImportError as error:
        raise MissingDependencyError("missing Pillow; install pillow") from error

    image = ImageOps.exif_transpose(Image.open(path)).convert("RGB").resize((width, height))
    data = np.asarray(image)
    dtype = input_detail["dtype"]

    if dtype == np.float32:
        return np.expand_dims(data.astype(np.float32) / 255.0, axis=0)

    scale, zero_point = input_detail.get("quantization", (0.0, 0))
    real_values = data.astype(np.float32) / 255.0 if scale and scale < NORMALIZED_INPUT_SCALE_CUTOFF else data.astype(np.float32)
    quantized = np.rint(real_values / scale + zero_point) if scale else real_values

    if dtype == np.uint8:
        quantized = np.clip(quantized, 0, 255)
    elif dtype == np.int8:
        quantized = np.clip(quantized, -128, 127)

    return np.expand_dims(quantized.astype(dtype), axis=0)


def dequantized_output(interpreter, output_detail):
    output = interpreter.get_tensor(output_detail["index"])
    if output.dtype == np.float32:
        return output.astype(np.float32).flatten()

    scale, zero_point = output_detail.get("quantization", (0.0, 0))
    if not scale:
        return output.astype(np.float32).flatten()

    return ((output.astype(np.float32) - zero_point) * scale).flatten()


def yolo_value(output, attributes_first, candidate_count, candidate_index, attribute_index):
    if attributes_first:
        return float(output[attribute_index * candidate_count + candidate_index])

    return float(output[candidate_index * YOLO_ATTRIBUTES + attribute_index])


def normalize_coordinate(value, input_size):
    normalized = value / input_size if value > 1.0 else value
    return max(0.0, min(1.0, normalized))


def decode_yolo(output, output_shape, input_width, input_height, threshold):
    dimensions = list(output_shape)
    while dimensions and dimensions[0] == 1:
        dimensions = dimensions[1:]

    attributes_first = len(dimensions) == 2 and dimensions[0] == YOLO_ATTRIBUTES
    attributes_last = len(dimensions) == 2 and dimensions[1] == YOLO_ATTRIBUTES
    if not attributes_first and not attributes_last:
        raise RuntimeError(f"unsupported YOLO output shape: {output_shape}")

    candidate_count = dimensions[1] if attributes_first else dimensions[0]
    detections = []

    for index in range(candidate_count):
        score = yolo_value(output, attributes_first, candidate_count, index, YOLO_CONFIDENCE_INDEX)
        if score < threshold:
            continue

        center_x = yolo_value(output, attributes_first, candidate_count, index, 0)
        center_y = yolo_value(output, attributes_first, candidate_count, index, 1)
        width = yolo_value(output, attributes_first, candidate_count, index, 2)
        height = yolo_value(output, attributes_first, candidate_count, index, 3)

        detections.append(
            {
                "confidence": score,
                "bounding_box": {
                    "left": normalize_coordinate(center_x - width / 2.0, input_width),
                    "top": normalize_coordinate(center_y - height / 2.0, input_height),
                    "right": normalize_coordinate(center_x + width / 2.0, input_width),
                    "bottom": normalize_coordinate(center_y + height / 2.0, input_height),
                },
            }
        )

    return sorted(detections, key=lambda detection: detection["confidence"], reverse=True)


def run(model_path, image_path, threshold):
    if np is None:
        raise MissingDependencyError("missing NumPy; install numpy")

    Interpreter = load_interpreter()
    interpreter = Interpreter(model_path=model_path)
    interpreter.allocate_tensors()

    input_detail = interpreter.get_input_details()[0]
    output_detail = interpreter.get_output_details()[0]
    _, input_height, input_width, _ = input_detail["shape"]
    input_data = load_image(image_path, input_width, input_height, input_detail)

    interpreter.set_tensor(input_detail["index"], input_data)
    interpreter.invoke()

    detections = decode_yolo(
        output=dequantized_output(interpreter, output_detail),
        output_shape=output_detail["shape"],
        input_width=input_width,
        input_height=input_height,
        threshold=threshold,
    )
    best_detection = detections[0] if detections else None

    return {
        "detected": best_detection is not None,
        "confidence": best_detection["confidence"] if best_detection else None,
        "threshold": threshold,
        "model_version": MODEL_VERSION,
        "bounding_box": best_detection["bounding_box"] if best_detection else None,
        "detections": detections,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True)
    parser.add_argument("--image", required=True)
    parser.add_argument("--threshold", type=float, default=0.25)
    args = parser.parse_args()

    try:
        print(json.dumps(run(args.model, args.image, args.threshold)))
    except MissingDependencyError as error:
        print(str(error), file=sys.stderr)
        return 2
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
