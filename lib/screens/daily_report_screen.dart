import "../main.dart";
import "../models/ledger_tx.dart";
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
  final NumberFormat moneyFmt = NumberFormat("#,###");
  final DateFormat dateFmt = DateFormat("d/M/yyyy");

  DateTime selectedDate = DateTime.now();

  List<LedgerTx> allTx = [];
  List<LedgerTx> depositTx = [];
  List<LedgerTx> withdrawTx = [];

  @override
  void initState() {
    super.initState();
    txStore.load().then((_) {
      bossStore.load().then((_) {
        _reloadForSelectedDay();
      });
    });
  }

  int _bossOpeningBalance() {
    final b = bossStore.getById(widget.bossId);
    if (b == null) return 0;
    // boss model မှာ openingBalanceMmk field သုံးထားပြီးသား
    return b.openingBalanceMmk;
  }

  int _balanceBeforeDay(int dayStartMs) {
    final opening = _bossOpeningBalance();

    final prevAll = txStore
        .listByBoss(widget.bossId)
        .where((t) => !t.deleted && t.dateMs < dayStartMs);

    final dep = prevAll
        .where((t) => t.type == "deposit")
        .fold<int>(0, (s, t) => s + t.totalKs);

    final wd = prevAll
        .where((t) => t.type == "withdraw")
        .fold<int>(0, (s, t) => s + t.totalKs);

    return opening + dep - wd;
  }

  void _reloadForSelectedDay() {
    final d = selectedDate;
    final start = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    final end = start + const Duration(days: 1).inMilliseconds;

    allTx = txStore
        .listByBoss(widget.bossId)
        .where((t) => !t.deleted && t.dateMs >= start && t.dateMs < end)
        .toList()
      ..sort((a, b) => a.seqNo.compareTo(b.seqNo));

    depositTx = allTx.where((t) => t.type == "deposit").toList();
    withdrawTx = allTx.where((t) => t.type == "withdraw").toList();

    if (mounted) setState(() {});
  }

  int get depositCount => depositTx.length;
  int get withdrawCount => withdrawTx.length;
  int get totalCount => depositCount + withdrawCount;

  int get totalDeposit => depositTx.fold<int>(0, (s, t) => s + t.totalKs);
  int get totalWithdraw => withdrawTx.fold<int>(0, (s, t) => s + t.totalKs);

  int get previousBalance {
    final d = selectedDate;
    final start = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    return _balanceBeforeDay(start);
  }

  int get subTotal => previousBalance + totalDeposit;
  int get closingBalance => subTotal - totalWithdraw;

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
      _reloadForSelectedDay();
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

  Widget _totalRow(int amountSum, int commSum, int totalSum) {
    const bold = TextStyle(fontSize: 12, fontWeight: FontWeight.w900);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6F8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFCFE0)),
        ),
        child: Row(
          children: [
            const Expanded(
              flex: 2,
              child: Text("Total", style: bold),
            ),
            Expanded(
              flex: 2,
              child: Text(moneyFmt.format(amountSum), style: bold, textAlign: TextAlign.right),
            ),
            Expanded(
              flex: 2,
              child: Text(moneyFmt.format(commSum), style: bold, textAlign: TextAlign.right),
            ),
            Expanded(
              flex: 2,
              child: Text(moneyFmt.format(totalSum), style: bold, textAlign: TextAlign.right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _table(List<LedgerTx> list) {
    if (list.isEmpty) {
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
        child: const Text("No transactions"),
      );
    }

    final headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w900,
      color: Colors.black.withOpacity(0.65),
    );
    const cellStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);

    final amountSum = list.fold<int>(0, (s, t) => s + t.amountKs);
    final commSum = list.fold<int>(0, (s, t) => s + t.commissionKs);
    final totalSum = list.fold<int>(0, (s, t) => s + t.totalKs);

    return Container(
      padding: const EdgeInsets.all(10),
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
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 14,
              headingRowHeight: 32,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 52,
              columns: [
                DataColumn(label: Text("နာမည်", style: headerStyle)),
                DataColumn(label: Text("အကြောင်းအရာ", style: headerStyle)),
                DataColumn(label: Text("ငွေပမာဏ", style: headerStyle), numeric: true),
                DataColumn(label: Text("ကော်မရှင်", style: headerStyle), numeric: true),
                DataColumn(label: Text("စုစုပေါင်းငွေ", style: headerStyle), numeric: true),
              ],
              rows: list.map((t) {
                return DataRow(
                  cells: [
                    DataCell(Text(t.personName, style: cellStyle)),
                    DataCell(Text(t.description, style: cellStyle)),
                    DataCell(Text(moneyFmt.format(t.amountKs), style: cellStyle)),
                    DataCell(Text(moneyFmt.format(t.commissionKs), style: cellStyle)),
                    DataCell(
                      Text(
                        moneyFmt.format(t.totalKs),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          _totalRow(amountSum, commSum, totalSum),
        ],
      ),
    );
  }

  Widget summaryRow(String label, int value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          Text(
            "${moneyFmt.format(value)} MMK",
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
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
      child: child,
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
            // Date picker
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
                      "Date: ${dateFmt.format(selectedDate)}",
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Icon(Icons.calendar_month),
                  ],
                ),
              ),
            ),

            sectionTitle("Total Deposit (ဒီနေ့အဝင်)", Colors.green),
            _table(depositTx),

            const SizedBox(height: 14),

            sectionTitle("Total Withdraw (ဒီနေ့အထွက်)", Colors.red),
            _table(withdrawTx),

            sectionTitle("Summary", const Color(0xFF333333)),

            // Card 1: calculation (order မမှားအောင်)
            _card(
              Column(
                children: [
                  summaryRow("Previous Balance (ယခင်လက်ကျန်)", previousBalance),
                  summaryRow("Total Deposit (ဒီနေ့အဝင်)", totalDeposit),
                  summaryRow("Sub Total", subTotal, bold: true),
                  summaryRow("Total Withdraw (ဒီနေ့အထွက်)", totalWithdraw),
                  const Divider(),
                  summaryRow(
                    "Closing Balance (စာရင်းပိတ်ငွေလက်ကျန်)",
                    closingBalance,
                    bold: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Card 2: counts (အောက်ဆုံးမှ ပြ)
            _card(
              Column(
                children: [
                  _countRow("Deposit စောင်ရေ", depositCount),
                  _countRow("Withdraw စောင်ရေ", withdrawCount),
                  _countRow("Total စောင်ရေ", totalCount, bold: true),
                ],
              ),
            ),

            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }
}

Widget _countRow(String label, int value, {bool bold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label)),
        Text(
          value.toString(),
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
