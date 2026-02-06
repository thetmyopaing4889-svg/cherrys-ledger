import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cherrys_ledger/models/ledger_tx.dart';
import 'package:cross_file/cross_file.dart';
import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DailyReportExportScreen extends StatefulWidget {
  final String bossName;
  final DateTime date;

  final List<LedgerTx> depositTx;
  final List<LedgerTx> withdrawTx;

  final int previousBalance;
  final int totalDeposit;
  final int subTotal;
  final int totalWithdraw;
  final int closingBalance;

  const DailyReportExportScreen({
    super.key,
    required this.bossName,
    required this.date,
    required this.depositTx,
    required this.withdrawTx,
    required this.previousBalance,
    required this.totalDeposit,
    required this.subTotal,
    required this.totalWithdraw,
    required this.closingBalance,
  });

  @override
  State<DailyReportExportScreen> createState() => _DailyReportExportScreenState();
}

class _DailyReportExportScreenState extends State<DailyReportExportScreen> {
  final _moneyFmt = NumberFormat("#,###");
  final _dateFmt = DateFormat("d/M/yyyy");

  bool _exporting = false;

  // phone full-screen pages
  static const int _rowsPerPage = 10;

  String _safeName(String s) => s.replaceAll(RegExp(r"[^A-Za-z0-9_\-]+"), "_");

  String _ymd(DateTime d) {
    final mm = d.month.toString().padLeft(2, "0");
    final dd = d.day.toString().padLeft(2, "0");
    return "${d.year}-$mm-$dd";
  }

  List<List<LedgerTx>> _chunk(List<LedgerTx> list) {
    if (list.isEmpty) return const [];
    final out = <List<LedgerTx>>[];
    for (int i = 0; i < list.length; i += _rowsPerPage) {
      out.add(list.sublist(i, math.min(i + _rowsPerPage, list.length)));
    }
    return out;
  }

  late final List<List<LedgerTx>> _depPages = _chunk(widget.depositTx);
  late final List<List<LedgerTx>> _wdPages = _chunk(widget.withdrawTx);

  int get _depCount => _depPages.isEmpty ? 1 : _depPages.length;
  int get _wdCount => _wdPages.isEmpty ? 1 : _wdPages.length;
  int get _pageCount => _depCount + _wdCount + 1; // + summary

  bool _isDepositPage(int idx) => idx < _depCount;
  bool _isWithdrawPage(int idx) => idx >= _depCount && idx < (_depCount + _wdCount);
  bool _isSummaryPage(int idx) => idx == _pageCount - 1;

  List<LedgerTx> _depositSliceFor(int idx) {
    if (_depPages.isEmpty) return const [];
    return _depPages[idx];
  }

  List<LedgerTx> _withdrawSliceFor(int idx) {
    if (_wdPages.isEmpty) return const [];
    return _wdPages[idx - _depCount];
  }

  late final PageController _pageCtrl = PageController();
  late final List<GlobalKey> _pageKeys = List.generate(_pageCount, (_) => GlobalKey());

  // ---------- UI blocks ----------
  Widget _watermark() {
    return IgnorePointer(
      child: Center(
        child: Transform.rotate(
          angle: -15 * math.pi / 180,
          child: Opacity(
            opacity: 0.07,
            child: Text(
              "CHERRY’S LEDGER",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Text(
          "Cherry’s Ledger",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF9F1239),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "Daily Report – ${_dateFmt.format(widget.date)}",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          "Boss: ${widget.bossName}",
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: Colors.black.withOpacity(0.12)),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _sectionTitle(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _table(List<LedgerTx> list) {
    final headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w900,
      color: Colors.black.withOpacity(0.65),
    );
    const cellStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);

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
                    DataCell(Text(_moneyFmt.format(t.amountKs), style: cellStyle)),
                    DataCell(Text(_moneyFmt.format(t.commissionKs), style: cellStyle)),
                    DataCell(
                      Text(
                        _moneyFmt.format(t.totalKs),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          _totalRow(amountSum, commSum, totalSum),
        ],
      ),
    );
  }

  Widget _totalRow(int amountSum, int commSum, int totalSum) {
    const bold = TextStyle(fontSize: 12, fontWeight: FontWeight.w900);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCFE0)),
      ),
      child: Row(
        children: [
          const Expanded(flex: 2, child: Text("Total", style: bold)),
          Expanded(flex: 2, child: Text(_moneyFmt.format(amountSum), style: bold, textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(_moneyFmt.format(commSum), style: bold, textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(_moneyFmt.format(totalSum), style: bold, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    Widget row(String label, String value, {bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label)),
            Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700)),
          ],
        ),
      );
    }

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
        children: [
          row("Previous Balance (ယခင်လက်ကျန်)", "${_moneyFmt.format(widget.previousBalance)} MMK"),
          row("Total Deposit (ဒီနေ့အဝင်)", "${_moneyFmt.format(widget.totalDeposit)} MMK"),
          const Divider(),
          row("Sub Total", "${_moneyFmt.format(widget.subTotal)} MMK", bold: true),
          row("Total Withdraw (ဒီနေ့အထွက်)", "${_moneyFmt.format(widget.totalWithdraw)} MMK"),
          const Divider(),
          row("Closing Balance (စာရင်းပိတ်ငွေလက်ကျန်)", "${_moneyFmt.format(widget.closingBalance)} MMK", bold: true),
        ],
      ),
    );
  }

  // ---------- export helpers ----------
  Future<File> _writeJpgFromBoundary(GlobalKey key, String path) async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;

    // higher quality for messenger (still phone full-screen)
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final decoded = img.decodeImage(pngBytes);
    if (decoded == null) {
      // fallback to png
      final f = File(path.replaceAll(".jpg", ".png"));
      await f.writeAsBytes(pngBytes, flush: true);
      return f;
    }

    final jpgBytes = img.encodeJpg(decoded, quality: 92);
    final f = File(path);
    await f.writeAsBytes(jpgBytes, flush: true);
    return f;
  }

  Future<List<XFile>> _exportAllPagesAsJpeg() async {
    final dir = await getApplicationDocumentsDirectory();
    final base = "DailyReport_${_safeName(widget.bossName)}_${_ymd(widget.date)}";
    final out = <XFile>[];

    for (int i = 0; i < _pageCount; i++) {
      // make sure page is visible before capture
      await _pageCtrl.animateToPage(i, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      await Future.delayed(const Duration(milliseconds: 260));

      final p = (i + 1).toString().padLeft(2, "0");
      final n = _pageCount.toString().padLeft(2, "0");
      final path = "${dir.path}/${base}_p${p}of${n}.jpg";

      final file = await _writeJpgFromBoundary(_pageKeys[i], path);
      out.add(XFile(file.path));
    }
    return out;
  }

  Future<XFile> _exportExcel() async {
    final excel = xls.Excel.createExcel();
    final sheet = excel["DailyReport"];

    sheet.appendRow([xls.TextCellValue("Cherry’s Ledger")]);
    sheet.appendRow([xls.TextCellValue("Boss"), xls.TextCellValue(widget.bossName)]);
    sheet.appendRow([xls.TextCellValue("Date"), xls.TextCellValue(_ymd(widget.date))]);
    sheet.appendRow([xls.TextCellValue("")]);

    sheet.appendRow([
      xls.TextCellValue("DEPOSIT"),
      xls.TextCellValue("Name"),
      xls.TextCellValue("Description"),
      xls.TextCellValue("Amount"),
      xls.TextCellValue("Commission"),
      xls.TextCellValue("Total"),
    ]);
    for (final t in widget.depositTx) {
      sheet.appendRow([
        xls.TextCellValue("D"),
        xls.TextCellValue(t.personName),
        xls.TextCellValue(t.description),
        xls.IntCellValue(t.amountKs),
        xls.IntCellValue(t.commissionKs),
        xls.IntCellValue(t.totalKs),
      ]);
    }

    sheet.appendRow([xls.TextCellValue("")]);
    sheet.appendRow([
      xls.TextCellValue("WITHDRAW"),
      xls.TextCellValue("Name"),
      xls.TextCellValue("Description"),
      xls.TextCellValue("Amount"),
      xls.TextCellValue("Commission"),
      xls.TextCellValue("Total"),
    ]);
    for (final t in widget.withdrawTx) {
      sheet.appendRow([
        xls.TextCellValue("W"),
        xls.TextCellValue(t.personName),
        xls.TextCellValue(t.description),
        xls.IntCellValue(t.amountKs),
        xls.IntCellValue(t.commissionKs),
        xls.IntCellValue(t.totalKs),
      ]);
    }

    sheet.appendRow([xls.TextCellValue("")]);
    sheet.appendRow([xls.TextCellValue("Summary"), xls.TextCellValue("Previous"), xls.IntCellValue(widget.previousBalance)]);
    sheet.appendRow([xls.TextCellValue("Summary"), xls.TextCellValue("Deposit"), xls.IntCellValue(widget.totalDeposit)]);
    sheet.appendRow([xls.TextCellValue("Summary"), xls.TextCellValue("SubTotal"), xls.IntCellValue(widget.subTotal)]);
    sheet.appendRow([xls.TextCellValue("Summary"), xls.TextCellValue("Withdraw"), xls.IntCellValue(widget.totalWithdraw)]);
    sheet.appendRow([xls.TextCellValue("Summary"), xls.TextCellValue("Closing"), xls.IntCellValue(widget.closingBalance)]);

    final bytes = excel.encode()!;
    final dir = await getApplicationDocumentsDirectory();
    final path = "${dir.path}/DailyReport_${_safeName(widget.bossName)}_${_ymd(widget.date)}.xlsx";
    final f = File(path);
    await f.writeAsBytes(bytes, flush: true);
    return XFile(f.path);
  }

  Future<void> _showExportSheet() async {
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
                title: const Text("Export JPEG (Multi-page)"),
                onTap: () async {
                  Navigator.pop(context);
                  setState(() => _exporting = true);
                  try {
                    final files = await _exportAllPagesAsJpeg();
                    await Share.shareXFiles(files, text: "${widget.bossName} Daily Report ${_ymd(widget.date)}");
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
                    final file = await _exportExcel();
                    await Share.shareXFiles([file], text: "${widget.bossName} Daily Report ${_ymd(widget.date)}");
                  } finally {
                    if (mounted) setState(() => _exporting = false);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text("Export Both (JPEG + Excel)"),
                onTap: () async {
                  Navigator.pop(context);
                  setState(() => _exporting = true);
                  try {
                    final imgs = await _exportAllPagesAsJpeg();
                    final xlsx = await _exportExcel();
                    await Share.shareXFiles([...imgs, xlsx], text: "${widget.bossName} Daily Report ${_ymd(widget.date)}");
                  } finally {
                    if (mounted) setState(() => _exporting = false);
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _pageContainer({required int pageIndex, required Widget child}) {
    return RepaintBoundary(
      key: _pageKeys[pageIndex],
      child: Container(
        color: const Color(0xFFFFF6F8),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Stack(
          children: [
            _watermark(),
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  Expanded(child: child),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Page ${pageIndex + 1}/$_pageCount",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black.withOpacity(0.55)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepositPage(int idx) {
    final slice = _depositSliceFor(idx);
    return _pageContainer(
      pageIndex: idx,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Total Deposit (ဒီနေ့အဝင်)", Colors.green),
          _table(slice),
        ],
      ),
    );
  }

  Widget _buildWithdrawPage(int idx) {
    final slice = _withdrawSliceFor(idx);
    return _pageContainer(
      pageIndex: idx,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Total Withdraw (ဒီနေ့အထွက်)", Colors.red),
          _table(slice),
        ],
      ),
    );
  }

  Widget _buildSummaryPage(int idx) {
    return _pageContainer(
      pageIndex: idx,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Summary", const Color(0xFF333333)),
          _summaryCard(),
          const SizedBox(height: 12),
          Text(
            "Deposit စောင်ရေ: ${widget.depositTx.length} စောင်\n"
            "Withdraw စောင်ရေ: ${widget.withdrawTx.length} စောင်\n"
            "Total စောင်ရေ: ${widget.depositTx.length + widget.withdrawTx.length} စောင်",
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
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
        title: Text("${widget.bossName} Export"),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _exporting ? null : _showExportSheet,
            icon: _exporting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: _pageCount,
        itemBuilder: (_, idx) {
          if (_isDepositPage(idx)) return _buildDepositPage(idx);
          if (_isWithdrawPage(idx)) return _buildWithdrawPage(idx);
          return _buildSummaryPage(idx);
        },
      ),
    );
  }
}
