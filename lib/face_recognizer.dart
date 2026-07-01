import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:ui' show Rect;

// MobileFaceNet -> L2-normalized embedding
class FaceRecognizer {
  FaceRecognizer._();
  static final FaceRecognizer instance = FaceRecognizer._();

  Interpreter? _interp;
  int _size = 112;
  int _embLen = 192;
  bool ready = false;

  Future<void> load() async {
    if (ready) return;
    try {
      _interp =
      await Interpreter.fromAsset('assets/models/edgeface_s.tflite');
      _size = _interp!.getInputTensor(0).shape[1];
      final out = _interp!.getOutputTensor(0).shape;
      _embLen = out[out.length - 1];
      ready = true;
    } catch (_) {
      ready = false;
    }
  }

  List<double>? embedFace(img.Image full, Rect box) {
    if (_interp == null) return null;

    // ---- SQUARE crop centred on the face (no aspect distortion) ----
    final pad = box.width * 0.2;
    final cx = box.left + box.width / 2;
    final cy = box.top + box.height / 2;
    double side = math.max(box.width, box.height) + pad * 2;
    // keep the square inside the image
    side = math.min(side, full.width.toDouble());
    side = math.min(side, full.height.toDouble());
    int x = (cx - side / 2).clamp(0, full.width - side).toInt();
    int y = (cy - side / 2).clamp(0, full.height - side).toInt();
    int s = side.toInt().clamp(1, math.min(full.width - x, full.height - y));

    final crop = img.copyCrop(full, x: x, y: y, width: s, height: s);
    final r = img.copyResize(crop, width: _size, height: _size);

    final input = List.generate(
      1,
          (_) => List.generate(
        _size,
            (yy) => List.generate(_size, (xx) {
          final p = r.getPixel(xx, yy);
          return [
            (p.r / 255.0 - 0.5) / 0.5,
            (p.g / 255.0 - 0.5) / 0.5,
            (p.b / 255.0 - 0.5) / 0.5
          ];
        }),
      ),
    );
    final output = List.generate(1, (_) => List.filled(_embLen, 0.0));
    _interp!.run(input, output);
    final emb = output[0];
    double norm = 0;
    for (final v in emb) {
      norm += v * v;
    }
    norm = math.sqrt(norm);
    if (norm == 0) return null;
    return emb.map((v) => v / norm).toList();
  }

  static double similarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return -1;
    double dot = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }
}

// match thresholds (tuned after square-crop quality fix)
const double kMatchThreshold = 0.45; // strict: only the real person passes
const double kDupThreshold = 0.50; // block duplicate registration
const double kMatchMargin = 0.05; // best must beat 2nd-best by this gap

double bestScore(List<double> probe, List<List<double>> templates) {
  double best = -1;
  for (final t in templates) {
    final s = FaceRecognizer.similarity(probe, t);
    if (s > best) best = s;
  }
  return best;
}