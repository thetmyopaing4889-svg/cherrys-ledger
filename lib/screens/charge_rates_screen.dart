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
    super.dispose();
  }

  Future<void> _loadRates() async {
    final rates = await ChargeRates.loadForBoss(widget.bossId);
    if (!mounted) return;
    setState(() {
      _kbzCtrl.text  = _fmtPct(rates.kbzRate);
      _cbCtrl.text   = _fmtPct(rates.cbRate);
      _yomaCtrl.text = _fmtPct(rates.yomaRate);
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final rates = ChargeRates(
        kbzRate:  _parsePct(_kbzCtrl.text),
        cbRate:   _parsePct(_cbCtrl.text),
        yomaRate: _parsePct(_yomaCtrl.text),
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
        content: const Text('KBZ 0.02% | CB 0.025% | Yoma 0.015%'),
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
                        _rateField('KBZ Bank', _kbzCtrl,
                            'Default: 0.02%', '0.02'),
                        const SizedBox(height: 12),
                        _rateField('CB Bank', _cbCtrl,
                            'Default: 0.025%', '0.025'),
                        const SizedBox(height: 12),
                        _rateField('Yoma Bank', _yomaCtrl,
                            'Default: 0.015%', '0.015'),
                      ],
                    ),
                  ),
                  _card(
                    bg: const Color(0xFFF0F9FF),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Wave Password → standard fee table ကိုသုံးမည်'
                            ' (3 သိန်းကျော်ရင် Check ပြမည်)။\n'
                            'WavePay, KBZPay, KPay → charge မကောက်ဘူး'
                            ' (0%)။',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey),
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
                            fontWeight: FontWeight.w900,
                            fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _rateField(String label, TextEditingController ctrl,
      String hint, String placeholder) {
    return TextField(
      controller: ctrl,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: '%',
        hintText: hint,
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
