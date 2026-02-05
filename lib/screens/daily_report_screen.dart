import "../models/ledger_tx.dart";
import "../main.dart";
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DailyReportScreen extends StatefulWidget {
  final String bossId;
  final String bossName;

  const DailyReportScreen({
    super.key,
    required this.bossId,
    required this.bossName,
  });

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {

  List allTx = [];
  List depositTx = [];
  List withdrawTx = [];

  @override
  void initState() {
    super.initState();
    txStore.load();
  }

    final start = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    final end = start + const Duration(days: 1).inMilliseconds;

    allTx = txStore.items
        .where(
          (t) =>
              t.bossId == widget.bossId &&
              !t.deleted &&
              t.dateMs >= start &&
              t.dateMs < end,
        )
        .toList();

    depositTx = allTx.where((t) => t.type == "deposit").toList();
    withdrawTx = allTx.where((t) => t.type == "withdraw").toList();

    setState(() {});
  }



  final NumberFormat moneyFmt = NumberFormat("#,###");

  // TEMP dummy data (နောက်မှ firestore ထဲကယူမယ်)
  final List<Map<String, dynamic>> deposits = [
    {"name": "Vis", "desc": "KBZ Pay", "amount": 10000000, "commission": 0},
  ];

  final List<Map<String, dynamic>> withdraws = [
    {
      "name": "Ko Aung",
      "desc": "Cash Out",
      "amount": 200000,
      "commission": 200,
    },
    {"name": "Su Su", "desc": "WavePay", "amount": 500000, "commission": 500},
  ];

  int get depositCount => deposits.length;
  int get withdrawCount => withdraws.length;
  int get totalCount => depositCount + withdrawCount;

  int get totalDeposit => deposits.fold(
    0,
    (sum, tx) => sum + (tx["amount"] + tx["commission"]) as int,
  );

  int get totalWithdraw => withdraws.fold(
    0,
    (sum, tx) => sum + (tx["amount"] + tx["commission"]) as int,
  );

  int get previousBalance => 0;

  int get closingBalance => previousBalance + totalDeposit - totalWithdraw;

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
    }
  }

  Widget sectionTitle(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget txTable(List<Map<String, dynamic>> list) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Column(
        children: list.map((tx) {
          final total = tx["amount"] + tx["commission"];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(tx["name"])),
                Expanded(child: Text(tx["desc"])),
                Text(moneyFmt.format(total)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget summaryRow(String label, int value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            "${moneyFmt.format(value)} MMK",
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6F8),
      appBar: AppBar(
        title: Text("${widget.bossName} Daily Report"),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Picker
            GestureDetector(
              onTap: pickDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                    ),
                    const Icon(Icons.calendar_month),
                  ],
                ),
              ),
            ),

            // Deposit
            sectionTitle("Total Deposit (ဒီနေ့အဝင်)", Colors.green),
            txTable(deposits),
            const SizedBox(height: 10),
            Text(
              "+${moneyFmt.format(totalDeposit)} MMK",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.green,
              ),
              textAlign: TextAlign.right,
            ),

            // Withdraw
            sectionTitle("Total Withdraw (ဒီနေ့အထွက်)", Colors.red),
            txTable(withdraws),
            const SizedBox(height: 10),
            Text(
              "-${moneyFmt.format(totalWithdraw)} MMK",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.red,
              ),
              textAlign: TextAlign.right,
            ),

            const SizedBox(height: 18),

            // Balance Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  summaryRow("Previous Balance (ယခင်လက်ကျန်)", previousBalance),
                  summaryRow("(+) Total Deposit", totalDeposit),
                  summaryRow("(-) Total Withdraw", totalWithdraw),
                  const Divider(),
                  summaryRow(
                    "Closing Balance (စာရင်းပိတ်ငွေလက်ကျန်)",
                    closingBalance,
                    bold: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Count Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Daily Count Summary",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text("Deposit စောင်ရေ ( $depositCount )"),
                  Text("Withdraw စောင်ရေ ( $withdrawCount )"),
                  Text("Total စောင်ရေ ( $totalCount )"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Ledger TX Wiring =====

    final dayStart = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    final dayEnd = dayStart + Duration(days: 1).inMilliseconds;

        .where(
          (t) =>
              t.bossId == widget.bossId &&
              !t.deleted &&
              t.dateMs >= dayStart &&
              t.dateMs < dayEnd,
        )
        .toList();

  }
}

// === TX TABLES ===

Widget _txTable(List<LedgerTx> list, Color color) {
  return _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Expanded(
              flex: 2,
              child: Text(
                "နာမည်",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                "အကြောင်းအရာ",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Text(
                "ငွေ",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Text(
                "ကော်မရှင်",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Text(
                "စုစုပေါင်း",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const Divider(),
        SizedBox(
          height: 220,
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final t = list[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        t.personName,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        t.description,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _fmt(t.amountKs),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _fmt(t.commissionKs),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _fmt(t.totalKs),
                        style: TextStyle(fontSize: 12, color: color),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
