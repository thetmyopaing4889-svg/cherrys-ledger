import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CherryLedgerApp());
}

class CherryLedgerApp extends StatelessWidget {
  const CherryLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Cherry's Ledger",
      home: const WelcomeScreen(),
    );
  }
}
