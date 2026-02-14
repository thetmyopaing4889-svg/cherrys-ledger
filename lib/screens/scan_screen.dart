import 'package:flutter/material.dart';

class ScanScreen extends StatefulWidget {
  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  String scannedText = "";

  Future<void> _startScan() async {
    // TODO: integrate OCR later
    setState(() {
      scannedText = "09420036948 kp U Ramesh Kumar သင့်ငွေ 30";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Scan Messenger Text")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _startScan,
            child: Text("Start Scan"),
          ),
          Text(scannedText),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, scannedText);
            },
            child: Text("Use Result"),
          ),
        ],
      ),
    );
  }
}
