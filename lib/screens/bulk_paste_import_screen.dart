import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/ledger_tx.dart';

// ─────────────────────────────────────────────────────────────
// Method name constants
// ─────────────────────────────────────────────────────────────

const _mWavePay  = 'WavePay';
const _mKPay     = 'KPay';
const _mKBZPay   = 'KBZPay';
const _mWavePw   = 'Wave Password';
const _mKBZ      = 'KBZ';
const _mCB       = 'CB';
const _mYoma     = 'Yoma';

// ─────────────────────────────────────────────────────────────
// Charge helpers
// ─────────────────────────────────────────────────────────────

/// Returns Wave Password fee, or -1 if amount is outside the fee table.
int _wavePasswordFee(int transfer) {
  if (transfer <=    10000) return    500;
  if (transfer <=    25000) return    700;
  if (transfer <=    50000) return  1000;
  if (transfer <=   100000) return  1500;
  if (transfer <=   150000) return  2000;
  if (transfer <=   200000) return  2500;
  if (transfer <=   300000) return  3000;
  if (transfer <=   400000) return  4000;
  if (transfer <=   500000) return  4500;
  if (transfer <=   600000) return  5500;
  if (transfer <=   700000) return  6000;
  if (transfer <=   800000) return  6700;
  if (transfer <=   900000) return  7500;
  if (transfer <=  1000000) return  8000;
  if (transfer <=  2000000) return 15000;
  if (transfer <=  3000000) return 20000;
  return -1; // outside table
}

/// Banking charge rounded UP to the nearest 100 MMK.
int _bankCharge(String method, int transfer) {
  double rate;
  if      (method == _mKBZ)  rate = 0.0002;   // 0.02 %
  else if (method == _mCB)   rate = 0.00025;  // 0.025 %
  else if (method == _mYoma) rate = 0.00015;  // 0.015 %
  else return 0;
  final raw = transfer * rate;
  return (raw / 100).ceil() * 100;
}

// ─────────────────────────────────────────────────────────────
// Draft row model
// ─────────────────────────────────────────────────────────────

class _DraftRow {
  final TextEditingController nameCtrl;
  final TextEditingController methodCtrl;
  final TextEditingController transferCtrl;
  final TextEditingController commissionCtrl;
  final String originalPhone;

  _DraftRow({
    required String name,
    required String method,
    required int    transfer,
    required String phone,
    int commission = 0,
  })  : nameCtrl       = TextEditingController(text: name),
        methodCtrl     = TextEditingController(text: method),
        transferCtrl   = TextEditingController(
            text: transfer > 0 ? transfer.toString() : ''),
        commissionCtrl = TextEditingController(text: commission.toString()),
        originalPhone  = phone;

  void dispose() {
    nameCtrl.dispose();
    methodCtrl.dispose();
    transferCtrl.dispose();
    commissionCtrl.dispose();
  }

  int _parse(String s) =>
      int.tryParse(
          s.replaceAll(',', '').replaceAll(RegExp(r'\.$'), '').trim()) ??
      0;

  int    get transfer   => _parse(transferCtrl.text);
  int    get commission => _parse(commissionCtrl.text);
  String get method     => methodCtrl.text.trim();

  /// Calculated service charge. Returns -1 if Wave Password amount is outside table.
  int get charge {
    final t = transfer;
    if (t <= 0) return 0;
    if (method == _mWavePw) return _wavePasswordFee(t);
    if (method == _mKBZ || method == _mCB || method == _mYoma) {
      return _bankCharge(method, t);
    }
    return 0;
  }

  bool get outsideTable =>
      method == _mWavePw && transfer > 0 && _wavePasswordFee(transfer) < 0;

  /// amountKs = transfer + charge (charge = 0 when outside table, status = Check)
  int get amount => transfer + (charge < 0 ? 0 : charge);
  int get total  => amount + commission;

  String get status {
    if (nameCtrl.text.trim().isEmpty) return 'Check';
    if (transfer <= 0)                return 'Check';
    if (outsideTable)                 return 'Check';
    return 'OK';
  }
}

// ─────────────────────────────────────────────────────────────
// Parser
// ─────────────────────────────────────────────────────────────

class _BulkParser {
  /// Each queue block → exactly ONE draft row.
  static _DraftRow parseBlock(String block) {
    final lines = block
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return _DraftRow(name: '', method: '', transfer: 0, phone: '');
    }

    final fullText = lines.join(' ');
    final lower    = fullText.toLowerCase();

    final phone    = _findPhone(fullText);
    final method   = _detectMethod(lower);
    final transfer = _extractAmount(lower, phone);

    final name       = _extractName(lines, phone, transfer);
    final personName = name.isNotEmpty ? name : (phone.isNotEmpty ? phone : '');

    return _DraftRow(
      name:     personName,
      method:   method,
      transfer: transfer,
      phone:    phone,
    );
  }

  // ── phone ──

  static String _findPhone(String text) {
    final m = RegExp(r'09\d{7,9}').firstMatch(text);
    return m?.group(0) ?? '';
  }

  // ── method detection (priority order) ──

  static String _detectMethod(String lower) {
    // Wave Password BEFORE WavePay (overlapping keyword "wave")
    if (RegExp(r'\bwave\s*(?:pw|pass(?:w(?:or)?d|od)?)\b').hasMatch(lower) ||
        RegExp(r'\bwavepw\b').hasMatch(lower)) {
      return _mWavePw;
    }
    // KBZPay BEFORE KBZ
    if (lower.contains('kbzpay') ||
        RegExp(r'\bkbz\s*pay\b').hasMatch(lower)) {
      return _mKBZPay;
    }
    // WavePay (Wave / WavePay / wave pay)
    if (lower.contains('wavepay') ||
        RegExp(r'\bwave\s*pay\b').hasMatch(lower) ||
        RegExp(r'\bwave\b').hasMatch(lower)) {
      return _mWavePay;
    }
    // KPay
    if (RegExp(r'\bkpay\b').hasMatch(lower) ||
        RegExp(r'\bk\s*pay\b').hasMatch(lower)) {
      return _mKPay;
    }
    // KBZ acc / KBZ sp / KBZ bank → all = KBZ
    // (matched before generic \bkbz\b so we can strip qualifiers in name)
    if (RegExp(r'\bkbz\b').hasMatch(lower)) return _mKBZ;
    if (RegExp(r'\bcb\b').hasMatch(lower))   return _mCB;
    if (RegExp(r'\byoma\b').hasMatch(lower)) return _mYoma;
    return '';
  }

  // ── amount extraction ──

  static int _extractAmount(String lower, String phone) {
    var text = lower;
    if (phone.isNotEmpty) text = text.replaceAll(phone, ' ');
    text = text.replaceAll(RegExp(r'09\d{7,9}'), ' ');
    // Also remove long bank account numbers (≥10 pure digits)
    text = text.replaceAll(RegExp(r'\b\d{10,}\b'), ' ');

    // ── Combined Myanmar units: sum ALL သိန်း + ALL သောင်း ──
    // e.g. "100 သိန်း 4သောင်း" = 10,000,000 + 40,000 = 10,040,000
    final lakhRe  = RegExp(r'(\d+\.?\d*)\s*သိန်း');
    final thousRe = RegExp(r'(\d+\.?\d*)\s*သောင်း');

    int lakhTotal  = 0;
    for (final m in lakhRe.allMatches(text)) {
      final val = double.tryParse(m.group(1)!) ?? 0.0;
      lakhTotal += (val * 100000).round();
    }

    int thousTotal = 0;
    for (final m in thousRe.allMatches(text)) {
      final val = double.tryParse(m.group(1)!) ?? 0.0;
      thousTotal += (val * 10000).round();
    }

    if (lakhTotal > 0 || thousTotal > 0) return lakhTotal + thousTotal;

    // English lakh
    final lakhEn = RegExp(r'(\d+\.?\d*)\s*l(?:akh)?\b', caseSensitive: false);
    final lakhEnMatch = lakhEn.firstMatch(text);
    if (lakhEnMatch != null) {
      final val = double.tryParse(lakhEnMatch.group(1)!) ?? 0.0;
      if (val > 0) return (val * 100000).round();
    }

    // Plain number — largest wins (skip long account numbers ≥ 10 digits)
    final numRe = RegExp(r'(\d[\d,]*\.?\d*)');
    int maxVal = 0;
    for (final match in numRe.allMatches(text)) {
      final raw = match
          .group(1)!
          .replaceAll(',', '')
          .replaceAll(RegExp(r'\.$'), '');
      // Skip long bank account numbers
      if (raw.replaceAll('.', '').length >= 10) continue;
      final val = (double.tryParse(raw) ?? 0.0).round();
      if (val > maxVal) maxVal = val;
    }
    return maxVal;
  }

  // ── name extraction ──

  static String _extractName(List<String> lines, String phone, int transfer) {
    final parts = <String>[];

    for (final line in lines) {
      // Skip pure phone lines
      if (phone.isNotEmpty && line == phone) continue;
      if (RegExp(r'^09\d{7,9}$').hasMatch(line)) continue;

      // Skip pure long bank account number lines (≥ 10 digits)
      if (RegExp(r'^\d{10,}$').hasMatch(line)) continue;

      var cleaned = line;

      // Remove phone from line
      if (phone.isNotEmpty) cleaned = cleaned.replaceAll(phone, '');

      // Remove method keywords and banking qualifiers
      cleaned = _stripMethods(cleaned);

      // Remove long bank account numbers mid-line
      cleaned = cleaned.replaceAll(RegExp(r'\b\d{10,}\b'), '');

      // Remove Myanmar unit amount expressions
      cleaned = cleaned.replaceAll(RegExp(r'\d+\.?\d*\s*သိန်း'), '');
      cleaned = cleaned.replaceAll(RegExp(r'\d+\.?\d*\s*သောင်း'), '');
      cleaned = cleaned.replaceAll(
          RegExp(r'\d+\.?\d*\s*l(?:akh)?\b', caseSensitive: false), '');

      // Remove all remaining numeric tokens (plain amounts, etc.)
      cleaned = cleaned.replaceAll(RegExp(r'\b\d[\d,]*\.?\b'), '');

      // Strip punctuation noise
      cleaned = cleaned.replaceAll(RegExp(r'[.,;:\-_|]+'), ' ');
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (cleaned.isNotEmpty) parts.add(cleaned);
    }

    return parts.join(' ').trim();
  }

  static String _stripMethods(String text) {
    var t = text;
    // Wave Password first
    t = t.replaceAll(
        RegExp(r'\bwave\s*(?:pw|pass(?:w(?:or)?d|od)?)\b',
            caseSensitive: false),
        '');
    t = t.replaceAll(RegExp(r'\bwavepw\b', caseSensitive: false), '');
    // KBZPay before KBZ
    t = t.replaceAll(RegExp(r'\bkbzpay\b', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\bkbz\s*pay\b', caseSensitive: false), '');
    // WavePay
    t = t.replaceAll(RegExp(r'\bwavepay\b', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\bwave\s*pay\b', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\bwave\b', caseSensitive: false), '');
    // KPay
    t = t.replaceAll(RegExp(r'\bkpay\b', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\bk\s*pay\b', caseSensitive: false), '');
    // Banking
    t = t.replaceAll(RegExp(r'\bkbz\b', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\bcb\b', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\byoma\b', caseSensitive: false), '');
    // Strip banking qualifiers that must not leak into name
    t = t.replaceAll(RegExp(r'\bacc(?:ount)?\b', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\bsp\b', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\bspecial\b', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\bbanking?\b', caseSensitive: false), '');
    return t;
  }
}

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────

class BulkPasteImportScreen extends StatefulWidget {
  final String bossId;
  final String bossName;

  const BulkPasteImportScreen({
    super.key,
    required this.bossId,
    required this.bossName,
  });

  @override
  State<BulkPasteImportScreen> createState() => _BulkPasteImportScreenState();
}

class _BulkPasteImportScreenState extends State<BulkPasteImportScreen> {
  // ── colours ──
  static const _cherry     = Color(0xFFFF2D55);
  static const _cherryDark = Color(0xFF9F1239);
  static const _border     = Color(0xFFFFCFE0);
  static const _bgPink     = Color(0xFFFFF3F7);
  static const _wdColor    = Color(0xFFDC2626);
  static const _depColor   = Color(0xFF16A34A);

  // ── state ──
  DateTime _date  = DateTime.now();
  String _txType  = 'withdraw';
  bool   _saving  = false;

  final _pasteCtrl       = TextEditingController();
  final List<String>    _queue  = [];
  final List<_DraftRow> _drafts = [];

  // ── compact table column widths ──
  // Order: # | Name | Method | Trf | Comm | Chg | Amt | Total | OK | Del
  static const _wNo   = 28.0;
  static const _wName = 120.0;
  static const _wMeth = 100.0;
  static const _wTran =  80.0;
  static const _wComm =  76.0;
  static const _wChg  =  68.0;
  static const _wAmt  =  80.0;
  static const _wTot  =  80.0;
  static const _wStat =  44.0;
  static const _wDel  =  32.0;

  // ── auto-save key ──
  String get _sessionKey => 'bulk_session_${widget.bossId}';

  // ─────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _date = DateTime(n.year, n.month, n.day);
    txStore.load();
    _tryRestore();
  }

  @override
  void dispose() {
    _pasteCtrl.dispose();
    for (final d in _drafts) d.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Auto-save / restore
  // ─────────────────────────────────────────────────────────────

  Future<void> _autoSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'bossId': widget.bossId,
        'dateMs': _date.millisecondsSinceEpoch,
        'txType': _txType,
        'queue': _queue,
        'drafts': _drafts.map((d) => {
          'name':       d.nameCtrl.text,
          'method':     d.methodCtrl.text,
          'transfer':   d.transfer,
          'phone':      d.originalPhone,
          'commission': d.commission,
        }).toList(),
      };
      await prefs.setString(_sessionKey, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _clearSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {}
  }

  Future<void> _tryRestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_sessionKey);
      if (raw == null || raw.isEmpty) return;

      final data       = jsonDecode(raw) as Map<String, dynamic>;
      final savedBoss  = data['bossId'] as String? ?? '';
      if (savedBoss != widget.bossId) return;

      final queueList = (data['queue'] as List<dynamic>?) ?? [];
      final draftList = (data['drafts'] as List<dynamic>?) ?? [];

      if (queueList.isEmpty && draftList.isEmpty) return;

      // Show restore prompt
      if (!mounted) return;
      final restore = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22)),
          title: const Text('မပြီးသေးသော Draft',
              style: TextStyle(fontWeight: FontWeight.w900)),
          content: Text(
            'Queue ${queueList.length} ခု, Draft row ${draftList.length} ခု ရှိသေးသည်။\n'
            'ဆက်လုပ်မည်လား?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Clear', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _cherry,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );

      if (restore != true) {
        await _clearSavedSession();
        return;
      }

      // Restore date
      final dateMs = data['dateMs'] as int?;
      if (dateMs != null) {
        final d = DateTime.fromMillisecondsSinceEpoch(dateMs);
        _date = DateTime(d.year, d.month, d.day);
      }

      // Restore txType
      final txType = data['txType'] as String?;
      if (txType != null) _txType = txType;

      // Restore queue
      _queue.addAll(queueList.map((e) => e.toString()));

      // Restore draft rows
      for (final item in draftList) {
        final m = item as Map<String, dynamic>;
        _drafts.add(_DraftRow(
          name:       m['name']       as String? ?? '',
          method:     m['method']     as String? ?? '',
          transfer:   m['transfer']   as int?    ?? 0,
          phone:      m['phone']      as String? ?? '',
          commission: m['commission'] as int?    ?? 0,
        ));
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _fmtN(int v) {
    if (v == 0) return '0';
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final fe = s.length - i;
      buf.write(s[i]);
      if (fe > 1 && fe % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  int get _grandTotal  => _drafts.fold(0, (s, d) => s + d.total);
  int get _grandAmount => _drafts.fold(0, (s, d) => s + d.amount);
  int get _grandComm   => _drafts.fold(0, (s, d) => s + d.commission);

  // ─────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate:  DateTime(2100),
    );
    if (p != null) {
      setState(() => _date = DateTime(p.year, p.month, p.day));
      _autoSave();
    }
  }

  void _addToQueue() {
    final t = _pasteCtrl.text.trim();
    if (t.isEmpty) { _snack('ကူးကပ်ထားသောစာသား မရှိပါ။'); return; }
    setState(() { _queue.add(t); _pasteCtrl.clear(); });
    _autoSave();
  }

  void _clearQueue() {
    setState(() { _queue.clear(); _drafts.clear(); });
    _clearSavedSession();
  }

  void _parseAll() {
    if (_queue.isEmpty) {
      _snack('Queue မရှိသေးပါ။ Add to Queue နှိပ်ပါ။');
      return;
    }
    for (final d in _drafts) d.dispose();
    _drafts.clear();
    for (final block in _queue) {
      _drafts.add(_BulkParser.parseBlock(block));
    }
    setState(() {});
    _autoSave();
  }

  void _removeRow(int idx) {
    setState(() {
      _drafts[idx].dispose();
      _drafts.removeAt(idx);
    });
    _autoSave();
  }

  Future<void> _confirmSaveAll() async {
    if (_drafts.isEmpty) { _snack('Draft rows မရှိပါ။'); return; }

    final bad = _drafts.where((d) => d.status == 'Check').length;
    if (bad > 0) {
      _snack('Status = Check ဖြစ်သော row $bad ခု စစ်ဆေးပါ။');
      return;
    }

    setState(() => _saving = true);
    try {
      int seq      = txStore.nextSeqNo(widget.bossId);
      final dateMs = _date.millisecondsSinceEpoch;
      final baseMs = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < _drafts.length; i++) {
        final d = _drafts[i];
        await txStore.addTx(LedgerTx(
          id:           'bulk_${baseMs}_$i',
          bossId:       widget.bossId,
          dateMs:       dateMs,
          seqNo:        seq++,
          description:  d.method,
          personName:   d.nameCtrl.text.trim(),
          type:         _txType,
          amountKs:     d.amount,
          commissionKs: d.commission,
          totalKs:      d.total,
          deleted:      false,
        ));
      }

      // Clear saved draft session on success
      await _clearSavedSession();

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22)),
          title: const Text('သိမ်းဆည်းပြီးပါပြီ',
              style: TextStyle(fontWeight: FontWeight.w900)),
          content: Text(
              'Transaction ${_drafts.length} ခု ထည့်သွင်းပြီးပါပြီ။\n'
              'Daily Report နှင့် Export Preview တွင် ပေါ်မည်ဖြစ်ပါသည်။'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _cherry,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Paste Import',
            style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: _bgPink,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerCard(),
            _pasteCard(),
            if (_drafts.isNotEmpty) ...[
              _draftTableCard(),
              _summaryCard(),
              _confirmButton(),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Header card – boss, date, type toggle
  // ─────────────────────────────────────────────────────────────

  Widget _headerCard() => _card(
    bg: _bgPink,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.business_center_rounded,
              color: _cherry, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(widget.bossName,
                style: const TextStyle(fontSize: 17,
                    fontWeight: FontWeight.w900, color: _cherryDark),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: _decor('ရက်စွဲ', Icons.calendar_month),
              child: Text(_fmtDate(_date),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          )),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _typeToggle(),
              const SizedBox(height: 4),
              // Issue 2: helper text showing which type will be saved
              Text(
                _txType == 'withdraw'
                    ? 'ဤစာရင်းအားလုံးကို ငွေထုတ် အဖြစ်သိမ်းမည်'
                    : 'ဤစာရင်းအားလုံးကို ငွေသွင်း အဖြစ်သိမ်းမည်',
                style: TextStyle(
                  fontSize: 9,
                  color: _txType == 'withdraw' ? _wdColor : _depColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          )),
        ]),
      ],
    ),
  );

  InputDecoration _decor(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 18),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    filled: true, fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _cherry)),
  );

  Widget _typeToggle() => Container(
    height: 46,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: _bgPink,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Row(children: [
      Expanded(child: _typeBtn('ငွေသွင်း', 'deposit', _depColor)),
      const SizedBox(width: 4),
      Expanded(child: _typeBtn('ငွေထုတ်', 'withdraw', _wdColor)),
    ]),
  );

  Widget _typeBtn(String label, String type, Color color) {
    final active = _txType == type;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() => _txType = type);
        _autoSave();
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : _border),
        ),
        child: Text(label,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12,
                color: active ? Colors.white : Colors.black54)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Paste + queue card
  // ─────────────────────────────────────────────────────────────

  Widget _pasteCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Step 1 — Paste & Queue'),
        TextField(
          controller: _pasteCtrl,
          maxLines: 5,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'ဤနေရာတွင် Message text ထည့်ပါ (transaction တစ်ခု)…\n'
                'e.g.\n09123456789\nKhaing Tin Zar\nWavepay\n15. သိန်း',
            hintStyle: const TextStyle(color: Colors.black26, fontSize: 11),
            filled: true, fillColor: _bgPink,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _cherry)),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _btn('Add to Queue',
              Icons.add_circle_outline, _cherry, _addToQueue)),
          const SizedBox(width: 8),
          _btn('Clear Queue', Icons.delete_sweep_outlined,
              Colors.grey, _clearQueue, small: true),
        ]),
        if (_queue.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Queue: ${_queue.length} block(s)',
              style: const TextStyle(fontWeight: FontWeight.w800,
                  color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 6),
          Container(
            height: 70,
            decoration: BoxDecoration(
              color: _bgPink,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(6),
              itemCount: _queue.length,
              itemBuilder: (_, i) {
                final preview = _queue[i].replaceAll('\n', ' ');
                final short = preview.length > 70
                    ? '${preview.substring(0, 70)}…' : preview;
                return Text('${i + 1}. $short',
                    style: const TextStyle(fontSize: 11,
                        color: Colors.black54));
              },
            ),
          ),
          const SizedBox(height: 10),
          _btn('Parse All  (${_queue.length} block(s))',
              Icons.auto_fix_high_rounded, _cherryDark, _parseAll),
        ],
      ],
    ),
  );

  // ─────────────────────────────────────────────────────────────
  // Compact draft table card
  // Column order: # | Name | Method | Trf | Comm | Chg | Amt | Total | OK | Del
  // ─────────────────────────────────────────────────────────────

  Widget _draftTableCard() => _card(
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Step 2 — Review & Edit  (${_drafts.length} rows)'),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tableHeader(),
              ..._drafts.asMap().entries.map((e) =>
                  _tableDataRow(e.key, e.value)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _tableHeader() {
    const bg = Color(0xFFFFCFE0);
    return Row(children: [
      _hCell('#',      _wNo,   bg: bg),
      _hCell('Name',   _wName, bg: bg, left: true),
      _hCell('Method', _wMeth, bg: bg, left: true),
      _hCell('Trf',    _wTran, bg: bg),
      _hCell('Comm',   _wComm, bg: bg),
      _hCell('Chg',    _wChg,  bg: bg),
      _hCell('Amt',    _wAmt,  bg: bg),
      _hCell('Total',  _wTot,  bg: bg),
      _hCell('OK',     _wStat, bg: bg),
      SizedBox(width: _wDel, height: 28,
          child: Container(color: bg)),
    ]);
  }

  Widget _hCell(String text, double w,
      {required Color bg, bool left = false}) {
    return SizedBox(
      width: w, height: 28,
      child: Container(
        color: bg,
        alignment: left ? Alignment.centerLeft : Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(text, style: const TextStyle(
            fontSize: 9, fontWeight: FontWeight.w900, color: _cherryDark)),
      ),
    );
  }

  Widget _tableDataRow(int idx, _DraftRow d) {
    final isCheck  = d.status == 'Check';
    final rowBg    = isCheck
        ? const Color(0xFFFFF9C4)
        : (idx.isOdd ? _bgPink : Colors.white);
    final typeColor = _txType == 'deposit' ? _depColor : _wdColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // #
        _staticCell('${idx + 1}', _wNo, bg: rowBg,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),

        // Name (editable)
        _editCell(d.nameCtrl, _wName,
            onChanged: (_) { setState(() {}); _autoSave(); }),

        // Method (editable)
        _editCell(d.methodCtrl, _wMeth,
            onChanged: (_) { setState(() {}); _autoSave(); }),

        // Transfer (editable, number)
        _editCell(d.transferCtrl, _wTran,
            keyboard: TextInputType.number,
            align: TextAlign.right,
            onChanged: (_) { setState(() {}); _autoSave(); }),

        // Commission (editable, number) — before Chg/Amt so user sees it first
        _editCell(d.commissionCtrl, _wComm,
            keyboard: TextInputType.number,
            align: TextAlign.right,
            onChanged: (_) { setState(() {}); _autoSave(); }),

        // Charge (read-only, computed)
        _staticCell(
          d.charge < 0 ? '—' : _fmtN(d.charge),
          _wChg,
          bg: rowBg,
          align: Alignment.centerRight,
          style: TextStyle(
              fontSize: 9,
              color: d.charge < 0 ? Colors.orange : Colors.black54,
              fontWeight: FontWeight.w600),
        ),

        // Amount (read-only = transfer + charge)
        _staticCell(_fmtN(d.amount), _wAmt, bg: rowBg,
            align: Alignment.centerRight,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),

        // Total (read-only)
        _staticCell(_fmtN(d.total), _wTot, bg: rowBg,
            align: Alignment.centerRight,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                color: typeColor)),

        // Status badge
        SizedBox(
          width: _wStat, height: 40,
          child: Container(
            color: rowBg,
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isCheck ? Colors.orange : Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(d.status,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 8, fontWeight: FontWeight.w900)),
            ),
          ),
        ),

        // Delete
        SizedBox(
          width: _wDel, height: 40,
          child: Container(
            color: rowBg,
            alignment: Alignment.center,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 14),
              onPressed: () => _removeRow(idx),
            ),
          ),
        ),
      ],
    );
  }

  // Editable table cell
  Widget _editCell(
    TextEditingController ctrl,
    double width, {
    TextInputType keyboard = TextInputType.text,
    TextAlign align = TextAlign.left,
    ValueChanged<String>? onChanged,
  }) {
    return SizedBox(
      width: width, height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: TextField(
          controller: ctrl,
          keyboardType: keyboard,
          textAlign: align,
          style: const TextStyle(fontSize: 10),
          onChanged: onChanged,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(4))),
          ),
        ),
      ),
    );
  }

  // Read-only / static table cell
  Widget _staticCell(
    String text,
    double width, {
    Color? bg,
    Alignment align = Alignment.center,
    TextStyle? style,
  }) {
    return SizedBox(
      width: width, height: 40,
      child: Container(
        color: bg ?? Colors.white,
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(text,
            style: style ??
                const TextStyle(fontSize: 9, color: Colors.black87)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Summary card
  // ─────────────────────────────────────────────────────────────

  Widget _summaryCard() => _card(
    bg: _bgPink,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Summary'),
        _sumRow('Rows',             '${_drafts.length}'),
        _sumRow('Total Amount',     '${_fmtN(_grandAmount)} MMK'),
        _sumRow('Total Commission', '${_fmtN(_grandComm)} MMK'),
        const Divider(height: 16),
        _sumRow('Grand Total', '${_fmtN(_grandTotal)} MMK', big: true),
      ],
    ),
  );

  Widget _sumRow(String label, String value, {bool big = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: big ? _cherryDark : Colors.black54,
                  fontSize: big ? 14 : 12))),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: big ? _cherry : Colors.black87,
                  fontSize: big ? 15 : 12)),
        ]),
      );

  // ─────────────────────────────────────────────────────────────
  // Confirm Save All button
  // ─────────────────────────────────────────────────────────────

  Widget _confirmButton() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SizedBox(
      width: double.infinity, height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _cherryDark,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: _saving ? null : _confirmSaveAll,
        icon: _saving
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_alt_rounded),
        label: Text(
          _saving
              ? 'Saving…'
              : 'Confirm Save All  (${_drafts.length} rows)',
          style: const TextStyle(
              fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ),
    ),
  );

  // ─────────────────────────────────────────────────────────────
  // Shared widget helpers
  // ─────────────────────────────────────────────────────────────

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
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
            color: Color(0xFF9F1239))),
  );

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap,
      {bool small = false}) {
    return SizedBox(
      height: small ? 38 : 44,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.symmetric(horizontal: small ? 10 : 14),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: small ? 14 : 16),
        label: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: small ? 11 : 12)),
      ),
    );
  }
}
