import 'dart:io';

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
  bool _ready = false;
  bool _busy = false;
  bool _torch = false;

  String _text = "";

  late final TextRecognizer _ocr;

  @override
  void initState() {
    super.initState();
    _ocr = TextRecognizer(script: TextRecognitionScript.latin);
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      final ctrl = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await ctrl.initialize();
      await ctrl.setFocusMode(FocusMode.auto);
      await ctrl.setExposureMode(ExposureMode.auto);

      if (!mounted) return;
      setState(() {
        _cam = ctrl;
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ready = false;
        _text = "Camera init error: $e";
      });
    }
  }

  Future<void> _toggleTorch() async {
    final c = _cam;
    if (c == null) return;
    try {
      _torch = !_torch;
      await c.setFlashMode(_torch ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _scanOnce() async {
    final c = _cam;
    if (c == null || _busy) return;

    setState(() => _busy = true);
    try {
      // capture
      final file = await c.takePicture();

      // OCR
      final img = InputImage.fromFilePath(file.path);
      final res = await _ocr.processImage(img);

      final out = (res.text).trim();
      if (mounted) {
        setState(() {
          _text = out;
        });
      }

      // cleanup temp file
      try {
        final f = File(file.path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    } catch (e) {
      if (mounted) setState(() => _text = "Scan error: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _ocr.close();
    _cam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Live Scan"),
        backgroundColor: const Color(0xFFFFF3F7),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: "Done",
            icon: const Icon(Icons.check),
            onPressed: _text.trim().isEmpty ? null : () => Navigator.pop(context, _text),
          ),
        ],
      ),
      body: !_ready
          ? Center(
              child: Text(
                _text.isNotEmpty ? _text : "Opening camera...",
                style: const TextStyle(color: Colors.white),
              ),
            )
          : Stack(
              children: [
                Positioned.fill(child: CameraPreview(_cam!)),

                // bottom panel
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                    decoration: const BoxDecoration(
                      color: Color(0xCC000000),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _busy ? null : _scanOnce,
                                icon: _busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.document_scanner),
                                label: Text(_busy ? "Scanning..." : "Scan"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              tooltip: "Torch",
                              onPressed: _toggleTorch,
                              icon: Icon(_torch ? Icons.flash_on : Icons.flash_off, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.15)),
                          ),
                          child: Text(
                            _text.isEmpty ? "Tap Scan to read text..." : _text,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
