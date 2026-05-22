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

// ─── Month aggregate ──────────────────────────────────────────────────────────

class _MonthAgg {
  final int    month;
  final String label;
  final int    amt;
  final int    comm;
  final int    tot;
  final int    count;

  const _MonthAgg({
    required this.month,
    required this.label,
    required this.amt,
    required this.comm,
    required this.tot,
    required this.count,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class YearlyReportExportScreen extends StatefulWidget {
  final String         bossName;
  final int            year;
  final List<LedgerTx> depositTx;
  final List<LedgerTx> withdrawTx;

  const YearlyReportExportScreen({
    super.key,
    required this.bossName,
    required this.year,
    required this.depositTx,
    required this.withdrawTx,
  });

  @override
  State<YearlyReportExportScreen> createState() =>
      _YearlyReportExportScreenState();
}

class _YearlyReportExportScreenState
    extends State<YearlyReportExportScreen> {
  final _moneyFmt = NumberFormat('#,###');

  bool _exporting   = false;
  bool _exportMode  = false;
  int  _currentPage = 0;

  // Pages: deposit page, withdraw page, summary page = 3 total
  static const int _pageCount = 3;

  late final List<GlobalKey>  _pageKeys;
  late final List<_MonthAgg>  _depAggs;
  late final List<_MonthAgg>  _wdAggs;
  final PageController _pc = PageController();

  @override
  void initState() {
    super.initState();
    _depAggs  = _buildAggs(widget.depositTx);
    _wdAggs   = _buildAggs(widget.withdrawTx);
    _pageKeys = List.generate(_pageCount, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<_MonthAgg> _buildAggs(List<LedgerTx> list) {
    return List.generate(12, (m) {
      final month = m + 1;
      final start = DateTime(widget.year, month).millisecondsSinceEpoch;
      final end   = DateTime(widget.year, month + 1).millisecondsSinceEpoch;
      final txs   =
          list.where((t) => t.dateMs >= start && t.dateMs < end).toList();
      return _MonthAgg(
        month: month,
        label: DateFormat('MMMM').format(DateTime(widget.year, month)),
        amt:   txs.fold(0, (s, t) => s + t.amountKs),
        comm:  txs.fold(0, (s, t) => s + t.commissionKs),
        tot:   txs.fold(0, (s, t) => s + t.totalKs),
        count: txs.length,
      );
    });
  }

  String get _fileBase {
    final boss = widget.bossName.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
    return '${boss}_${widget.year}';
  }

  int get _depAmt   => _depAggs.fold(0, (s, r) => s + r.amt);
  int get _depComm  => _depAggs.fold(0, (s, r) => s + r.comm);
  int get _depTot   => _depAggs.fold(0, (s, r) => s + r.tot);
  int get _depCount => _depAggs.fold(0, (s, r) => s + r.count);

  int get _wdAmt    => _wdAggs.fold(0, (s, r) => s + r.amt);
  int get _wdComm   => _wdAggs.fold(0, (s, r) => s + r.comm);
  int get _wdTot    => _wdAggs.fold(0, (s, r) => s + r.tot);
  int get _wdCount  => _wdAggs.fold(0, (s, r) => s + r.count);

  int get _totalComm => _depComm + _wdComm;
  int get _totalCount => _depCount + _wdCount;

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _watermark() => Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
              painter: _RepeatingWatermark("CHERRY'S LEDGER")),
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
          Text('Yearly Report – ${widget.year}',
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

  Widget _monthTable(
    List<_MonthAgg> aggs,
    Color accent, {
    required int yearAmt,
    required int yearComm,
    required int yearTot,
    required int yearCount,
  }) {
    const hStyle = TextStyle(
        fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black54);
    final cStyle = TextStyle(
        fontSize: _exportMode ? 11.0 : 12.0, fontWeight: FontWeight.w700);
    final cBold = TextStyle(
        fontSize: _exportMode ? 11.0 : 12.0, fontWeight: FontWeight.w900);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCFE0)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(children: [
              const Expanded(flex: 3, child: Text('Month', style: hStyle)),
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
              Expanded(
                  flex: 1,
                  child: Text('စောင်',
                      style: hStyle, textAlign: TextAlign.right)),
            ]),
          ),
          const Divider(height: 1),

          // Month rows
          ...aggs.map((r) {
            final hasData = r.count > 0;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  child: Row(children: [
                    Expanded(
                        flex: 3,
                        child: Text(r.label,
                            style: hasData
                                ? cBold
                                : cStyle.copyWith(color: Colors.black38))),
                    Expanded(
                        flex: 2,
                        child: Text(
                            hasData ? _moneyFmt.format(r.amt) : '-',
                            style: hasData
                                ? cStyle
                                : cStyle.copyWith(color: Colors.black38),
                            textAlign: TextAlign.right)),
                    Expanded(
                        flex: 2,
                        child: Text(
                            hasData ? _moneyFmt.format(r.comm) : '-',
                            style: hasData
                                ? cStyle
                                : cStyle.copyWith(color: Colors.black38),
                            textAlign: TextAlign.right)),
                    Expanded(
                        flex: 2,
                        child: Text(
                            hasData ? _moneyFmt.format(r.tot) : '-',
                            style: hasData
                                ? cBold
                                : cBold.copyWith(color: Colors.black38),
                            textAlign: TextAlign.right)),
                    Expanded(
                        flex: 1,
                        child: Text(
                            hasData ? '${r.count}' : '-',
                            style: cStyle.copyWith(color: Colors.black45),
                            textAlign: TextAlign.right)),
                  ]),
                ),
                const Divider(height: 1),
              ],
            );
          }),

          // Yearly Total
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.13),
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14)),
            ),
            child: Row(children: [
              const Expanded(
                  flex: 3,
                  child: Text('Total (နှစ်တစ်နှစ်)',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900))),
              Expanded(
                  flex: 2,
                  child: Text(_moneyFmt.format(yearAmt),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text(_moneyFmt.format(yearComm),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text(_moneyFmt.format(yearTot),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 1,
                  child: Text('$yearCount',
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCFE0)),
      ),
      child: Column(children: [
        row('Deposit စောင်ရေ', '$_depCount စောင်'),
        row('Withdraw စောင်ရေ', '$_wdCount စောင်'),
        row('Total စောင်ရေ', '$_totalCount စောင်', bold: true),
        const Divider(),
        row('Total ကော်မရှင် (income)',
            '${_moneyFmt.format(_totalComm)} MMK',
            bold: true),
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
    if (pageIndex == 0) {
      return _pageContainer(
        pageIndex: pageIndex,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Total Deposit (ဒီနှစ်အဝင်)', Colors.green),
              _monthTable(_depAggs, Colors.green,
                  yearAmt: _depAmt, yearComm: _depComm,
                  yearTot: _depTot, yearCount: _depCount),
            ],
          ),
        ),
      );
    }

    if (pageIndex == 1) {
      return _pageContainer(
        pageIndex: pageIndex,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                  'Total Withdraw (ဒီနှစ်အထွက်)', Colors.red),
              _monthTable(_wdAggs, Colors.red,
                  yearAmt: _wdAmt, yearComm: _wdComm,
                  yearTot: _wdTot, yearCount: _wdCount),
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

  // ── Export ─────────────────────────────────────────────────────────────────

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
        final file =
            File('${dir.path}/${_fileBase}_yearly_p${p}of$n.jpg');
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
    final sheet = excel['YearlyReport'];

    sheet.appendRow([xls.TextCellValue("Cherry's Ledger")]);
    sheet.appendRow([
      xls.TextCellValue('Boss'),
      xls.TextCellValue(widget.bossName)
    ]);
    sheet.appendRow([
      xls.TextCellValue('Year'),
      xls.IntCellValue(widget.year)
    ]);
    sheet.appendRow([xls.TextCellValue('')]);

    void writeSection(String label, List<_MonthAgg> aggs,
        int totAmt, int totComm, int totTot, int totCount) {
      sheet.appendRow([
        xls.TextCellValue(label),
        xls.TextCellValue('Month'),
        xls.TextCellValue('Amount'),
        xls.TextCellValue('Commission'),
        xls.TextCellValue('Total'),
        xls.TextCellValue('Count'),
      ]);
      for (final r in aggs) {
        sheet.appendRow([
          xls.TextCellValue(''),
          xls.TextCellValue(r.label),
          xls.IntCellValue(r.amt),
          xls.IntCellValue(r.comm),
          xls.IntCellValue(r.tot),
          xls.IntCellValue(r.count),
        ]);
      }
      sheet.appendRow([
        xls.TextCellValue('$label Total'),
        xls.TextCellValue(''),
        xls.IntCellValue(totAmt),
        xls.IntCellValue(totComm),
        xls.IntCellValue(totTot),
        xls.IntCellValue(totCount),
      ]);
      sheet.appendRow([xls.TextCellValue('')]);
    }

    writeSection('DEPOSIT', _depAggs, _depAmt, _depComm, _depTot, _depCount);
    writeSection('WITHDRAW', _wdAggs, _wdAmt, _wdComm, _wdTot, _wdCount);

    sheet.appendRow([xls.TextCellValue('SUMMARY')]);
    sheet.appendRow([
      xls.TextCellValue('Deposit စောင်ရေ'),
      xls.IntCellValue(_depCount)
    ]);
    sheet.appendRow([
      xls.TextCellValue('Withdraw စောင်ရေ'),
      xls.IntCellValue(_wdCount)
    ]);
    sheet.appendRow([
      xls.TextCellValue('Total စောင်ရေ'),
      xls.IntCellValue(_totalCount)
    ]);
    sheet.appendRow([
      xls.TextCellValue('Total ကော်မရှင် (income)'),
      xls.IntCellValue(_totalComm)
    ]);

    final bytes = excel.encode()!;
    final dir   = await getTemporaryDirectory();
    final file  = File('${dir.path}/${_fileBase}_yearly.xlsx');
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
          text:
              '${widget.bossName} Yearly Report (${widget.year})');
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
              const SnackBar(
                  content: Text('Gallery permission denied')));
        }
        return;
      }
      final pages = await _exportJpegPages();
      int saved = 0;
      for (final x in pages) {
        final res = await ImageGallerySaverPlus.saveFile(x.path);
        bool ok2  = false;
        if (res is Map) {
          ok2 = res['isSuccess'] == true || res['success'] == true;
        } else if (res != null) {
          ok2 = true;
        }
        if (ok2) saved++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Gallery မှာ $saved page သိမ်းပြီးပြီ')));
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
          text:
              '${widget.bossName} Yearly Report (${widget.year})');
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
        title: Text('${widget.bossName} Yearly Export'),
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
