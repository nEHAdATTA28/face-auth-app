import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:tflite_flutter/tflite_flutter.dart';

class ModelPrediction {
  const ModelPrediction({required this.appClass, required this.confidence});

  final String appClass;
  final double confidence;
}

class PredictionService {
  PredictionService._();

  static const _modelPath = 'assets/models/face_classifier.tflite';
  static const _labelsPath = 'assets/models/face_classifier_labels.txt';

  static Interpreter? _interpreter;
  static List<String>? _labels;

  static Future<ModelPrediction> predict(Uint8List imageBytes) async {
    final decoded = image.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FormatException('The selected image could not be decoded.');
    }

    final interpreter = await _loadInterpreter();
    final labels = await _loadLabels();
    final inputShape = interpreter.getInputTensor(0).shape;

    if (inputShape.length != 4 || inputShape[0] != 1 || inputShape[3] != 3) {
      throw StateError('Unsupported model input shape: $inputShape');
    }

    final height = inputShape[1];
    final width = inputShape[2];
    final input = _resizeWithPad(decoded, width: width, height: height);
    final outputLength = interpreter.getOutputTensor(0).shape.last;

    if (outputLength != labels.length) {
      throw StateError('Model has $outputLength outputs but ${labels.length} labels are configured.');
    }

    final output = List.generate(1, (_) => List<double>.filled(outputLength, 0));
    interpreter.run(input, output);

    final scores = _probabilities(output.single);
    var bestIndex = 0;
    for (var index = 1; index < scores.length; index++) {
      if (scores[index] > scores[bestIndex]) bestIndex = index;
    }

    // The identity label is used only for the required internal mapping.
    // It is never returned to, or displayed by, the app UI.
    final appClass = labels[bestIndex] == 'professor' ? 'class_B' : 'class_A';
    return ModelPrediction(appClass: appClass, confidence: scores[bestIndex]);
  }

  // Matches the Colab training/test preprocessing: preserve aspect ratio and
  // letterbox with black pixels while supplying raw 0-255 RGB values.
  static List<List<List<List<double>>>> _resizeWithPad(
    image.Image source, {
    required int width,
    required int height,
  }) {
    final scale = min(width / source.width, height / source.height);
    final resizedWidth = max(1, (source.width * scale).round());
    final resizedHeight = max(1, (source.height * scale).round());
    final resized = image.copyResize(source, width: resizedWidth, height: resizedHeight);
    final left = (width - resizedWidth) ~/ 2;
    final top = (height - resizedHeight) ~/ 2;

    return List.generate(1, (_) => List.generate(height, (y) => List.generate(width, (x) {
      if (x < left || x >= left + resizedWidth || y < top || y >= top + resizedHeight) {
        return <double>[0, 0, 0];
      }
      final pixel = resized.getPixel(x - left, y - top);
      return <double>[pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble()];
    })));
  }

  static Future<Interpreter> _loadInterpreter() async {
    return _interpreter ??= await Interpreter.fromAsset(_modelPath);
  }

  static Future<List<String>> _loadLabels() async {
    return _labels ??= (await rootBundle.loadString(_labelsPath))
        .split(RegExp(r'\r?\n'))
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);
  }

  static List<double> _probabilities(List<double> values) {
    final sum = values.fold<double>(0, (total, value) => total + value);
    if (values.every((value) => value >= 0 && value <= 1) && (sum - 1).abs() < 0.01) {
      return values;
    }

    final maxValue = values.reduce(max);
    final exponentials = values.map((value) => exp(value - maxValue)).toList();
    final denominator = exponentials.fold<double>(0, (total, value) => total + value);
    return exponentials.map((value) => value / denominator).toList();
  }
}
