import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/ledger_tx.dart';
import 'yearly_report_export_screen.dart';

class YearlyReportScreen extends StatefulWidget {
  final String bossId;
  final String bossName;

  const YearlyReportScreen({
    super.key,
    required this.bossId,
    required this.bossName,
  });

  @override
  State<YearlyReportScreen> createState() => _YearlyReportScreenState();
}

class _YearlyReportScreenState extends State<YearlyReportScreen> {
  final moneyFmt = NumberFormat('#,###');

  int _selectedYear = DateTime.now().year;

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
    final start = DateTime(_selectedYear).millisecondsSinceEpoch;
    final end   = DateTime(_selectedYear + 1).millisecondsSinceEpoch;

    final all = txStore
        .listByBoss(widget.bossId)
        .where((t) => !t.deleted && t.dateMs >= start && t.dateMs < end)
        .toList();

    _depositTx  = all.where((t) => t.type == 'deposit').toList();
    _withdrawTx = all.where((t) => t.type == 'withdraw').toList();

    if (mounted) setState(() {});
  }

  // Build monthly aggregates: index 0 = January … 11 = December
  List<_MonthRow> _buildMonthRows(List<LedgerTx> list) {
    return List.generate(12, (m) {
      final month = m + 1;
      final start = DateTime(_selectedYear, month).millisecondsSinceEpoch;
      final end   = DateTime(_selectedYear, month + 1).millisecondsSinceEpoch;
      final txs   = list
          .where((t) => t.dateMs >= start && t.dateMs < end)
          .toList();
      return _MonthRow(
        month: month,
        label: DateFormat('MMMM').format(DateTime(_selectedYear, month)),
        amt:   txs.fold(0, (s, t) => s + t.amountKs),
        comm:  txs.fold(0, (s, t) => s + t.commissionKs),
        tot:   txs.fold(0, (s, t) => s + t.totalKs),
        count: txs.length,
      );
    });
  }

  Widget _buildSection(List<LedgerTx> txList, Color accent, String label) {
    final rows = _buildMonthRows(txList);

    final totalAmt   = rows.fold<int>(0, (s, r) => s + r.amt);
    final totalComm  = rows.fold<int>(0, (s, r) => s + r.comm);
    final totalTot   = rows.fold<int>(0, (s, r) => s + r.tot);
    final totalCount = rows.fold<int>(0, (s, r) => s + r.count);

    const hStyle = TextStyle(
        fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black54);
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
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
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
          ...rows.map((r) {
            final hasData = r.count > 0;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Expanded(
                        flex: 3,
                        child: Text(r.label,
                            style: hasData ? cBold : cStyle.copyWith(color: Colors.black38))),
                    Expanded(
                        flex: 2,
                        child: Text(
                            hasData ? moneyFmt.format(r.amt) : '-',
                            style: hasData ? cStyle : cStyle.copyWith(color: Colors.black38),
                            textAlign: TextAlign.right)),
                    Expanded(
                        flex: 2,
                        child: Text(
                            hasData ? moneyFmt.format(r.comm) : '-',
                            style: hasData ? cStyle : cStyle.copyWith(color: Colors.black38),
                            textAlign: TextAlign.right)),
                    Expanded(
                        flex: 2,
                        child: Text(
                            hasData ? moneyFmt.format(r.tot) : '-',
                            style: hasData ? cBold : cBold.copyWith(color: Colors.black38),
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
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18)),
            ),
            child: Row(children: [
              const Expanded(
                  flex: 3,
                  child: Text('Total (နှစ်တစ်နှစ်)',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900))),
              Expanded(
                  flex: 2,
                  child: Text(moneyFmt.format(totalAmt),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text(moneyFmt.format(totalComm),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text(moneyFmt.format(totalTot),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 1,
                  child: Text('$totalCount',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.right)),
            ]),
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
        title: Text('${widget.bossName} Yearly Report'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Year picker
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () {
                      setState(() => _selectedYear--);
                      _reload();
                    },
                  ),
                  const SizedBox(width: 12),
                  Text('$_selectedYear',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () {
                      setState(() => _selectedYear++);
                      _reload();
                    },
                  ),
                ],
              ),
            ),

            _sectionTitle(
                'Total Deposit (ဒီနှစ်အဝင်)', Colors.green),
            _buildSection(_depositTx, Colors.green, 'Deposit'),

            const SizedBox(height: 14),

            _sectionTitle(
                'Total Withdraw (ဒီနှစ်အထွက်)', Colors.red),
            _buildSection(_withdrawTx, Colors.red, 'Withdraw'),

            _sectionTitle('Summary', const Color(0xFF333333)),

            _card(Column(children: [
              _countRow('Deposit စောင်ရေ', _depositCount),
              _countRow('Withdraw စောင်ရေ', _withdrawCount),
              _countRow('Total စောင်ရေ', _totalCount, bold: true),
              const Divider(),
              _moneyRow('Total ကော်မရှင် (income)', _totalComm,
                  bold: true),
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
                    builder: (_) => YearlyReportExportScreen(
                      bossName:   widget.bossName,
                      year:       _selectedYear,
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

// ─── Data model ───────────────────────────────────────────────────────────────

class _MonthRow {
  final int    month;
  final String label;
  final int    amt;
  final int    comm;
  final int    tot;
  final int    count;

  const _MonthRow({
    required this.month,
    required this.label,
    required this.amt,
    required this.comm,
    required this.tot,
    required this.count,
  });
}
