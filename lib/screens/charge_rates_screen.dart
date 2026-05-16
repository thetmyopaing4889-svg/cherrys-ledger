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

  // Wave fee table rows: each entry = {maxCtrl, feeCtrl}
  final List<Map<String, TextEditingController>> _waveFeeRows = [];

  bool _loading = true;
  bool _saving  = false;

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
    _disposeWaveRows();
    super.dispose();
  }

  void _disposeWaveRows() {
    for (final row in _waveFeeRows) {
      row['max']!.dispose();
      row['fee']!.dispose();
    }
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

      _disposeWaveRows();
      _waveFeeRows.clear();
      for (final entry in rates.effectiveWaveFeeTable) {
        _waveFeeRows.add({
          'max': TextEditingController(text: (entry['max'] ?? 0).toString()),
          'fee': TextEditingController(text: (entry['fee'] ?? 0).toString()),
        });
      }

      _loading = false;
    });
  }

  String _fmtPct(double v) {
    final pct = v * 100;
    if (pct == pct.truncateToDouble()) return pct.toStringAsFixed(0);
    return pct
        .toStringAsFixed(4)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  double _parsePct(String s) =>
      (double.tryParse(s.replaceAll(',', '').trim()) ?? 0.0) / 100;

  int _parseInt(String s) =>
      int.tryParse(s.replaceAll(',', '').trim()) ?? 0;

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

  void _addWaveFeeRow() {
    setState(() {
      _waveFeeRows.add({
        'max': TextEditingController(),
        'fee': TextEditingController(),
      });
    });
  }

  void _removeWaveFeeRow(int index) {
    setState(() {
      _waveFeeRows[index]['max']!.dispose();
      _waveFeeRows[index]['fee']!.dispose();
      _waveFeeRows.removeAt(index);
    });
  }

  Future<void> _save() async {
    for (int i = 0; i < _extraRows.length; i++) {
      if (_extraRows[i]['name']!.text.trim().isEmpty) {
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
        if (name.isNotEmpty) extra[name] = _parsePct(row['rate']!.text);
      }

      List<Map<String, int>>? wft;
      if (_waveFeeRows.isNotEmpty) {
        wft = _waveFeeRows.map((row) => {
          'max': _parseInt(row['max']!.text),
          'fee': _parseInt(row['fee']!.text),
        }).toList();
      }

      final rates = ChargeRates(
        kbzRate:      _parsePct(_kbzCtrl.text),
        cbRate:       _parsePct(_cbCtrl.text),
        yomaRate:     _parsePct(_yomaCtrl.text),
        extraRates:   extra,
        waveFeeTable: wft,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Default rate တွေပြန်ထည့်မလား?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
            'KBZ 0.02% | CB 0.025% | Yoma 0.015%\n'
            'Wave Password ဇယားနဲ့ ထပ်ထည့်ထားတဲ့ ဘဏ်တွေ ပြန်ခြေစင်မယ်။'),
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
        _disposeWaveRows();
        _waveFeeRows.clear();
        for (final entry in ChargeRates.defaultWaveFeeTable) {
          _waveFeeRows.add({
            'max': TextEditingController(text: (entry['max'] ?? 0).toString()),
            'fee': TextEditingController(text: (entry['fee'] ?? 0).toString()),
          });
        }
      });
    }
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
                style: TextStyle(color: _cherry, fontWeight: FontWeight.w700)),
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
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        _rateField('KBZ Bank', _kbzCtrl, '0.02'),
                        const SizedBox(height: 12),
                        _rateField('CB Bank', _cbCtrl, '0.025'),
                        const SizedBox(height: 12),
                        _rateField('Yoma Bank', _yomaCtrl, '0.015'),

                        if (_extraRows.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          _sectionLabel('ထပ်ထည့်ထားတဲ့ ဘဏ်တွေ'),
                          for (int i = 0; i < _extraRows.length; i++)
                            _extraRateRow(i),
                        ],

                        const SizedBox(height: 16),
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

                  // ── Wave Password Fee Table (editable) ──
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.table_chart_outlined,
                                size: 16, color: Color(0xFF9F1239)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Wave Password — Fee Table',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF9F1239)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'ပမာဏ (max) နဲ့ ကြေးကို ပြင်လို့ ရတယ်။ '
                          'အပေါ်ဆုံး row ရဲ့ max ကျော်ရင် Check ပြမည်။',
                          style: TextStyle(fontSize: 11, color: Colors.black45),
                        ),
                        const SizedBox(height: 12),

                        // Header row
                        Row(
                          children: const [
                            SizedBox(width: 28),
                            Expanded(
                              flex: 5,
                              child: Text('အများဆုံး (MMK)',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF9F1239))),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: Text('ကြေး (MMK)',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF9F1239))),
                            ),
                            SizedBox(width: 36),
                          ],
                        ),
                        const SizedBox(height: 8),

                        for (int i = 0; i < _waveFeeRows.length; i++)
                          _waveFeeRow(i),

                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blueGrey,
                            side: const BorderSide(color: Colors.blueGrey),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          onPressed: _addWaveFeeRow,
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Row ထပ်ထည့်မည်',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
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
                                  strokeWidth: 2, color: Colors.white))
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

  Widget _waveFeeRow(int index) {
    final row = _waveFeeRows[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${index + 1}.',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ),
          Expanded(
            flex: 5,
            child: TextField(
              controller: row['max'],
              keyboardType: TextInputType.number,
              decoration: _compactDeco('e.g. 10000'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: TextField(
              controller: row['fee'],
              keyboardType: TextInputType.number,
              decoration: _compactDeco('e.g. 500'),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => _removeWaveFeeRow(index),
            icon: const Icon(Icons.delete_outline,
                color: Colors.redAccent, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'ဖယ်ရှားမည်',
          ),
        ],
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

  InputDecoration _compactDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26, fontSize: 11),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _cherry)),
      );

  Widget _rateField(String label, TextEditingController ctrl,
      String placeholder) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: '%',
        hintText: placeholder,
        hintStyle: const TextStyle(color: Colors.black26, fontSize: 11),
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

  Widget _card({required Widget child, Color? bg, EdgeInsets? padding}) =>
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
