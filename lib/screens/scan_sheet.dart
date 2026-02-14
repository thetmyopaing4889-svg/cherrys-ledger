import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ScanSheet extends StatefulWidget {
  const ScanSheet({super.key});

  @override
  State<ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<ScanSheet> {
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
        ResolutionPreset.veryHigh,
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
      final file = await c.takePicture();
      final img = InputImage.fromFilePath(file.path);
      final res = await _ocr.processImage(img);

      final out = res.text.trim();
      if (mounted) setState(() => _text = out);

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
    // sheet height ~ 75% screen
    final h = MediaQuery.of(context).size.height * 0.75;

    return SizedBox(
      height: h,
      child: Column(
        children: [
          // top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text("Live Scan", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                IconButton(
                  tooltip: "Torch",
                  onPressed: _toggleTorch,
                  icon: Icon(_torch ? Icons.flash_on : Icons.flash_off),
                ),
                IconButton(
                  tooltip: "Close",
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // camera preview area
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black12,
              ),
              clipBehavior: Clip.antiAlias,
              child: !_ready
                  ? Center(child: Text(_text.isNotEmpty ? _text : "Opening camera..."))
                  : CameraPreview(_cam!),
            ),
          ),

          const SizedBox(height: 10),

          // buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _scanOnce,
                    icon: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.document_scanner),
                    label: Text(_busy ? "Scanning..." : "Scan"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _text.trim().isEmpty ? null : () => Navigator.pop(context, _text),
                    icon: const Icon(Icons.check),
                    label: const Text("Use"),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // result preview
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.black.withOpacity(0.05),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
              ),
              child: Text(
                _text.isEmpty ? "Result will show here..." : _text,
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
