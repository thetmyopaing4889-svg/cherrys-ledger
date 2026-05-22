import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

import '../models/ledger_tx.dart';

// ─── Data structure ───────────────────────────────────────────────────────────

class _DayGroup {
  final int dayMs;
  final String label;
  final List<LedgerTx> txs;

  _DayGroup(this.dayMs, this.label, this.txs);

  int get amtSum  => txs.fold(0, (s, t) => s + t.amountKs);
  int get commSum => txs.fold(0, (s, t) => s + t.commissionKs);
  int get totSum  => txs.fold(0, (s, t) => s + t.totalKs);
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class MonthlyReportExportScreen extends StatefulWidget {
  final String        bossName;
  final int           year;
  final int           month;
  final List<LedgerTx> depositTx;
  final List<LedgerTx> withdrawTx;

  const MonthlyReportExportScreen({
    super.key,
    required this.bossName,
    required this.year,
    required this.month,
    required this.depositTx,
    required this.withdrawTx,
  });

  @override
  State<MonthlyReportExportScreen> createState() =>
      _MonthlyReportExportScreenState();
}

class _MonthlyReportExportScreenState
    extends State<MonthlyReportExportScreen> {
  static const int _daysPerPage = 5;

  final _moneyFmt = NumberFormat('#,###');

  bool _exporting   = false;
  bool _exportMode  = false;
  int  _currentPage = 0;

  late final List<_DayGroup> _depGroups;
  late final List<_DayGroup> _wdGroups;

  late final List<List<_DayGroup>> _depPages;
  late final List<List<_DayGroup>> _wdPages;

  late final int _pageCount;
  late final List<GlobalKey> _pageKeys;
  final PageController _pc = PageController();

  @override
  void initState() {
    super.initState();
    _depGroups = _buildGroups(widget.depositTx);
    _wdGroups  = _buildGroups(widget.withdrawTx);
    _depPages  = _chunkGroups(_depGroups);
    _wdPages   = _chunkGroups(_wdGroups);
    _pageCount = _depPages.length + _wdPages.length + 1; // +1 summary
    _pageKeys  = List.generate(_pageCount, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<_DayGroup> _buildGroups(List<LedgerTx> list) {
    final map = <int, List<LedgerTx>>{};
    for (final t in list) {
      final d   = DateTime.fromMillisecondsSinceEpoch(t.dateMs);
      final key = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
      map.putIfAbsent(key, () => []).add(t);
    }
    final sorted = map.keys.toList()..sort();
    return sorted.map((k) {
      final d  = DateTime.fromMillisecondsSinceEpoch(k);
      return _DayGroup(k, '${d.day}.${d.month}.${d.year}', map[k]!);
    }).toList();
  }

  List<List<_DayGroup>> _chunkGroups(List<_DayGroup> groups) {
    if (groups.isEmpty) return [[]];
    final out = <List<_DayGroup>>[];
    for (int i = 0; i < groups.length; i += _daysPerPage) {
      out.add(groups.sublist(i, math.min(i + _daysPerPage, groups.length)));
    }
    return out;
  }

  bool _isDepPage(int i)      => i < _depPages.length;
  bool _isWdPage(int i)       => i >= _depPages.length && i < _depPages.length + _wdPages.length;
  bool _isSummaryPage(int i)  => i == _pageCount - 1;

  bool _isLastDepPage(int i)  => i == _depPages.length - 1;
  bool _isLastWdPage(int i)   => i == _depPages.length + _wdPages.length - 1;

  String get _monthLabel =>
      DateFormat('MMMM yyyy').format(DateTime(widget.year, widget.month));

  String _safeName(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');

  String get _fileBase {
    final boss  = _safeName(widget.bossName);
    final mm    = widget.month.toString().padLeft(2, '0');
    return '${boss}_${widget.year}_$mm';
  }

  int get _depAmt  => widget.depositTx.fold(0, (s, t) => s + t.amountKs);
  int get _depComm => widget.depositTx.fold(0, (s, t) => s + t.commissionKs);
  int get _depTot  => widget.depositTx.fold(0, (s, t) => s + t.totalKs);

  int get _wdAmt   => widget.withdrawTx.fold(0, (s, t) => s + t.amountKs);
  int get _wdComm  => widget.withdrawTx.fold(0, (s, t) => s + t.commissionKs);
  int get _wdTot   => widget.withdrawTx.fold(0, (s, t) => s + t.totalKs);

  int get _totalComm => _depComm + _wdComm;

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _watermark() => Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _RepeatingWatermark("CHERRY'S LEDGER")),
        ),
      );

  Widget _header() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Text("Cherry's Ledger",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF9F1239))),
          const SizedBox(height: 2),
          Text('Monthly Report – $_monthLabel',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('Boss: ${widget.bossName}',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(height: 1, color: Colors.black.withOpacity(0.12)),
          const SizedBox(height: 10),
        ],
      );

  Widget _sectionTitle(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      );

  Widget _dayGroupWidget(
    _DayGroup g,
    Color accent, {
    required bool export,
    required bool showMonthTotal,
    required int monthAmt,
    required int monthComm,
    required int monthTot,
  }) {
    final cStyle = TextStyle(
        fontSize: export ? 10.0 : 12.0, fontWeight: FontWeight.w700);
    final cBold = TextStyle(
        fontSize: export ? 10.0 : 12.0, fontWeight: FontWeight.w900);
    final hStyle = TextStyle(
        fontSize: export ? 9.0 : 10.0,
        fontWeight: FontWeight.w800,
        color: Colors.black54);

    Widget txRow(LedgerTx t) => Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            Expanded(
                flex: 3, child: Text(t.personName, style: cStyle)),
            Expanded(
                flex: 3, child: Text(t.description, style: cStyle)),
            Expanded(
                flex: 2,
                child: Text(_moneyFmt.format(t.amountKs),
                    style: cStyle, textAlign: TextAlign.right)),
            Expanded(
                flex: 2,
                child: Text(_moneyFmt.format(t.commissionKs),
                    style: cStyle, textAlign: TextAlign.right)),
            Expanded(
                flex: 2,
                child: Text(_moneyFmt.format(t.totalKs),
                    style: cBold, textAlign: TextAlign.right)),
          ]),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCFE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column labels (only first group on each page)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
            child: Row(children: [
              Expanded(flex: 3, child: Text('နာမည်', style: hStyle)),
              Expanded(
                  flex: 3,
                  child: Text('အကြောင်းအရာ', style: hStyle)),
              Expanded(
                  flex: 2,
                  child: Text('ငွေပမာဏ',
                      style: hStyle, textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('ကော်မရှင်',
                      style: hStyle, textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('စုစုပေါင်း',
                      style: hStyle, textAlign: TextAlign.right)),
            ]),
          ),
          // Date label
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            color: accent.withOpacity(0.08),
            child: Text(g.label,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: accent,
                    fontSize: export ? 11.0 : 12.0)),
          ),
          // TX rows
          ...g.txs.map(txRow),
          // Sub Total
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: accent.withOpacity(0.05),
            child: Row(children: [
              Expanded(
                  flex: 6,
                  child: Text('Sub Total (${g.label})',
                      style: TextStyle(
                          fontSize: export ? 10.0 : 11.0,
                          fontWeight: FontWeight.w800,
                          color: accent))),
              Expanded(
                  flex: 2,
                  child: Text(_moneyFmt.format(g.amtSum),
                      style: TextStyle(
                          fontSize: export ? 10.0 : 11.0,
                          fontWeight: FontWeight.w800),
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text(_moneyFmt.format(g.commSum),
                      style: TextStyle(
                          fontSize: export ? 10.0 : 11.0,
                          fontWeight: FontWeight.w800),
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text(_moneyFmt.format(g.totSum),
                      style: TextStyle(
                          fontSize: export ? 10.0 : 11.0,
                          fontWeight: FontWeight.w900),
                      textAlign: TextAlign.right)),
            ]),
          ),
          // Monthly Total (last group on last page of this section)
          if (showMonthTotal)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.13),
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14)),
              ),
              child: Row(children: [
                const Expanded(
                    flex: 6,
                    child: Text('Total (လတစ်လုံး)',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900))),
                Expanded(
                    flex: 2,
                    child: Text(_moneyFmt.format(monthAmt),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900),
                        textAlign: TextAlign.right)),
                Expanded(
                    flex: 2,
                    child: Text(_moneyFmt.format(monthComm),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900),
                        textAlign: TextAlign.right)),
                Expanded(
                    flex: 2,
                    child: Text(_moneyFmt.format(monthTot),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900),
                        textAlign: TextAlign.right)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    Widget row(String label, String value, {bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label)),
              Text(value,
                  style: TextStyle(
                      fontWeight:
                          bold ? FontWeight.w900 : FontWeight.w700)),
            ],
          ),
        );

    Widget countRow(String label, int n) =>
        row(label, '$n စောင်');

    Widget moneyRow(String label, int v, {bool bold = false}) =>
        row(label, '${_moneyFmt.format(v)} MMK', bold: bold);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFCFE0)),
      ),
      child: Column(children: [
        countRow('Deposit စောင်ရေ', widget.depositTx.length),
        countRow('Withdraw စောင်ရေ', widget.withdrawTx.length),
        countRow('Total စောင်ရေ',
            widget.depositTx.length + widget.withdrawTx.length),
        const Divider(),
        moneyRow('Total ကော်မရှင် (income)', _totalComm, bold: true),
      ]),
    );
  }

  Widget _pageContainer({required Widget child, required int pageIndex}) =>
      RepaintBoundary(
        key: _pageKeys[pageIndex],
        child: LayoutBuilder(builder: (ctx, c) {
          return Container(
            width: c.maxWidth,
            height: c.maxHeight,
            color: const Color(0xFFFFF6F8),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Stack(children: [
              _watermark(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  Expanded(child: child),
                ],
              ),
            ]),
          );
        }),
      );

  Widget _buildPage(int pageIndex) {
    // Deposit pages
    if (_isDepPage(pageIndex)) {
      final groups        = _depPages[pageIndex];
      final isLastSection = _isLastDepPage(pageIndex);
      return _pageContainer(
        pageIndex: pageIndex,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Total Deposit (ဒီလအဝင်)', Colors.green),
              if (groups.isEmpty)
                const Text('No transactions')
              else
                ...groups.asMap().entries.map((e) {
                  final isLast = isLastSection && e.key == groups.length - 1;
                  return _dayGroupWidget(
                    e.value,
                    Colors.green,
                    export: _exportMode,
                    showMonthTotal: isLast,
                    monthAmt:  _depAmt,
                    monthComm: _depComm,
                    monthTot:  _depTot,
                  );
                }),
            ],
          ),
        ),
      );
    }

    // Withdraw pages
    if (_isWdPage(pageIndex)) {
      final wdIdx         = pageIndex - _depPages.length;
      final groups        = _wdPages[wdIdx];
      final isLastSection = _isLastWdPage(pageIndex);
      return _pageContainer(
        pageIndex: pageIndex,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Total Withdraw (ဒီလအထွက်)', Colors.red),
              if (groups.isEmpty)
                const Text('No transactions')
              else
                ...groups.asMap().entries.map((e) {
                  final isLast = isLastSection && e.key == groups.length - 1;
                  return _dayGroupWidget(
                    e.value,
                    Colors.red,
                    export: _exportMode,
                    showMonthTotal: isLast,
                    monthAmt:  _wdAmt,
                    monthComm: _wdComm,
                    monthTot:  _wdTot,
                  );
                }),
            ],
          ),
        ),
      );
    }

    // Summary page
    return _pageContainer(
      pageIndex: pageIndex,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Summary', const Color(0xFF333333)),
            _summaryCard(),
          ],
        ),
      ),
    );
  }

  // ── Export logic ───────────────────────────────────────────────────────────

  Future<bool> _ensureGalleryPermission() async {
    if (!Platform.isAndroid) return true;
    final photos  = await Permission.photos.request();
    if (photos.isGranted) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  Future<List<XFile>> _exportJpegPages() async {
    final out = <XFile>[];
    final dir = await getTemporaryDirectory();
    if (mounted) setState(() => _exportMode = true);
    try {
      for (int i = 0; i < _pageCount; i++) {
        await _pc.animateToPage(i,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut);
        await Future.delayed(const Duration(milliseconds: 200));

        final ctx = _pageKeys[i].currentContext;
        if (ctx == null) continue;

        final boundary =
            ctx.findRenderObject() as RenderRepaintBoundary;
        final uiImage =
            await boundary.toImage(pixelRatio: 3.0);
        final byteData = await uiImage.toByteData(
            format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        final decoded = img.decodePng(pngBytes);
        final jpg     = decoded == null
            ? pngBytes
            : img.encodeJpg(decoded, quality: 92);

        final p    = (i + 1).toString().padLeft(2, '0');
        final n    = _pageCount.toString().padLeft(2, '0');
        final file = File('${dir.path}/${_fileBase}_p${p}of$n.jpg');
        await file.writeAsBytes(jpg, flush: true);
        out.add(XFile(file.path));
      }
    } finally {
      if (mounted) setState(() => _exportMode = false);
    }
    return out;
  }

  Future<XFile> _exportExcel() async {
    final excel = xls.Excel.createExcel();
    final sheet = excel['MonthlyReport'];

    sheet.appendRow([xls.TextCellValue("Cherry's Ledger")]);
    sheet.appendRow([
      xls.TextCellValue('Boss'),
      xls.TextCellValue(widget.bossName)
    ]);
    sheet.appendRow([
      xls.TextCellValue('Month'),
      xls.TextCellValue(_monthLabel)
    ]);
    sheet.appendRow([xls.TextCellValue('')]);

    // Deposit
    sheet.appendRow([
      xls.TextCellValue('DEPOSIT'),
      xls.TextCellValue('ရက်စွဲ'),
      xls.TextCellValue('နာမည်'),
      xls.TextCellValue('အကြောင်းအရာ'),
      xls.TextCellValue('Amount'),
      xls.TextCellValue('Commission'),
      xls.TextCellValue('Total'),
    ]);
    for (final g in _depGroups) {
      for (final t in g.txs) {
        sheet.appendRow([
          xls.TextCellValue('D'),
          xls.TextCellValue(g.label),
          xls.TextCellValue(t.personName),
          xls.TextCellValue(t.description),
          xls.IntCellValue(t.amountKs),
          xls.IntCellValue(t.commissionKs),
          xls.IntCellValue(t.totalKs),
        ]);
      }
      sheet.appendRow([
        xls.TextCellValue('Sub Total'),
        xls.TextCellValue(g.label),
        xls.TextCellValue(''),
        xls.TextCellValue(''),
        xls.IntCellValue(g.amtSum),
        xls.IntCellValue(g.commSum),
        xls.IntCellValue(g.totSum),
      ]);
    }
    sheet.appendRow([
      xls.TextCellValue('Deposit Total'),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.IntCellValue(_depAmt),
      xls.IntCellValue(_depComm),
      xls.IntCellValue(_depTot),
    ]);
    sheet.appendRow([xls.TextCellValue('')]);

    // Withdraw
    sheet.appendRow([
      xls.TextCellValue('WITHDRAW'),
      xls.TextCellValue('ရက်စွဲ'),
      xls.TextCellValue('နာမည်'),
      xls.TextCellValue('အကြောင်းအရာ'),
      xls.TextCellValue('Amount'),
      xls.TextCellValue('Commission'),
      xls.TextCellValue('Total'),
    ]);
    for (final g in _wdGroups) {
      for (final t in g.txs) {
        sheet.appendRow([
          xls.TextCellValue('W'),
          xls.TextCellValue(g.label),
          xls.TextCellValue(t.personName),
          xls.TextCellValue(t.description),
          xls.IntCellValue(t.amountKs),
          xls.IntCellValue(t.commissionKs),
          xls.IntCellValue(t.totalKs),
        ]);
      }
      sheet.appendRow([
        xls.TextCellValue('Sub Total'),
        xls.TextCellValue(g.label),
        xls.TextCellValue(''),
        xls.TextCellValue(''),
        xls.IntCellValue(g.amtSum),
        xls.IntCellValue(g.commSum),
        xls.IntCellValue(g.totSum),
      ]);
    }
    sheet.appendRow([
      xls.TextCellValue('Withdraw Total'),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.IntCellValue(_wdAmt),
      xls.IntCellValue(_wdComm),
      xls.IntCellValue(_wdTot),
    ]);
    sheet.appendRow([xls.TextCellValue('')]);

    // Summary
    sheet.appendRow([xls.TextCellValue('SUMMARY')]);
    sheet.appendRow([
      xls.TextCellValue('Deposit စောင်ရေ'),
      xls.IntCellValue(widget.depositTx.length)
    ]);
    sheet.appendRow([
      xls.TextCellValue('Withdraw စောင်ရေ'),
      xls.IntCellValue(widget.withdrawTx.length)
    ]);
    sheet.appendRow([
      xls.TextCellValue('Total စောင်ရေ'),
      xls.IntCellValue(
          widget.depositTx.length + widget.withdrawTx.length)
    ]);
    sheet.appendRow([
      xls.TextCellValue('Total ကော်မရှင် (income)'),
      xls.IntCellValue(_totalComm)
    ]);

    final bytes = excel.encode()!;
    final dir   = await getTemporaryDirectory();
    final file  = File('${dir.path}/${_fileBase}_monthly.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path);
  }

  Future<void> _shareJpeg() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final pages = await _exportJpegPages();
      if (pages.isEmpty) return;
      await Share.shareXFiles(pages,
          text: '${widget.bossName} Monthly Report ($_monthLabel)');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Share failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _saveGallery() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final ok = await _ensureGalleryPermission();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gallery permission denied')));
        }
        return;
      }
      final pages = await _exportJpegPages();
      int saved = 0;
      for (final x in pages) {
        final res = await ImageGallerySaverPlus.saveFile(x.path);
        bool ok2 = false;
        if (res is Map) {
          ok2 = res['isSuccess'] == true || res['success'] == true;
        } else if (res != null) {
          ok2 = true;
        }
        if (ok2) saved++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gallery မှာ $saved page သိမ်းပြီးပြီ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareExcel() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final xfile = await _exportExcel();
      await Share.shareXFiles([xfile],
          text: '${widget.bossName} Monthly Report ($_monthLabel)');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6F8),
      appBar: AppBar(
        title: Text('${widget.bossName} Monthly Export'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Save JPEG to Gallery',
            onPressed: _exporting ? null : _saveGallery,
            icon: const Icon(Icons.photo_library),
          ),
          IconButton(
            tooltip: 'Share Excel',
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
                    onPressed: _exporting ? null : _shareJpeg,
                    icon: const Icon(Icons.ios_share),
                    label: Text(_exporting
                        ? 'Exporting…'
                        : 'Share JPEG (All Pages)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exporting ? null : _shareExcel,
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Share Excel'),
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

// ─── Watermark ────────────────────────────────────────────────────────────────

class _RepeatingWatermark extends CustomPainter {
  final String text;
  _RepeatingWatermark(this.text);

  @override
  void paint(Canvas canvas, Size size) {
    final ts = ui.TextStyle(
        color: const Color(0xFF000000).withOpacity(0.05),
        fontSize: 16,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2);
    final ps = ui.ParagraphStyle(textAlign: TextAlign.center);
    final pb = ui.ParagraphBuilder(ps)
      ..pushStyle(ts)
      ..addText(text);
    final para = pb.build();
    para.layout(const ui.ParagraphConstraints(width: 240));

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-20 * math.pi / 180);
    canvas.translate(-size.width / 2, -size.height / 2);
    const gx = 160.0, gy = 140.0;
    for (double y = -size.height; y < size.height * 2; y += gy) {
      for (double x = -size.width; x < size.width * 2; x += gx) {
        canvas.drawParagraph(para, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
