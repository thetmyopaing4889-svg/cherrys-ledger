import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/ledger_tx.dart';
import 'monthly_report_export_screen.dart';

class MonthlyReportScreen extends StatefulWidget {
  final String bossId;
  final String bossName;

  const MonthlyReportScreen({
    super.key,
    required this.bossId,
    required this.bossName,
  });

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final moneyFmt = NumberFormat('#,###');

  int _selectedYear  = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  List<LedgerTx> _depositTx  = [];
  List<LedgerTx> _withdrawTx = [];

  @override
  void initState() {
    super.initState();
    txStore.load().then((_) {
      bossStore.load().then((_) => _reload());
    });
    txStore.addListener(_onStore);
  }

  @override
  void dispose() {
    txStore.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (!mounted) return;
    if (!txStore.isLoaded) return;
    _reload();
  }

  void _reload() {
    final start = DateTime(_selectedYear, _selectedMonth).millisecondsSinceEpoch;
    final end   = DateTime(_selectedYear, _selectedMonth + 1).millisecondsSinceEpoch;

    final all = txStore
        .listByBoss(widget.bossId)
        .where((t) => !t.deleted && t.dateMs >= start && t.dateMs < end)
        .toList()
      ..sort((a, b) {
        final dc = a.dateMs.compareTo(b.dateMs);
        return dc != 0 ? dc : a.seqNo.compareTo(b.seqNo);
      });

    _depositTx  = all.where((t) => t.type == 'deposit').toList();
    _withdrawTx = all.where((t) => t.type == 'withdraw').toList();

    if (mounted) setState(() {});
  }

  Future<void> _pickMonth() async {
    int tempYear  = _selectedYear;
    int tempMonth = _selectedMonth;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('လနှင့်နှစ် ရွေးပါ',
              style: TextStyle(fontWeight: FontWeight.w900)),
          content: Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  value: tempMonth,
                  isExpanded: true,
                  items: List.generate(12, (i) => i + 1)
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(DateFormat('MMM').format(DateTime(2000, m))),
                          ))
                      .toList(),
                  onChanged: (v) => setSt(() => tempMonth = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<int>(
                  value: tempYear,
                  isExpanded: true,
                  items: List.generate(8, (i) => DateTime.now().year - 3 + i)
                      .map((y) =>
                          DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (v) => setSt(() => tempYear = v!),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('OK',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      setState(() {
        _selectedYear  = tempYear;
        _selectedMonth = tempMonth;
      });
      _reload();
    }
  }

  Map<int, List<LedgerTx>> _groupByDay(List<LedgerTx> list) {
    final map = <int, List<LedgerTx>>{};
    for (final t in list) {
      final d      = DateTime.fromMillisecondsSinceEpoch(t.dateMs);
      final dayKey = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
      map.putIfAbsent(dayKey, () => []).add(t);
    }
    return map;
  }

  Widget _buildSection(List<LedgerTx> txList, Color accent) {
    if (txList.isEmpty) {
      return _card(const Text('No transactions'));
    }

    final grouped   = _groupByDay(txList);
    final sortedKeys = grouped.keys.toList()..sort();

    final monthAmt  = txList.fold<int>(0, (s, t) => s + t.amountKs);
    final monthComm = txList.fold<int>(0, (s, t) => s + t.commissionKs);
    final monthTot  = txList.fold<int>(0, (s, t) => s + t.totalKs);

    const hStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black54);
    const cStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
    const cBold  = TextStyle(fontSize: 12, fontWeight: FontWeight.w900);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 6),
              color: Colors.black.withOpacity(0.06)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text('နာမည်', style: hStyle)),
                const Expanded(flex: 3, child: Text('အကြောင်းအရာ', style: hStyle)),
                Expanded(flex: 2, child: Text('ငွေပမာဏ', style: hStyle, textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('ကော်မရှင်', style: hStyle, textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('စုစုပေါင်း', style: hStyle, textAlign: TextAlign.right)),
              ],
            ),
          ),
          const Divider(height: 1),

          // Day groups
          ...sortedKeys.map((dayMs) {
            final dayTxs = grouped[dayMs]!;
            final d      = DateTime.fromMillisecondsSinceEpoch(dayMs);
            final label  = '${d.day}.${d.month}.${d.year}';
            final dayAmt  = dayTxs.fold<int>(0, (s, t) => s + t.amountKs);
            final dayComm = dayTxs.fold<int>(0, (s, t) => s + t.commissionKs);
            final dayTot  = dayTxs.fold<int>(0, (s, t) => s + t.totalKs);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: accent.withOpacity(0.08),
                  child: Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: accent,
                          fontSize: 12)),
                ),
                // TX rows
                ...dayTxs.map((t) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 3,
                              child:
                                  Text(t.personName, style: cStyle)),
                          Expanded(
                              flex: 3,
                              child:
                                  Text(t.description, style: cStyle)),
                          Expanded(
                              flex: 2,
                              child: Text(moneyFmt.format(t.amountKs),
                                  style: cStyle,
                                  textAlign: TextAlign.right)),
                          Expanded(
                              flex: 2,
                              child: Text(
                                  moneyFmt.format(t.commissionKs),
                                  style: cStyle,
                                  textAlign: TextAlign.right)),
                          Expanded(
                              flex: 2,
                              child: Text(moneyFmt.format(t.totalKs),
                                  style: cBold,
                                  textAlign: TextAlign.right)),
                        ],
                      ),
                    )),
                // Sub Total
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  color: accent.withOpacity(0.05),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 6,
                          child: Text('Sub Total ($label)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: accent))),
                      Expanded(
                          flex: 2,
                          child: Text(moneyFmt.format(dayAmt),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800),
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 2,
                          child: Text(moneyFmt.format(dayComm),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800),
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 2,
                          child: Text(moneyFmt.format(dayTot),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900),
                              textAlign: TextAlign.right)),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            );
          }),

          // Monthly Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.13),
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18)),
            ),
            child: Row(
              children: [
                const Expanded(
                    flex: 6,
                    child: Text('Total (လတစ်လုံး)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900))),
                Expanded(
                    flex: 2,
                    child: Text(moneyFmt.format(monthAmt),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900),
                        textAlign: TextAlign.right)),
                Expanded(
                    flex: 2,
                    child: Text(moneyFmt.format(monthComm),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900),
                        textAlign: TextAlign.right)),
                Expanded(
                    flex: 2,
                    child: Text(moneyFmt.format(monthTot),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900),
                        textAlign: TextAlign.right)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                blurRadius: 10,
                offset: const Offset(0, 6),
                color: Colors.black.withOpacity(0.06)),
          ],
        ),
        child: child,
      );

  Widget _sectionTitle(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      );

  Widget _countRow(String label, int count, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label)),
            Text('$count စောင်',
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.w900 : FontWeight.w700)),
          ],
        ),
      );

  Widget _moneyRow(String label, int value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label)),
            Text('${moneyFmt.format(value)} MMK',
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.w900 : FontWeight.w700)),
          ],
        ),
      );

  String get _monthLabel =>
      DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));

  int get _depositCount  => _depositTx.length;
  int get _withdrawCount => _withdrawTx.length;
  int get _totalCount    => _depositCount + _withdrawCount;
  int get _totalComm =>
      (_depositTx + _withdrawTx).fold<int>(0, (s, t) => s + t.commissionKs);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6F8),
      appBar: AppBar(
        title: Text('${widget.bossName} Monthly Report'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _pickMonth,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Month: $_monthLabel',
                        style:
                            const TextStyle(fontWeight: FontWeight.w900)),
                    const Icon(Icons.calendar_month),
                  ],
                ),
              ),
            ),

            _sectionTitle('Total Deposit (ဒီလအဝင်)', Colors.green),
            _buildSection(_depositTx, Colors.green),

            const SizedBox(height: 14),

            _sectionTitle('Total Withdraw (ဒီလအထွက်)', Colors.red),
            _buildSection(_withdrawTx, Colors.red),

            _sectionTitle('Summary', const Color(0xFF333333)),

            _card(Column(children: [
              _countRow('Deposit စောင်ရေ', _depositCount),
              _countRow('Withdraw စောင်ရေ', _withdrawCount),
              _countRow('Total စောင်ရေ', _totalCount, bold: true),
              const Divider(),
              _moneyRow('Total ကော်မရှင် (income)', _totalComm, bold: true),
            ])),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2D55),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MonthlyReportExportScreen(
                      bossName:   widget.bossName,
                      year:       _selectedYear,
                      month:      _selectedMonth,
                      depositTx:  _depositTx,
                      withdrawTx: _withdrawTx,
                    ),
                  ));
                },
                icon: const Icon(Icons.ios_share),
                label: const Text('Export (JPEG / Excel)',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),

            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }
}
