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
import 'package:cherrys_ledger/screens/scan_screen.dart';
import 'package:cherrys_ledger/utils/ocr_parser.dart';
import 'package:cherrys_ledger/screens/transaction_form.dart';

ElevatedButton(
  onPressed: () async {
    final scannedText = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ScanScreen()),
    );
    if (scannedText != null) {
      final parsedData = OcrParser.parse(scannedText);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TransactionForm(
            phone: parsedData["phone"],
            name: parsedData["name"],
            method: parsedData["method"],
            amount: parsedData["amount"],
            commission: parsedData["commission"],
          ),
        ),
      );
    }
  },
  child: Text("Scan"),
),
