import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'state/boss_store.dart';
import 'state/tx_store.dart';

final bossStore = BossStore();
final txStore = TxStore();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CherrysLedgerApp());
}

class CherrysLedgerApp extends StatelessWidget {
  const CherrysLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Cherry's Ledger",
      theme: ThemeData(
        fontFamily: 'NotoSansMyanmar',
        scaffoldBackgroundColor: const Color(0xFFFFF3F7),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF2D55)),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}
