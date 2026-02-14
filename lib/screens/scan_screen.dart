import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
  String _lastText = "";
  bool _streaming = false;

  @override
  void initState() {
    super.initState();
    _ocr = TextRecognizer(script: TextRecognitionScript.latin);
    _initCam();
  }

  Future<void> _initCam() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      final ctrl = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await ctrl.initialize();
      if (!mounted) return;

      setState(() => _cam = ctrl);

      // start stream
      await _cam!.startImageStream(_onFrame);
      _streaming = true;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Camera init failed: $e")),
      );
    }
  }

  InputImageRotation _rotationFromDeg(int deg) {
    switch (deg) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _onFrame(CameraImage img) async {
    if (_busy || !mounted) return;
    _busy = true;

    try {
      final cam = _cam;
      if (cam == null) return;

      // bytes
      final bytes = Uint8List.fromList(img.planes.expand((p) => p.bytes).toList());
// meta
      final ui.Size size = ui.Size(img.width.toDouble(), img.height.toDouble());

      final rotation = _rotationFromDeg(cam.description.sensorOrientation);

      final format =
          InputImageFormatValue.fromRawValue(img.format.raw) ??
              InputImageFormat.yuv420;

      final meta = InputImageMetadata(
        size: size,
        rotation: rotation,
        format: format,
        bytesPerRow: img.planes.first.bytesPerRow,
      );

      final input = InputImage.fromBytes(bytes: bytes, metadata: meta);

      final result = await _ocr.processImage(input);
      final text = result.text.trim();

      if (text.isNotEmpty && mounted) {
        setState(() => _lastText = text);
      }
    } catch (_) {
      // ignore frame errors (keep stream alive)
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    () async {
      try {
        if (_streaming) {
          await _cam?.stopImageStream();
        }
      } catch (_) {}
      await _cam?.dispose();
      await _ocr.close();
    }();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Scan"),
        actions: [
          IconButton(
            tooltip: "Use",
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, _lastText);
            },
          ),
        ],
      ),
      body: cam == null || !cam.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                CameraPreview(cam),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.black.withOpacity(0.55),
                    child: Text(
                      _lastText.isEmpty ? "Scanning..." : _lastText,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
