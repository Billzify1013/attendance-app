import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import 'models.dart';
import 'face_recognizer.dart';

List<CameraDescription> cameras = [];

class CaptureResult {
  final String photoB64;
  final List<List<double>> templates;
  final Employee? matched;
  CaptureResult(this.photoB64, this.templates, {this.matched});
}

class FaceCaptureScreen extends StatefulWidget {
  final String title;
  final int samples;
  final List<Employee>? identifyAgainst;
  const FaceCaptureScreen({
    super.key,
    this.title = 'Align your face',
    this.samples = 1,
    this.identifyAgainst,
  });

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  Timer? _iosTimer;
  CameraController? _controller;
  late final FaceDetector _detector;
  bool _initializing = true;
  bool _busy = false;
  bool _capturing = false;
  bool _faceVisible = false;
  int _stable = 0;
  int _camIndex = 0;
  String? _error;
  String _hint = 'Position your face in the circle';
  Color _ring = Colors.white60;
  final List<List<double>> _templates = [];
  String? _photo;

  bool get _identify => widget.identifyAgainst != null;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat();
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.12,
      ),
    );
    _pickCamera();
  }

  void _pickCamera() {
    if (!FaceRecognizer.instance.ready) {
      setState(() {
        _error = 'Face model not loaded. Reinstall the app.';
        _initializing = false;
      });
      return;
    }
    if (cameras.isEmpty) {
      setState(() {
        _error = 'No camera found';
        _initializing = false;
      });
      return;
    }
    final front =
    cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
    _camIndex = front >= 0 ? front : 0;
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _initializing = true;
      _capturing = false;
      _faceVisible = false;
      _stable = 0;
    });
    final c = CameraController(
      cameras[_camIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
      Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
    );
    _controller = c;
    try {
      await c.initialize();
      // Live image-stream face-detection is reliable on Android.
      // On iOS it's fragile, so there we detect from a still photo on tap.
      if (!Platform.isIOS) {
        await c.startImageStream(_process);
      }
      if (mounted) {
        setState(() {
          _initializing = false;
          if (Platform.isIOS) _hint = 'Hold still, scanning…';
        });
      }
      // iOS: auto-scan by taking a still photo every ~1.8s (reliable path)
      if (Platform.isIOS) {
        _iosTimer?.cancel();
        _iosTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
          if (!_capturing && mounted) _captureSample();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not open camera. Allow camera permission.';
          _initializing = false;
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    if (cameras.length < 2 || _capturing) return;
    await _stopStream();
    await _controller?.dispose();
    _camIndex = (_camIndex + 1) % cameras.length;
    await _start();
  }

  Future<void> _stopStream() async {
    try {
      if (_controller?.value.isStreamingImages ?? false) {
        await _controller!.stopImageStream();
      }
    } catch (_) {}
  }

  InputImage? _toInputImage(CameraImage image) {
    final cam = cameras[_camIndex];
    final sensor = cam.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      // iOS: use the sensor orientation directly
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else {
      // Android: compensate for device orientation + lens direction
      final deviceOr =
          _controller?.value.deviceOrientation ?? DeviceOrientation.portraitUp;
      var comp = _orientations[deviceOr] ?? 0;
      if (cam.lensDirection == CameraLensDirection.front) {
        comp = (sensor + comp) % 360;
      } else {
        comp = (sensor - comp + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(comp);
    }
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null || image.planes.isEmpty) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _process(CameraImage image) async {
    if (_busy || _capturing) return;
    _busy = true;
    try {
      bool good = false;
      String hint = _hint;
      final input = _toInputImage(image);
      if (input != null) {
        final faces = await _detector.processImage(input);
        if (faces.isEmpty) {
          hint = 'No face — center it in the circle, add light';
        } else if (faces.length > 1) {
          hint = 'Only one person at a time';
        } else {
          final f = faces.first;
          final yaw = (f.headEulerAngleY ?? 99).abs();
          final roll = (f.headEulerAngleZ ?? 99).abs();
          if (yaw > 40 || roll > 40) {
            hint = 'Look straight at the camera';
          } else {
            good = true;
            hint = _identify
                ? 'Hold still…'
                : (widget.samples > 1
                ? 'Hold still (${_templates.length}/${widget.samples})'
                : 'Hold still…');
          }
        }
      }
      if (mounted && (good != _faceVisible || hint != _hint)) {
        setState(() {
          _faceVisible = good;
          _hint = hint;
          if (good) {
            _ring = Colors.green;
          } else if (_ring == Colors.green) {
            _ring = Colors.white60;
          }
        });
      }
      if (good) {
        _stable++;
        if (_stable >= 1) await _captureSample();
      } else {
        _stable = 0;
      }
    } catch (e) {
      if (mounted) setState(() => _hint = 'DET: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _captureSample() async {
    if (_capturing) return;
    _capturing = true;
    _iosTimer?.cancel(); // pause auto-loop while processing this shot
    if (mounted) setState(() => _hint = 'Processing…');
    await _stopStream();
    try {
      final file = await _controller!.takePicture();
      final bytes = await File(file.path).readAsBytes();

      // Decode + bake orientation FIRST so pixels are upright on every device.
      var full = img.decodeImage(bytes);
      if (full == null) return _retry('Capture failed, retry');
      full = img.bakeOrientation(full);

      List<Face> faces;
      if (Platform.isIOS) {
        // iOS photos are rotated/mirrored differently -> detect on baked image
        final bakedPath = '${file.path}_baked.jpg';
        await File(bakedPath).writeAsBytes(img.encodeJpg(full));
        faces = await _detector.processImage(InputImage.fromFilePath(bakedPath));
        try {
          await File(bakedPath).delete();
        } catch (_) {}
      } else {
        // Android: single detection on the captured file (fast)
        faces = await _detector.processImage(InputImage.fromFilePath(file.path));
      }

      if (faces.length != 1) return _retry('Face not clear, retry');
      final f = faces.first;
      final yaw = (f.headEulerAngleY ?? 99).abs();
      final roll = (f.headEulerAngleZ ?? 99).abs();
      if (yaw > 42 || roll > 42) return _retry('Look straight, retry');

      // helpful guidance so the user knows WHY it failed
      final box = f.boundingBox;
      final faceFrac = box.width / full.width;
      if (faceFrac < 0.16) return _retry('Come closer — face too small');
      if (faceFrac > 0.85) return _retry('Move back a little');
      // quick brightness check on the face region
      double lum = 0;
      int n = 0;
      final bx = box.left.clamp(0, full.width - 1).toInt();
      final by = box.top.clamp(0, full.height - 1).toInt();
      final bw = box.width.clamp(1, full.width - bx).toInt();
      final bh = box.height.clamp(1, full.height - by).toInt();
      for (int yy = by; yy < by + bh; yy += (bh ~/ 6).clamp(1, bh)) {
        for (int xx = bx; xx < bx + bw; xx += (bw ~/ 6).clamp(1, bw)) {
          final p = full.getPixel(xx, yy);
          lum += (0.299 * p.r + 0.587 * p.g + 0.114 * p.b);
          n++;
        }
      }
      if (n > 0 && (lum / n) < 45) {
        return _retry('Too dark — face a light source');
      }

      final emb = FaceRecognizer.instance.embedFace(full, f.boundingBox);
      if (emb == null) return _retry('Could not read face, retry');

      _photo ??= base64Encode(
          img.encodeJpg(img.copyResize(full, width: 220), quality: 80));

      if (_identify) {
        Employee? matched;
        double best = -1;
        for (final e in widget.identifyAgainst!) {
          final sc = bestScore(emb, e.templates);
          if (sc > best) {
            best = sc;
            matched = e;
          }
        }
        if (matched == null || best < kMatchThreshold) {
          return _retry('Face not recognized — try again');
        }
        if (mounted) {
          setState(() {
            _ring = Colors.green;
            _hint = 'Hello, ${matched!.name}';
          });
        }
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) {
          Navigator.pop(
              context, CaptureResult(_photo!, [emb], matched: matched));
        }
        return;
      }

      _templates.add(emb);
      if (_templates.length >= widget.samples) {
        if (mounted) Navigator.pop(context, CaptureResult(_photo!, _templates));
        return;
      }
      _stable = 0;
      _capturing = false;
      if (mounted) {
        setState(() {
          _ring = Colors.green;
          _hint =
          'Saved ${_templates.length}/${widget.samples} — turn head slightly';
        });
      }
      await Future.delayed(const Duration(milliseconds: 400));
      if (!Platform.isIOS) {
        try {
          await _controller?.startImageStream(_process);
        } catch (_) {}
      } else if (mounted) {
        _iosTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
          if (!_capturing && mounted) _captureSample();
        });
      }
    } catch (e) {
      _retry('ERR: $e');
    }
  }

  Future<void> _retry(String msg) async {
    _capturing = false;
    _stable = 0;
    if (mounted) {
      setState(() {
        if (Platform.isIOS) {
          _hint = 'Hold still, scanning…';
          _ring = Colors.white60;
        } else {
          _hint = msg;
          _ring = Colors.white60;
        }
      });
    }
    // small cooldown so failed tries don't rapidly flash the camera
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (!Platform.isIOS) {
      try {
        _controller?.startImageStream(_process);
      } catch (_) {}
    } else if (mounted) {
      _iosTimer?.cancel();
      _iosTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
        if (!_capturing && mounted) _captureSample();
      });
    }
  }

  @override
  void dispose() {
    _iosTimer?.cancel();
    _anim.dispose();
    _stopStream();
    _controller?.dispose();
    _detector.close();
    super.dispose();
  }

  Widget _roundPreview(double size) {
    final c = _controller!;
    final preview = c.value.previewSize;
    final ringBox = size + 54;
    final allGreen = _faceVisible || _capturing;
    final error = _ring == Colors.red;
    return SizedBox(
      width: ringBox,
      height: ringBox,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // segmented animated ring
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => CustomPaint(
              size: Size(ringBox, ringBox),
              painter: _RingPainter(
                progress: _anim.value,
                allGreen: allGreen,
                error: error,
              ),
            ),
          ),
          // circular camera + crosshair
          ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: preview?.height ?? size,
                      height: preview?.width ?? size,
                      child: CameraPreview(c),
                    ),
                  ),
                  CustomPaint(painter: _CrosshairPainter()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_initializing &&
        _controller != null &&
        _controller!.value.isInitialized &&
        _error == null;
    final size = MediaQuery.of(context).size.width * 0.72;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: true,
        title: Text(widget.title,
            style: const TextStyle(
                color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800)),
        actions: [
          if (cameras.length > 1)
            IconButton(
              onPressed: _capturing ? null : _switchCamera,
              icon: const Icon(Icons.cameraswitch),
            ),
        ],
      ),
      body: _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF1A1A1A))),
        ),
      )
          : !ready
          ? const Center(child: CircularProgressIndicator())
          : Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              if (widget.samples > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                      '${_templates.length}/${widget.samples} captured',
                      style: const TextStyle(
                          color: Color(0xFF8A8A8E),
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 8),
              _roundPreview(size),
              const SizedBox(height: 34),
              Text(
                  _identify ? 'Verify to clock in' : 'Align your face',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 8),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  _ring == Colors.red
                      ? _hint
                      : 'Make sure your head is in the circle while we scan your face',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ring == Colors.red
                        ? Colors.red
                        : const Color(0xFF8A8A8E),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              if (_capturing)
                const CircularProgressIndicator()
              else
                SizedBox(
                  width: size * 0.85,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _captureSample,
                    icon: const Icon(Icons.center_focus_strong),
                    label: Text(_identify ? 'Scan now' : 'Capture'),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}


class _RingPainter extends CustomPainter {
  final double progress;
  final bool allGreen;
  final bool error;
  _RingPainter(
      {required this.progress, required this.allGreen, required this.error});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    const ticks = 64;
    const window = 16; // how many ticks light up while scanning
    final base = const Color(0xFFE2E5EC);
    const green = Color(0xFF34C759);
    const blue = Color(0xFF5B7BFA);
    const red = Color(0xFFFF3B30);
    final paint = Paint()..strokeCap = StrokeCap.round;
    final pos = progress * ticks;
    for (int i = 0; i < ticks; i++) {
      final ang = (i / ticks) * 2 * math.pi - math.pi / 2;
      final dir = Offset(math.cos(ang), math.sin(ang));
      final outer = center + dir * radius;
      final inner = center + dir * (radius - 13);
      Color col = base;
      double w = 3;
      if (error) {
        col = red;
        w = 3.5;
      } else if (allGreen) {
        col = green;
        w = 4;
      } else {
        final d = (((i - pos) % ticks) + ticks) % ticks;
        if (d < window) {
          col = blue; // still searching (blue), green only when locked
          w = 4;
        }
      }
      paint
        ..color = col
        ..strokeWidth = w;
      canvas.drawLine(inner, outer, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.progress != progress || o.allGreen != allGreen || o.error != error;
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x559DB4FF)
      ..strokeWidth = 1.4;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), p);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), p);
  }

  @override
  bool shouldRepaint(_CrosshairPainter o) => false;
}