import 'package:flutter/material.dart';
import '../models/charge_rates.dart';

class ChargeRatesScreen extends StatefulWidget {
  final String bossId;
  final String bossName;

  const ChargeRatesScreen({
    super.key,
    required this.bossId,
    required this.bossName,
  });

  @override
  State<ChargeRatesScreen> createState() => _ChargeRatesScreenState();
}

class _ChargeRatesScreenState extends State<ChargeRatesScreen> {
  static const _cherry     = Color(0xFFFF2D55);
  static const _cherryDark = Color(0xFF9F1239);
  static const _border     = Color(0xFFFFCFE0);
  static const _bgPink     = Color(0xFFFFF3F7);

  late TextEditingController _kbzCtrl;
  late TextEditingController _cbCtrl;
  late TextEditingController _yomaCtrl;

  // Extra banks: each entry = {nameCtrl, rateCtrl}
  final List<Map<String, TextEditingController>> _extraRows = [];

  bool _loading = true;
  bool _saving  = false;

  // Wave Password fee table data
  static const List<Map<String, dynamic>> _waveFeeTable = [
    {'max': 10000,   'fee': 500},
    {'max': 25000,   'fee': 700},
    {'max': 50000,   'fee': 1000},
    {'max': 100000,  'fee': 1500},
    {'max': 150000,  'fee': 2000},
    {'max': 200000,  'fee': 2500},
    {'max': 300000,  'fee': 3000},
    {'max': 400000,  'fee': 4000},
    {'max': 500000,  'fee': 4500},
    {'max': 600000,  'fee': 5500},
    {'max': 700000,  'fee': 6000},
    {'max': 800000,  'fee': 6700},
    {'max': 900000,  'fee': 7500},
    {'max': 1000000, 'fee': 8000},
    {'max': 2000000, 'fee': 15000},
    {'max': 3000000, 'fee': 20000},
  ];

  @override
  void initState() {
    super.initState();
    _kbzCtrl  = TextEditingController();
    _cbCtrl   = TextEditingController();
    _yomaCtrl = TextEditingController();
    _loadRates();
  }

  @override
  void dispose() {
    _kbzCtrl.dispose();
    _cbCtrl.dispose();
    _yomaCtrl.dispose();
    for (final row in _extraRows) {
      row['name']!.dispose();
      row['rate']!.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRates() async {
    final rates = await ChargeRates.loadForBoss(widget.bossId);
    if (!mounted) return;
    setState(() {
      _kbzCtrl.text  = _fmtPct(rates.kbzRate);
      _cbCtrl.text   = _fmtPct(rates.cbRate);
      _yomaCtrl.text = _fmtPct(rates.yomaRate);
      _extraRows.clear();
      rates.extraRates.forEach((name, rate) {
        _extraRows.add({
          'name': TextEditingController(text: name),
          'rate': TextEditingController(text: _fmtPct(rate)),
        });
      });
      _loading = false;
    });
  }

  // Store as decimal, display as % (multiply × 100)
  String _fmtPct(double v) {
    final pct = v * 100;
    if (pct == pct.truncateToDouble()) {
      return pct.toStringAsFixed(0);
    }
    return pct.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  double _parsePct(String s) =>
      (double.tryParse(s.replaceAll(',', '').trim()) ?? 0.0) / 100;

  void _addExtraRow() {
    setState(() {
      _extraRows.add({
        'name': TextEditingController(),
        'rate': TextEditingController(),
      });
    });
  }

  void _removeExtraRow(int index) {
    setState(() {
      _extraRows[index]['name']!.dispose();
      _extraRows[index]['rate']!.dispose();
      _extraRows.removeAt(index);
    });
  }

  Future<void> _save() async {
    // validate extra rows
    for (int i = 0; i < _extraRows.length; i++) {
      final name = _extraRows[i]['name']!.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bank ${i + 1} ရဲ့ နာမည် ဖြည့်ပါ')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final Map<String, double> extra = {};
      for (final row in _extraRows) {
        final name = row['name']!.text.trim();
        if (name.isNotEmpty) {
          extra[name] = _parsePct(row['rate']!.text);
        }
      }

      final rates = ChargeRates(
        kbzRate:    _parsePct(_kbzCtrl.text),
        cbRate:     _parsePct(_cbCtrl.text),
        yomaRate:   _parsePct(_yomaCtrl.text),
        extraRates: extra,
      );
      await rates.saveForBoss(widget.bossId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Charge rates သိမ်းပြီးပါပြီ။')),
      );
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetDefaults() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22)),
        title: const Text('Default rate တွေပြန်ထည့်မလား?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
            'KBZ 0.02% | CB 0.025% | Yoma 0.015%\n'
            'ထည့်ထားတဲ့ ဘဏ်အသစ်တွေ ဖျောက်သွားမယ်။'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('မလုပ်ဘူး'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cherry,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (ok == true) {
      const d = ChargeRates.defaults;
      setState(() {
        _kbzCtrl.text  = _fmtPct(d.kbzRate);
        _cbCtrl.text   = _fmtPct(d.cbRate);
        _yomaCtrl.text = _fmtPct(d.yomaRate);
        for (final row in _extraRows) {
          row['name']!.dispose();
          row['rate']!.dispose();
        }
        _extraRows.clear();
      });
    }
  }

  String _fmtMMK(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _wavePrevMax(int index) {
    if (index == 0) return '1';
    return _fmtMMK((_waveFeeTable[index - 1]['max'] as int) + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.bossName} — Charge Rates',
          style: const TextStyle(fontWeight: FontWeight.w900),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        backgroundColor: _bgPink,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _resetDefaults,
            child: const Text('Reset',
                style: TextStyle(
                    color: _cherry, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Banking Charge Rates ──
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('Banking Charge Rates'),
                        const Text(
                          'Transfer amount ရဲ့ % နှုန်းဖြင့် ကောက်ကြေးကောက်တယ်။\n'
                          'အနီးဆုံး 100 MMK ကို round up လုပ်မည်။',
                          style: TextStyle(
                              fontSize: 11, color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        _rateField('KBZ Bank', _kbzCtrl, '0.02'),
                        const SizedBox(height: 12),
                        _rateField('CB Bank', _cbCtrl, '0.025'),
                        const SizedBox(height: 12),
                        _rateField('Yoma Bank', _yomaCtrl, '0.015'),

                        // ── Extra banks ──
                        if (_extraRows.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          _sectionLabel('ထပ်ထည့်ထားတဲ့ ဘဏ်တွေ'),
                          for (int i = 0; i < _extraRows.length; i++)
                            _extraRateRow(i),
                        ],

                        const SizedBox(height: 16),
                        // Add bank button
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _cherry,
                            side: const BorderSide(color: _cherry),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          onPressed: _addExtraRow,
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('ဘဏ်အသစ် ထည့်မည်',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),

                  // ── Wave Password Fee Table ──
                  _card(
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 8),
                        title: Row(
                          children: [
                            const Icon(Icons.table_chart_outlined,
                                size: 16, color: Color(0xFF9F1239)),
                            const SizedBox(width: 8),
                            Text(
                              'Wave Password — Fee Table',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF9F1239),
                              ),
                            ),
                          ],
                        ),
                        subtitle: const Text(
                          '3 သိန်းကျော်ရင် Check ပြမည်',
                          style: TextStyle(fontSize: 11, color: Colors.black45),
                        ),
                        children: [
                          Table(
                            border: TableBorder.all(
                              color: _border,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            columnWidths: const {
                              0: FlexColumnWidth(2.5),
                              1: FlexColumnWidth(2.5),
                              2: FlexColumnWidth(1.5),
                            },
                            children: [
                              TableRow(
                                decoration: const BoxDecoration(
                                    color: Color(0xFFFFEBF2)),
                                children: [
                                  _tCell('ငွေပမာဏ (MMK)', header: true),
                                  _tCell('အထိ (MMK)', header: true),
                                  _tCell('ကြေး', header: true),
                                ],
                              ),
                              for (int i = 0;
                                  i < _waveFeeTable.length;
                                  i++)
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: i.isEven
                                        ? Colors.white
                                        : const Color(0xFFFFF9FB),
                                  ),
                                  children: [
                                    _tCell(_wavePrevMax(i)),
                                    _tCell(_fmtMMK(
                                        _waveFeeTable[i]['max'] as int)),
                                    _tCell(_fmtMMK(
                                        _waveFeeTable[i]['fee'] as int)),
                                  ],
                                ),
                              const TableRow(
                                decoration:
                                    BoxDecoration(color: Color(0xFFFFF3E0)),
                                children: [
                                  _TCell('3,000,001', bold: false),
                                  _TCell('အထက်', bold: false),
                                  _TCell('Check', bold: true, orange: true),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Info note ──
                  _card(
                    bg: const Color(0xFFF0F9FF),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.blueGrey),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'WavePay, KBZPay, KPay → charge မကောက်ဘူး (0%)။',
                            style: TextStyle(
                                fontSize: 11, color: Colors.blueGrey),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cherryDark,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.save_alt_rounded),
                      label: Text(
                        _saving ? 'Saving…' : 'Save Rates',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _extraRateRow(int index) {
    final row = _extraRows[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: TextField(
              controller: row['name'],
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'ဘဏ်နာမည်',
                hintText: 'e.g. AYA',
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cherry)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: TextField(
              controller: row['rate'],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Rate',
                suffixText: '%',
                hintText: '0.02',
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cherry)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => _removeExtraRow(index),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'ဖယ်ရှားမည်',
          ),
        ],
      ),
    );
  }

  Widget _rateField(String label, TextEditingController ctrl,
      String placeholder) {
    return TextField(
      controller: ctrl,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: '%',
        hintText: placeholder,
        hintStyle:
            const TextStyle(color: Colors.black26, fontSize: 11),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _cherry)),
      ),
    );
  }

  Widget _tCell(String text, {bool header = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: header ? FontWeight.w900 : FontWeight.normal,
            color: header ? const Color(0xFF9F1239) : Colors.black87,
          ),
        ),
      );

  Widget _card(
          {required Widget child, Color? bg, EdgeInsets? padding}) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg ?? Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
                blurRadius: 12,
                offset: const Offset(0, 6),
                color: Colors.black.withOpacity(0.05)),
          ],
        ),
        child: child,
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFF9F1239))),
      );
}

// Const table cell for use inside const TableRow
class _TCell extends StatelessWidget {
  final String text;
  final bool bold;
  final bool orange;
  const _TCell(this.text, {this.bold = false, this.orange = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w900 : FontWeight.normal,
          color: orange ? Colors.orange[800] : Colors.black87,
        ),
      ),
    );
  }
}
