import 'dart:io';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../models/ledger_tx.dart';

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

  final GlobalKey _captureKey = GlobalKey();
  bool _exporting = false;

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

  int get totalDeposit =>
      depositTx.fold<int>(0, (s, t) => s + t.totalKs);
  int get totalWithdraw =>
      withdrawTx.fold<int>(0, (s, t) => s + t.totalKs);

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

  Widget summaryRow(
    String label,
    int value, {
    bool bold = false,
    bool money = true,
  }) {
    final text = money ? "${moneyFmt.format(value)} MMK" : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          Text(
            text,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(int amountSum, int commSum, int totalSum) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "Total",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              moneyFmt.format(amountSum),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              moneyFmt.format(commSum),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              moneyFmt.format(totalSum),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _table(List<LedgerTx> txs) {
    final amountSum = txs.fold<int>(0, (s, t) => s + t.amountKs);
    final commSum = txs.fold<int>(0, (s, t) => s + t.commissionKs);
    final totalSum = txs.fold<int>(0, (s, t) => s + t.totalKs);

    if (txs.isEmpty) {
      return _card(
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            "No transactions for this day.",
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
          ),
        ),
      );
    }

    return _card(
      Column(
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  "No",
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  "Amount",
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: Text(
                  "Comm",
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: Text(
                  "Total",
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 6),
          ...txs.map((t) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "#${t.seqNo}",
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text(
                      moneyFmt.format(t.amountKs),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 110,
                    child: Text(
                      moneyFmt.format(t.commissionKs),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 110,
                    child: Text(
                      moneyFmt.format(t.totalKs),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 10),
          _totalRow(amountSum, commSum, totalSum),
        ],
      ),
    );
  }

  String _safeName(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');

  String _txAccountLabel(LedgerTx t) {
    // LedgerTx field name မတူနိုင်လို့ dynamic နဲ႔ safe try
    final d = t as dynamic;
    try {
      final v = d.accountName;
      if (v != null) return v.toString();
    } catch (_) {}
    try {
      final v = d.account;
      if (v != null) return v.toString();
    } catch (_) {}
    try {
      final v = d.name;
      if (v != null) return v.toString();
    } catch (_) {}
    try {
      final v = d.note;
      if (v != null) return v.toString();
    } catch (_) {}
    return "";
  }

  Future<XFile> _exportJpeg() async {
    final boundary = _captureKey.currentContext!
        .findRenderObject() as RenderRepaintBoundary;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final d = selectedDate;

    final file = File(
      "${dir.path}/${_safeName(widget.bossName)}_${d.year}-${d.month}-${d.day}_daily.png",
    );
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path);
  }

  Future<XFile> _exportExcel() async {
    final excel = xl.Excel.createExcel();
    final sheet = excel["DailyReport"];
    final d = selectedDate;

    sheet.appendRow([
      xl.TextCellValue("Boss"),
      xl.TextCellValue(widget.bossName),
    ]);
    sheet.appendRow([
      xl.TextCellValue("Date"),
      xl.TextCellValue("${d.year}-${d.month}-${d.day}"),
    ]);
    sheet.appendRow([xl.TextCellValue(""), xl.TextCellValue("")]);

    sheet.appendRow([
      xl.TextCellValue("DEPOSIT"),
      xl.TextCellValue("Account"),
      xl.TextCellValue("Amount"),
      xl.TextCellValue("Commission"),
      xl.TextCellValue("Total"),
    ]);
    for (final t in depositTx) {
      sheet.appendRow([
        xl.TextCellValue("D"),
        xl.TextCellValue(_txAccountLabel(t)),
        xl.IntCellValue(t.amountKs),
        xl.IntCellValue(t.commissionKs),
        xl.IntCellValue(t.totalKs),
      ]);
    }
    sheet.appendRow([
      xl.TextCellValue(""),
      xl.TextCellValue("TotalDeposit"),
      xl.IntCellValue(totalDeposit),
    ]);

    sheet.appendRow([xl.TextCellValue(""), xl.TextCellValue("")]);

    sheet.appendRow([
      xl.TextCellValue("WITHDRAW"),
      xl.TextCellValue("Account"),
      xl.TextCellValue("Amount"),
      xl.TextCellValue("Commission"),
      xl.TextCellValue("Total"),
    ]);
    for (final t in withdrawTx) {
      sheet.appendRow([
        xl.TextCellValue("W"),
        xl.TextCellValue(_txAccountLabel(t)),
        xl.IntCellValue(t.amountKs),
        xl.IntCellValue(t.commissionKs),
        xl.IntCellValue(t.totalKs),
      ]);
    }
    sheet.appendRow([
      xl.TextCellValue(""),
      xl.TextCellValue("TotalWithdraw"),
      xl.IntCellValue(totalWithdraw),
    ]);

    sheet.appendRow([xl.TextCellValue(""), xl.TextCellValue("")]);

    sheet.appendRow([
      xl.TextCellValue("Summary"),
      xl.TextCellValue("Previous"),
      xl.IntCellValue(previousBalance),
    ]);
    sheet.appendRow([
      xl.TextCellValue("Summary"),
      xl.TextCellValue("Deposit"),
      xl.IntCellValue(totalDeposit),
    ]);
    sheet.appendRow([
      xl.TextCellValue("Summary"),
      xl.TextCellValue("SubTotal"),
      xl.IntCellValue(subTotal),
    ]);
    sheet.appendRow([
      xl.TextCellValue("Summary"),
      xl.TextCellValue("Withdraw"),
      xl.IntCellValue(totalWithdraw),
    ]);
    sheet.appendRow([
      xl.TextCellValue("Summary"),
      xl.TextCellValue("Closing"),
      xl.IntCellValue(closingBalance),
    ]);

    final bytes = excel.encode()!;
    final dir = await getTemporaryDirectory();
    final file = File(
      "${dir.path}/${_safeName(widget.bossName)}_${d.year}-${d.month}-${d.day}_daily.xlsx",
    );
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path);
  }

  Future<void> _showExport() async {
    if (_exporting) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text("Export JPEG"),
                onTap: () async {
                  Navigator.pop(context);
                  setState(() => _exporting = true);
                  try {
                    final img = await _exportJpeg();
                    await Share.shareXFiles(
                      [img],
                      text: "${widget.bossName} Daily Report",
                    );
                  } finally {
                    if (mounted) setState(() => _exporting = false);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text("Export Excel"),
                onTap: () async {
                  Navigator.pop(context);
                  setState(() => _exporting = true);
                  try {
                    final xlsx = await _exportExcel();
                    await Share.shareXFiles(
                      [xlsx],
                      text: "${widget.bossName} Daily Report",
                    );
                  } finally {
                    if (mounted) setState(() => _exporting = false);
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
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
      body: RepaintBoundary(
        key: _captureKey,
        child: SingleChildScrollView(
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
                    summaryRow(
                      "Previous Balance (ယခင်လက်ကျန်)",
                      previousBalance,
                    ),
                    summaryRow(
                      "Total Deposit (ဒီနေ့အဝင်)",
                      totalDeposit,
                    ),
                    // ✅ underline between Deposit and SubTotal
                    const Divider(),
                    summaryRow("Sub Total", subTotal, bold: true),
                    summaryRow(
                      "Total Withdraw (ဒီနေ့အထွက်)",
                      totalWithdraw,
                    ),
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

              // Card 2: counts (MMK မပြ)
              _card(
                Column(
                  children: [
                    summaryRow("Deposit စောင်ရေ", depositCount, money: false),
                    summaryRow("Withdraw စောင်ရေ", withdrawCount, money: false),
                    summaryRow(
                      "Total စောင်ရေ",
                      totalCount,
                      bold: true,
                      money: false,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _exporting ? null : _showExport,
                  icon: const Icon(Icons.ios_share),
                  label: Text(_exporting
                      ? "Exporting..."
                      : "Export (JPEG / Excel)"),
                ),
              ),

              const SizedBox(height: 22),
            ],
          ),
        ),
      ),
    );
  }
}
