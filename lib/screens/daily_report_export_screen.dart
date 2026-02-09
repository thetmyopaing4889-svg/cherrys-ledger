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
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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

  bool _exportMode = false;



int _currentPage = 0;
  String _safeName(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), "_");

  String _ymd(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "${d.year}-$mm-$dd";
  }

  Future<bool> _ensureGalleryPermission() async {
    if (!Platform.isAndroid) return true;
    final photos = await Permission.photos.request();
    if (photos.isGranted) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  String _cleanFilePath(String p) {
    // sometimes share cache path comes as: File: '/path/to/file.jpg'
    var s = p;
    if (s.startsWith("File:")) {
      s = s.replaceFirst("File:", "").trim();
    }
    // strip wrapping quotes if any
    if ((s.startsWith("\x27") && s.endsWith("\x27")) || (s.startsWith("\"") && s.endsWith("\""))) {
      s = s.substring(1, s.length - 1);
    }
    return s;
  }

  String _baseFileName({required int pageIndex, required int pageCount}) {
    final boss = _safeName(widget.bossName);
    final d = _ymd(widget.date);
    final p = (pageIndex + 1).toString().padLeft(2, '0');
    final n = pageCount.toString().padLeft(2, '0');
    return "${boss}_${d}_p${p}of${n}";
  }
  // full-screen pages: deposit pages + withdraw pages + summary page
  static const int _rowsPerPage = 10;

  List<List<LedgerTx>> _chunk(List<LedgerTx> list) {
    if (list.isEmpty) return const [];
    final out = <List<LedgerTx>>[];
    for (int i = 0; i < list.length; i += _rowsPerPage) {
      out.add(list.sublist(i, math.min(i + _rowsPerPage, list.length)));
    }
    if (mounted) {
      setState(() {
      });
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

  late final List<GlobalKey> _pageKeys =
      List.generate(_pageCount, (_) => GlobalKey());

  Widget _watermark() {
  return Positioned.fill(
    child: IgnorePointer(
      child: CustomPaint(
        painter: RepeatingWatermark("CHERRY’S LEDGER"),
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

    Widget _table(List<LedgerTx> list, {bool export = false}) {
    // Export-only tuning:
    // - NO wrapping (single line) for headers + key cells to avoid stacked text
    // - Smaller export font so 5 columns fit in one page
    // - Total column data MUST match amount/commission (no larger font)
    final headerStyle = TextStyle(
      fontSize: export ? 11.0 : 12.0,
      fontWeight: FontWeight.w900,
      color: Colors.black.withOpacity(0.65),
    );

    final cellStyle = TextStyle(
      fontSize: export ? 10.5 : 12.0,
      fontWeight: FontWeight.w700,
      color: Colors.black.withOpacity(0.88),
    );

    Text headerText(String t) => Text(
          t,
          style: headerStyle,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        );

    Text cellText(String t, {TextAlign align = TextAlign.left, bool ellipsisWhenExport = true}) => Text(
          t,
          style: cellStyle,
          textAlign: align,
          maxLines: export && ellipsisWhenExport ? 1 : null,
          softWrap: export && ellipsisWhenExport ? false : true,
          overflow: export && ellipsisWhenExport ? TextOverflow.ellipsis : TextOverflow.clip,
        );

    final amountSum = list.fold<int>(0, (s, t) => s + t.amountKs);
    final commSum = list.fold<int>(0, (s, t) => s + t.commissionKs);
    final totalSum = list.fold<int>(0, (s, t) => s + t.totalKs);

    Widget totalRow() {
      final bold = TextStyle(
        fontSize: export ? 11.0 : 12.0,
        fontWeight: FontWeight.w900,
        color: Colors.black.withOpacity(0.90),
      );

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
              Expanded(flex: 2, child: Text("Total", style: bold)),
              Expanded(flex: 2, child: Text(_moneyFmt.format(amountSum), style: bold, textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text(_moneyFmt.format(commSum), style: bold, textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text(_moneyFmt.format(totalSum), style: bold, textAlign: TextAlign.right)),
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

    final dt = DataTable(
      columnSpacing: export ? 6 : 14,
      horizontalMargin: export ? 4 : 12,
      headingRowHeight: 32,
      dataRowMinHeight: export ? 30 : 36,
      dataRowMaxHeight: export ? 48 : 52,
      columns: [
        DataColumn(label: headerText("နာမည်")),
        DataColumn(label: headerText("အကြောင်းအရာ")),
        DataColumn(label: headerText("ငွေပမာဏ"), numeric: true),
        DataColumn(label: headerText("ကော်မရှင်"), numeric: true),
        DataColumn(label: headerText("စုစုပေါင်းငွေ"), numeric: true),
      ],
      rows: list.map((t) {
        return DataRow(
          cells: [
            // Export: single line + ellipsis (avoid stacked names)
            DataCell(cellText(t.personName, ellipsisWhenExport: true)),
            DataCell(cellText(t.description, ellipsisWhenExport: true)),
            DataCell(cellText(_moneyFmt.format(t.amountKs), align: TextAlign.right, ellipsisWhenExport: false)),
            DataCell(cellText(_moneyFmt.format(t.commissionKs), align: TextAlign.right, ellipsisWhenExport: false)),
            // IMPORTANT: total column data uses SAME style/size as amount/commission (no extra bold)
            DataCell(cellText(_moneyFmt.format(t.totalKs), align: TextAlign.right, ellipsisWhenExport: false)),
          ],
        );
      }).toList(),
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFCFE0)),
      ),
      child: Column(
        children: [
          // Preview: allow horizontal scroll as before
          // Export: NO scroll (so image captures everything) + smaller font above should fit
          export
              ? dt
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: dt,
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
      final files = await _exportJpegPages();
      if (files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Nothing to export")),
          );
        }
        return;
      }
      await Share.shareXFiles(
        files,
        text: "${widget.bossName} Daily Report (${_dateFmt.format(widget.date)})",
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Share failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
  
  Future<List<XFile>> _exportJpegPages() async {
    final out = <XFile>[];
    final dir = await getTemporaryDirectory();
    if (mounted) setState(() => _exportMode = true);

    try {
      for (int i = 0; i < _pageCount; i++) {
        // Ensure the page is rendered in PageView before capture
        await _pc.animateToPage(
          i,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
        await Future.delayed(const Duration(milliseconds: 180));

        final ctx = _pageKeys[i].currentContext;
        if (ctx == null) continue;

        final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
        final uiImage = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        final decoded = img.decodePng(pngBytes);
        final jpg = (decoded == null)
            ? pngBytes /* fallback */
            : img.encodeJpg(decoded, quality: 92);

        final name = _baseFileName(pageIndex: i, pageCount: _pageCount);
        final file = File("${dir.path}/$name.jpg");
        await file.writeAsBytes(jpg, flush: true);
        out.add(XFile(file.path));
      }
      return out;
    } finally {
      if (mounted) setState(() => _exportMode = false);
    }
  }
  Future<void> _saveAllToGallery() async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final ok = await _ensureGalleryPermission();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gallery permission denied")),
          );
        }
        return;
      }

      final pages = await _exportJpegPages();
      if (pages.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Nothing to save")),
          );
        }
        return;
      }

      int saved = 0;
      for (final x in pages) {
        final p = x.path;
        final file = File(p);
        if (!await file.exists()) continue;

        final res = await ImageGallerySaverPlus.saveFile(p);

        bool okSave = false;
        if (res is Map) {
          final v1 = res["isSuccess"];
          final v2 = res["success"];
          if (v1 == true || v2 == true) okSave = true;
        } else if (res != null) {
          okSave = true;
        }

        if (okSave) saved++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Saved to Gallery: $saved page(s)")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Save failed: $e")),
        );
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
      await Share.shareXFiles([xfile], text: "${widget.bossName} Daily Report (${_dateFmt.format(widget.date)})");
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  
  
Widget _pageContainer({required Widget child, required int pageIndex}) {
    return RepaintBoundary(
      key: _pageKeys[pageIndex],
      child: LayoutBuilder(
        builder: (context, c) {
          Widget buildPaper(double pw, double ph) {
            return Container(
              width: pw,
              height: ph,
              color: const Color(0xFFFFF6F8),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Stack(
                children: [
                  _watermark(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      Expanded(child: child),
                    ],
                  ),
                ],
              ),
            );
          }

          final w = c.maxWidth;
          final h = c.maxHeight;
          // Always render pages using screen size.
          // This makes export JPEG match preview proportions and lets the card layout use full width.
          return buildPaper(w, h);
},
      ),
    );
  }

  Widget _buildPage(int pageIndex) {
      if (_isDepositPage(pageIndex)) {
        final slice = _depositSliceFor(pageIndex);

        final Widget content = SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle("Total Deposit (ဒီနေ့အဝင်)", Colors.green),
                _table(slice, export: _exportMode),
              ],
            ),
          );

          return _pageContainer(
            pageIndex: pageIndex,
            child: content,
          );
}

      if (_isWithdrawPage(pageIndex)) {
        final slice = _withdrawSliceFor(pageIndex);

        final Widget content = SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle("Total Withdraw (ဒီနေ့အထွက်)", Colors.green),
                _table(slice, export: _exportMode),
              ],
            ),
          );

          return _pageContainer(
            pageIndex: pageIndex,
            child: content,
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

  Future<void> _exportAndShare() async {
    if (_exporting) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text("Share All JPEG Pages"),
              onTap: () async {
                Navigator.pop(context);
                setState(() => _exporting = true);
                try {
                  final pages = await _exportJpegPages();
                  await Share.shareXFiles(
                    pages,
                    text: "${widget.bossName} Daily Report (${_dateFmt.format(widget.date)})",
                  );
                } finally {
                  if (mounted) setState(() => _exporting = false);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text("Save JPEG to Gallery"),
              onTap: () async {
                Navigator.pop(context);
                await _saveAllToGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text("Share Excel"),
              onTap: () async {
                Navigator.pop(context);
                await _shareExcel();
              },
            ),
            const SizedBox(height: 12),
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
            tooltip: "Save JPEG to Gallery",
              onPressed: _exporting ? null : _saveAllToGallery,
              icon: const Icon(Icons.photo_library),
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

class RepeatingWatermark extends CustomPainter {
  final String text;
  RepeatingWatermark(this.text);

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = ui.TextStyle(
      color: const Color(0xFF000000).withOpacity(0.05),
      fontSize: 16,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.2,
    );

    final paragraphStyle = ui.ParagraphStyle(
      textAlign: TextAlign.center,
    );

    final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(text);

    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 240));

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-20 * math.pi / 180);
    canvas.translate(-size.width / 2, -size.height / 2);

    const gapX = 160.0;
    const gapY = 140.0;

    for (double y = -size.height; y < size.height * 2; y += gapY) {
      for (double x = -size.width; x < size.width * 2; x += gapX) {
        canvas.drawParagraph(paragraph, Offset(x, y));
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
