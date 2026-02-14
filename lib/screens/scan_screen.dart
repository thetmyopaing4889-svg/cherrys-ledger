import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _cam;
  late final TextRecognizer _ocr;
  bool _busy = false;
  bool _ready = false;

  // Throttle OCR so it stays fast + stable
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _ocr = TextRecognizer(script: TextRecognitionScript.latin);
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) Navigator.pop(context, null);
        return;
      }

      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      final ctrl = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await ctrl.initialize();
      await ctrl.startImageStream(_onFrame);

      if (!mounted) return;
      setState(() {
        _cam = ctrl;
        _ready = true;
      });
    } catch (_) {
      if (mounted) Navigator.pop(context, null);
    }
  }

  Future<void> _onFrame(CameraImage img) async {
    if (_busy) return;

    final now = DateTime.now();
    if (now.difference(_lastRun).inMilliseconds < 650) return; // throttle
    _lastRun = now;

    _busy = true;
    try {
      final ctrl = _cam;
      if (ctrl == null) return;

      final input = _toInputImage(img, ctrl.description.sensorOrientation);
      final res = await _ocr.processImage(input);

      final text = (res.text).trim();
      if (text.isNotEmpty && mounted) {
        // Return raw OCR text to NewTransaction screen
        await _stopStream();
        Navigator.pop(context, text);
      }
    } catch (_) {
      // ignore frame errors
    } finally {
      _busy = false;
    }
  }

  InputImage _toInputImage(CameraImage img, int rotationDeg) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final p in img.planes) {
      allBytes.putUint8List(p.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final size = Size(img.width.toDouble(), img.height.toDouble());

    final rotation = switch (rotationDeg) {
      90 => InputImageRotation.rotation90deg,
      180 => InputImageRotation.rotation180deg,
      270 => InputImageRotation.rotation270deg,
      _ => InputImageRotation.rotation0deg,
    };

    final format = InputImageFormat.nv21; // yuv420 on Android usually maps ok
    final planeData = img.planes
        .map((p) => InputImagePlaneMetadata(
              bytesPerRow: p.bytesPerRow,
              height: p.height,
              width: p.width,
            ))
        .toList();

    final meta = InputImageMetadata(
      size: size,
      rotation: rotation,
      format: format,
      bytesPerRow: img.planes.first.bytesPerRow,
      planeData: planeData,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: meta);
  }

  Future<void> _stopStream() async {
    final ctrl = _cam;
    if (ctrl == null) return;
    try {
      await ctrl.stopImageStream();
    } catch (_) {}
  }

  @override
  void dispose() {
    _ocr.close();
    final ctrl = _cam;
    _cam = null;
    if (ctrl != null) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Scan"),
      ),
      body: !_ready || _cam == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                CameraPreview(_cam!),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.black.withOpacity(0.35),
                    child: const Text(
                      "Messenger message ကို camera နဲ့ တန်းဖတ်ပါ\nText တွေ့တာနဲ့ auto-fill သွားမယ်",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
