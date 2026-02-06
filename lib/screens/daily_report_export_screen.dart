import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cherrys_ledger/models/ledger_tx.dart';
import 'package:cross_file/cross_file.dart';
import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  String _safeName(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), "_");

  String _ymd(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "${d.year}-$mm-$dd";
  }

  // full-screen pages: deposit pages + withdraw pages + summary page
  static const int _rowsPerPage = 10;

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

  int get _pageCount => _depCount + _wdCount + 1; // + summary page

  bool _isDepositPage(int pageIndex) => pageIndex < _depCount;

  bool _isWithdrawPage(int pageIndex) => pageIndex >= _depCount && pageIndex < _depCount + _wdCount;

  bool _isSummaryPage(int pageIndex) => pageIndex == _pageCount - 1;

  List<LedgerTx> _depositSliceFor(int pageIndex) {
    if (_depPages.isEmpty) return const [];
    return _depPages[pageIndex];
  }

  List<LedgerTx> _withdrawSliceFor(int pageIndex) {
    if (_wdPages.isEmpty) return const [];
    return _wdPages[pageIndex - _depCount];
  }

  final PageController _pc = PageController();
  int _currentPage = 0;

  late final List<GlobalKey> _pageKeys =
      List.generate(_pageCount, (_) => GlobalKey());

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
                fontSize: 44,
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

    final amountSum = list.fold<int>(0, (s, t) => s + t.amountKs);
    final commSum = list.fold<int>(0, (s, t) => s + t.commissionKs);
    final totalSum = list.fold<int>(0, (s, t) => s + t.totalKs);

    Widget totalRow() {
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
              const Expanded(flex: 2, child: Text("Total", style: bold)),
              Expanded(
                flex: 2,
                child: Text(_moneyFmt.format(amountSum),
                    style: bold, textAlign: TextAlign.right),
              ),
              Expanded(
                flex: 2,
                child: Text(_moneyFmt.format(commSum),
                    style: bold, textAlign: TextAlign.right),
              ),
              Expanded(
                flex: 2,
                child: Text(_moneyFmt.format(totalSum),
                    style: bold, textAlign: TextAlign.right),
              ),
            ],
          ),
        ),
      );
    }

    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFCFE0)),
        ),
        child: const Text("No transactions"),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFCFE0)),
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
                    DataCell(Text(
                      _moneyFmt.format(t.totalKs),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
          totalRow(),
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
            Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFCFE0)),
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

  Future<XFile> _capturePageToFile(int pageIndex) async {
    await WidgetsBinding.instance.endOfFrame;

    final boundary = _pageKeys[pageIndex].currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final boss = _safeName(widget.bossName);
    final date = _ymd(widget.date);
    final p = pageIndex + 1;
    final n = _pageCount;

    final file = File("${dir.path}/${boss}_${date}_daily_p${p}of${n}.png");
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path);
  }

  Future<XFile> _exportExcel() async {
    final excel = xls.Excel.createExcel();
    final sheet = excel["DailyReport"];

    final d = widget.date;
    sheet.appendRow([xls.TextCellValue("Cherry’s Ledger")]);
    sheet.appendRow([xls.TextCellValue("Boss"), xls.TextCellValue(widget.bossName)]);
    sheet.appendRow([xls.TextCellValue("Date"), xls.TextCellValue("${d.year}-${d.month}-${d.day}")]);
    sheet.appendRow([xls.TextCellValue("")]);

    sheet.appendRow([
      xls.TextCellValue("DEPOSIT"),
      xls.TextCellValue("နာမည်"),
      xls.TextCellValue("အကြောင်းအရာ"),
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
      xls.TextCellValue("နာမည်"),
      xls.TextCellValue("အကြောင်းအရာ"),
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

    sheet.appendRow([xls.TextCellValue("SUMMARY")]);
    sheet.appendRow([xls.TextCellValue("PreviousBalance"), xls.IntCellValue(widget.previousBalance)]);
    sheet.appendRow([xls.TextCellValue("TotalDeposit"), xls.IntCellValue(widget.totalDeposit)]);
    sheet.appendRow([xls.TextCellValue("SubTotal"), xls.IntCellValue(widget.subTotal)]);
    sheet.appendRow([xls.TextCellValue("TotalWithdraw"), xls.IntCellValue(widget.totalWithdraw)]);
    sheet.appendRow([xls.TextCellValue("ClosingBalance"), xls.IntCellValue(widget.closingBalance)]);

    final bytes = excel.encode()!;
    final dir = await getTemporaryDirectory();
    final boss = _safeName(widget.bossName);
    final date = _ymd(widget.date);
    final file = File("${dir.path}/${boss}_${date}_daily.xlsx");
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path);
  }

  Future<void> _shareAllPagesAsJpeg() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final files = <XFile>[];
      for (int i = 0; i < _pageCount; i++) {
        // jump to page so it renders
        await _pc.animateToPage(i, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        files.add(await _capturePageToFile(i));
      }
      await Share.shareXFiles(files, text: "${widget.bossName} Daily Report (${_dateFmt.format(widget.date)})");
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareExcel() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final xfile = await _exportExcel();
      await Share.shareXFiles([xfile], text: "${widget.bossName} Daily Report (${_dateFmt.format(widget.date)})");
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _pageContainer({required Widget child, required int pageIndex}) {
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
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Page ${pageIndex + 1} / $_pageCount",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.black.withOpacity(0.55),
                      ),
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

  Widget _buildPage(int pageIndex) {
    if (_isDepositPage(pageIndex)) {
      final slice = _depositSliceFor(pageIndex);
      return _pageContainer(
        pageIndex: pageIndex,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("Total Deposit (ဒီနေ့အဝင်)", Colors.green),
              _table(slice),
            ],
          ),
        ),
      );
    }

    if (_isWithdrawPage(pageIndex)) {
      final slice = _withdrawSliceFor(pageIndex);
      return _pageContainer(
        pageIndex: pageIndex,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("Total Withdraw (ဒီနေ့အထွက်)", Colors.red),
              _table(slice),
            ],
          ),
        ),
      );
    }

    // summary page
    return _pageContainer(
      pageIndex: pageIndex,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("Summary", const Color(0xFF333333)),
            _summaryCard(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFFCFE0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(child: Text("Deposit စောင်ရေ")),
                      Text("${widget.depositTx.length} စောင်", style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(child: Text("Withdraw စောင်ရေ")),
                      Text("${widget.withdrawTx.length} စောင်", style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(child: Text("Total စောင်ရေ")),
                      Text("${widget.depositTx.length + widget.withdrawTx.length} စောင်",
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6F8),
      appBar: AppBar(
        title: Text("${widget.bossName} Export Preview"),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: "Share JPEG (all pages)",
            onPressed: _exporting ? null : _shareAllPagesAsJpeg,
            icon: const Icon(Icons.image),
          ),
          IconButton(
            tooltip: "Share Excel",
            onPressed: _exporting ? null : _shareExcel,
            icon: const Icon(Icons.table_chart),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _pageCount,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (_, i) => _buildPage(i),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exporting ? null : _shareAllPagesAsJpeg,
                    icon: const Icon(Icons.ios_share),
                    label: Text(_exporting ? "Exporting..." : "Share JPEG (All Pages)"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exporting ? null : _shareExcel,
                    icon: const Icon(Icons.table_chart),
                    label: const Text("Share Excel"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
