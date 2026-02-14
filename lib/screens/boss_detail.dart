ElevatedButton(
  onPressed: () async {
    final scannedText = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ScanScreen()),
    );
    if (scannedText != null) {
      final parsedData = OcrParser.parse(scannedText);
      openTransactionForm(context, parsedData);
    }
  },
  child: Text("Scan"),
),
