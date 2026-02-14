import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _txt = TextEditingController();

  @override
  void dispose() {
    _txt.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final v = (data?.text ?? "").trim();
    if (v.isNotEmpty) {
      setState(() => _txt.text = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan (Paste Text)"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Messenger စာကို ဒီနေရာမှာ Paste လုပ်ပြီး Continue ကိုနှိပ်ပါ။\n(OCR/Camera ကို နောက်ပိုင်း ထည့်မယ်)",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _paste,
                    icon: const Icon(Icons.paste),
                    label: const Text("Paste"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final out = _txt.text.trim();
                      Navigator.pop(context, out.isEmpty ? null : out);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text("Continue"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _txt,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: "Paste scanned text here…",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
