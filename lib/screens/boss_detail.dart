import 'package:flutter/material.dart';
import 'package:cherrys_ledger/screens/scan_screen.dart';
import 'package:cherrys_ledger/utils/ocr_parser.dart';
import 'package:cherrys_ledger/screens/transaction_form.dart';

class BossDetail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Boss A")),
      body: Column(
        children: [
          Text("Current Balance (MMK)"),
          Text("Phone"),
          Text("Address"),

          // ✅ Scan ခလုတ်
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

          // Existing buttons
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TransactionForm()),
              );
            },
            child: Text("New Transaction"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, "/reports");
            },
            child: Text("Reports"),
          ),
        ],
      ),
    );
  }
}
