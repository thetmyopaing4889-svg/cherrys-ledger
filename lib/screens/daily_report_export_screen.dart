import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cherrys_ledger/models/ledger_tx.dart';
import 'package:cross_file/cross_file.dart';
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

  // tune for phone screen
  static const int _rowsPerPage = 10;

  String _safeName(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), "_");

  String _ymd(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
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

  bool _isDepositPage(int i) => i < _depCount;
  bool _isWithdrawPage(int i) => i >= _depCount && i < _depCount + _wdCount;
  bool _isSummaryPage(int i) => i == _pageCount - 1;

  List<LedgerTx> _depositSliceFor(int i) => _depPages.isEmpty ? const [] : _depPages[i];
  List<LedgerTx> _withdrawSliceFor(int i) => _wdPages.isEmpty ? const [] : _wdPages[i - _depCount];

  final List<GlobalKey> _pageKeys = [];

  @override
  void initState() {
    super.initState();
    _pageKeys.clear();
    for (int i = 0; i < _pageCount; i++) {
      _pageKeys.add(GlobalKey());
    }
  }

  Widget _watermark() {
    return IgnorePointer(
      child: Center(
        child: Transform.rotate(
          angle: -15 * math.pi / 180,
          child: Opacity(
            opacity: 0.07,
            child: Text(
              "CHERRY'S LEDGER",
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

  Widget _header({required int pageIndex}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          "Cherry's Ledger",
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
        const SizedBox(height: 2),
        Text(
          "Page ${pageIndex + 1} / $_pageCount",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black.withOpacity(0.65)),
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
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
      ),
    );
  }

  Widget _table(List<LedgerTx> list) {
    final headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black.withOpacity(0.65));
    const cellStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
    const totalStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w900);

    int amountSum = 0, commSum = 0, totalSum = 0;
    for (final t in list) {
      amountSum += t.amountKs;
      commSum += t.commissionKs;
      totalSum += t.totalKs;
    }

    Widget cell(String s, {TextAlign align = TextAlign.left, TextStyle? style}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(s, textAlign: align, style: style ?? cellStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
      );
    }

    Widget rowDivider() => Container(height: 1, color: Colors.black.withOpacity(0.08));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(blurRadius: 10, offset: const Offset(0, 6), color: Colors.black.withOpacity(0.06))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(flex: 2, child: Text("နာမည်", style: headerStyle)),
              Expanded(flex: 3, child: Text("အကြောင်းအရာ", style: headerStyle)),
              Expanded(flex: 2, child: Text("ငွေပမာဏ", style: headerStyle, textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text("ကော်မရှင်", style: headerStyle, textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text("စုစုပေါင်းငွေ", style: headerStyle, textAlign: TextAlign.right)),
            ],
          ),
          rowDivider(),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text("No transactions", style: TextStyle(fontWeight: FontWeight.w700)),
            )
          else
            ...list.map((t) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(flex: 2, child: cell(t.personName)),
                      Expanded(flex: 3, child: cell(t.description)),
                      Expanded(flex: 2, child: cell(_moneyFmt.format(t.amountKs), align: TextAlign.right)),
                      Expanded(flex: 2, child: cell(_moneyFmt.format(t.commissionKs), align: TextAlign.right)),
                      Expanded(flex: 2, child: cell(_moneyFmt.format(t.totalKs), align: TextAlign.right, style: totalStyle)),
                    ],
                  ),
                  rowDivider(),
                ],
              );
            }),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6F8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFCFE0)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 2, child: Text("Total", style: totalStyle)),
                Expanded(flex: 3, child: const SizedBox.shrink()),
                Expanded(flex: 2, child: Text(_moneyFmt.format(amountSum), style: totalStyle, textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_moneyFmt.format(commSum), style: totalStyle, textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_moneyFmt.format(totalSum), style: totalStyle, textAlign: TextAlign.right)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    Widget row(String label, int value, {bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label)),
            Text(
              "${_moneyFmt.format(value)} MMK",
              style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700),
            ),
          ],
        ),
      );
    }

    Widget countRow(String label, int value, {bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label)),
            Text(
              "$value စောင်",
              style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700),
            ),
          ],
        ),
      );
    }

    final depCount = widget.depositTx.length;
    final wdCount = widget.withdrawTx.length;
    final totalCount = depCount + wdCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Summary", const Color(0xFF333333)),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(blurRadius: 10, offset: const Offset(0, 6), color: Colors.black.withOpacity(0.06))],
          ),
          child: Column(
            children: [
              row("Previous Balance (ယခင်လက်ကျန်)", widget.previousBalance),
              row("Total Deposit (ဒီနေ့အဝင်)", widget.totalDeposit),
              const Divider(),
              row("Sub Total", widget.subTotal, bold: true),
              row("Total Withdraw (ဒီနေ့အထွက်)", widget.totalWithdraw),
              const Divider(),
              row("Closing Balance (စာရင်းပိတ်ငွေလက်ကျန်)", widget.closingBalance, bold: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(blurRadius: 10, offset: const Offset(0, 6), color: Colors.black.withOpacity(0.06))],
          ),
          child: Column(
            children: [
              countRow("Deposit စောင်ရေ", depCount),
              countRow("Withdraw စောင်ရေ", wdCount),
              countRow("Total စောင်ရေ", totalCount, bold: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _page(int i) {
    late final Widget body;

    if (_isDepositPage(i)) {
      final slice = _depPages.isEmpty ? const <LedgerTx>[] : _depositSliceFor(i);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Total Deposit (ဒီနေ့အဝင်)", Colors.green),
          _table(slice),
        ],
      );
    } else if (_isWithdrawPage(i)) {
      final slice = _wdPages.isEmpty ? const <LedgerTx>[] : _withdrawSliceFor(i);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Total Withdraw (ဒီနေ့အထွက်)", Colors.red),
          _table(slice),
        ],
      );
    } else {
      body = _summaryCard();
    }

    return RepaintBoundary(
      key: _pageKeys[i],
      child: Container(
        color: const Color(0xFFFFF6F8),
        child: Stack(
          children: [
            Positioned.fill(child: _watermark()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _header(pageIndex: i),
                    Expanded(
                      child: SingleChildScrollView(
                        child: body,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<XFile> _capturePageToFile(int i) async {
    final boundary = _pageKeys[i].currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final boss = _safeName(widget.bossName);
    final ymd = _ymd(widget.date);
    final pageNo = (i + 1).toString().padLeft(2, '0');
    final file = File("${dir.path}/${boss}_${ymd}_daily_p$pageNo.png");
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path);
  }

  Future<void> _exportAndShare() async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      // give UI a frame to paint
      await Future.delayed(const Duration(milliseconds: 200));

      final files = <XFile>[];
      for (int i = 0; i < _pageCount; i++) {
        final f = await _capturePageToFile(i);
        files.add(f);
      }

      await Share.shareXFiles(
        files,
        text: "${widget.bossName} Daily Report – ${_dateFmt.format(widget.date)}",
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cherry Daily Report"),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _exporting ? null : _exportAndShare,
            icon: _exporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: PageView.builder(
        itemCount: _pageCount,
        itemBuilder: (_, i) => _page(i),
      ),
    );
  }
}
