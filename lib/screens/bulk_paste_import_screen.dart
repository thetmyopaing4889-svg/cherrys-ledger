import 'package:flutter/material.dart';
import '../main.dart';
import '../models/ledger_tx.dart';
import '../utils/ocr_parser.dart';

// ---------------------------------------------------------------------------
// Draft row – lives only in memory until Confirm Save All
// ---------------------------------------------------------------------------
class _DraftRow {
  final TextEditingController name;
  final TextEditingController desc; // method / description
  final TextEditingController phone;
  final TextEditingController amount;
  final TextEditingController commission;
  bool hasWarning;

  _DraftRow({
    String name = '',
    String desc = '',
    String phone = '',
    String amount = '',
    String commission = '0',
    this.hasWarning = false,
  })  : name = TextEditingController(text: name),
        desc = TextEditingController(text: desc),
        phone = TextEditingController(text: phone),
        amount = TextEditingController(text: amount),
        commission = TextEditingController(text: commission);

  void dispose() {
    name.dispose();
    desc.dispose();
    phone.dispose();
    amount.dispose();
    commission.dispose();
  }

  int get amountKs => int.tryParse(amount.text.replaceAll(',', '').trim()) ?? 0;
  int get commissionKs =>
      int.tryParse(commission.text.replaceAll(',', '').trim()) ?? 0;
  int get totalKs => amountKs + commissionKs;

  bool get isValid => name.text.trim().isNotEmpty && amountKs > 0;
}

// ---------------------------------------------------------------------------
// Bulk Paste Parser
// ---------------------------------------------------------------------------
class _BulkParser {
  /// Split raw text into individual blocks separated by blank lines,
  /// then parse each block using OcrParser.
  static List<_DraftRow> parseBlocks(String rawText) {
    // Split on one or more blank lines
    final blocks = rawText
        .trim()
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();

    final rows = <_DraftRow>[];
    for (final block in blocks) {
      rows.add(_parseOne(block));
    }
    return rows;
  }

  static _DraftRow _parseOne(String block) {
    final parsed = OcrParser.parse(block);

    // Build description from method + phone
    final descParts = <String>[];
    if (parsed.method.trim().isNotEmpty) descParts.add(parsed.method.trim());
    if (parsed.phone.trim().isNotEmpty) descParts.add(parsed.phone.trim());

    final name = parsed.name.trim();
    final phone = parsed.phone.trim();
    final desc = descParts.join(' ');
    final amount = parsed.amount > 0 ? parsed.amount.toString() : '';

    final hasWarning = name.isEmpty || parsed.amount <= 0;

    return _DraftRow(
      name: name,
      desc: desc,
      phone: phone,
      amount: amount,
      commission: '0',
      hasWarning: hasWarning,
    );
  }
}

// ---------------------------------------------------------------------------
// Main Screen
// ---------------------------------------------------------------------------
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
  static const _cherry = Color(0xFFFF2D55);
  static const _cherryDark = Color(0xFF9F1239);
  static const _border = Color(0xFFFFCFE0);
  static const _withdrawColor = Color(0xFFDC2626);
  static const _depositColor = Color(0xFF16A34A);

  DateTime _date = DateTime.now();
  String _txType = 'withdraw';

  final _pasteCtrl = TextEditingController();
  final List<String> _queue = [];
  final List<_DraftRow> _drafts = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    txStore.load();
  }

  @override
  void dispose() {
    _pasteCtrl.dispose();
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  // ---- helpers ----

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _fmtMMK(int v) {
    if (v == 0) return '0 MMK';
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return '${buf.toString()} MMK';
  }

  int get _summaryTotal =>
      _drafts.fold(0, (s, d) => s + d.totalKs);
  int get _summaryAmount =>
      _drafts.fold(0, (s, d) => s + d.amountKs);
  int get _summaryCommission =>
      _drafts.fold(0, (s, d) => s + d.commissionKs);

  // ---- actions ----

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _addToQueue() {
    final text = _pasteCtrl.text.trim();
    if (text.isEmpty) {
      _snack('ကူးကပ်ထားသောစာသား မရှိပါ။');
      return;
    }
    setState(() {
      _queue.add(text);
      _pasteCtrl.clear();
    });
  }

  void _clearQueue() {
    setState(() {
      _queue.clear();
    });
  }

  void _parseAll() {
    if (_queue.isEmpty) {
      _snack('Queue တွင် block မရှိပါ။ Add to Queue ကိုအရင်နှိပ်ပါ။');
      return;
    }

    // Dispose existing drafts
    for (final d in _drafts) {
      d.dispose();
    }
    _drafts.clear();

    // Parse every queued block (each queue item may contain multiple blocks)
    for (final block in _queue) {
      final rows = _BulkParser.parseBlocks(block);
      _drafts.addAll(rows);
    }

    if (_drafts.isEmpty) {
      _snack('Parse မအောင်မြင်ပါ။ ထည့်သွင်းမှုကို စစ်ဆေးပါ။');
    }

    // Attach listeners to rebuild totals
    for (final d in _drafts) {
      d.amount.addListener(_rebuild);
      d.commission.addListener(_rebuild);
    }

    setState(() {});
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _removeDraft(int idx) {
    setState(() {
      _drafts[idx].dispose();
      _drafts.removeAt(idx);
    });
  }

  Future<void> _confirmSaveAll() async {
    // Validate
    final invalid = _drafts.where((d) => !d.isValid).toList();
    if (_drafts.isEmpty) {
      _snack('Draft rows မရှိပါ။ Parse All ကိုအရင်နှိပ်ပါ။');
      return;
    }
    if (invalid.isNotEmpty) {
      setState(() {
        for (final d in _drafts) {
          d.hasWarning = !d.isValid;
        }
      });
      _snack(
        'နာမည် သို့မဟုတ် ငွေပမာဏ မပြည့်မှီသော row ${invalid.length} ခု ရှိပါသည်။',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      int seq = txStore.nextSeqNo(widget.bossId);
      final dateMs = _date.millisecondsSinceEpoch;
      final baseMs = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < _drafts.length; i++) {
        final d = _drafts[i];
        final tx = LedgerTx(
          id: 'bulk_${baseMs}_$i',
          bossId: widget.bossId,
          dateMs: dateMs,
          seqNo: seq++,
          description: d.desc.text.trim(),
          personName: d.name.text.trim(),
          type: _txType,
          amountKs: d.amountKs,
          commissionKs: d.commissionKs,
          totalKs: d.totalKs,
          deleted: false,
        );
        await txStore.addTx(tx);
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text(
            'သိမ်းဆည်းပြီးပါပြီ',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            'Transaction ${_drafts.length} ခု ထည့်သွင်းပြီးပါပြီ။\n'
            'Daily Report နှင့် Export Preview တွင် ပေါ်မည်ဖြစ်ပါသည်။',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _cherry,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // return to BossDetail
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

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- UI ----

  InputDecoration _dec(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 18) : null,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _cherry),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: Color(0xFF9F1239),
        ),
      ),
    );
  }

  Widget _card({required Widget child, Color? bg}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg ?? Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: child,
    );
  }

  // Header card – boss + date + type
  Widget _buildHeaderCard() {
    return _card(
      bg: const Color(0xFFFFF3F7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Boss label
          Row(
            children: [
              const Icon(Icons.business_center_rounded,
                  color: _cherry, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.bossName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _cherryDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date picker row
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: _dec('ရက်စွဲ', icon: Icons.calendar_month),
                    child: Text(
                      _fmtDate(_date),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeToggle(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(child: _typeBtn('ငွေသွင်း', 'deposit', _depositColor)),
          const SizedBox(width: 4),
          Expanded(child: _typeBtn('ငွေထုတ်', 'withdraw', _withdrawColor)),
        ],
      ),
    );
  }

  Widget _typeBtn(String label, String type, Color color) {
    final active = _txType == type;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _txType = type),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: active ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  // Paste + queue section
  Widget _buildPasteSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Step 1 — Paste Text Block'),
          TextField(
            controller: _pasteCtrl,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'မောင်ဇော်\nKPay\n3000000\n09768204772',
              hintStyle: const TextStyle(color: Colors.black26),
              filled: true,
              fillColor: const Color(0xFFFFF3F7),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _cherry),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _btn(
                  label: 'Add to Queue',
                  icon: Icons.add_circle_outline,
                  color: _cherry,
                  onTap: _addToQueue,
                ),
              ),
              const SizedBox(width: 10),
              _btn(
                label: 'Clear',
                icon: Icons.delete_sweep_outlined,
                color: Colors.grey,
                onTap: _clearQueue,
                small: true,
              ),
            ],
          ),
          if (_queue.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Queue: ${_queue.length} block(s)',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _queue.length,
                itemBuilder: (_, i) => Text(
                  '${i + 1}. ${_queue[i].replaceAll('\n', ' ').substring(0, _queue[i].replaceAll('\n', ' ').length.clamp(0, 60))}…',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _btn(
              label: 'Parse All  (${_queue.length} block(s))',
              icon: Icons.auto_fix_high_rounded,
              color: _cherryDark,
              onTap: _parseAll,
            ),
          ],
        ],
      ),
    );
  }

  // Draft review list
  Widget _buildDraftSection() {
    if (_drafts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          bg: const Color(0xFFFFF3F7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Step 2 — Review & Edit Drafts'),
              Text(
                '${_drafts.length} rows  |  Total: ${_fmtMMK(_summaryTotal)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        ..._drafts.asMap().entries.map((e) => _buildDraftRow(e.key, e.value)),
        _buildSummaryCard(),
        _buildConfirmBtn(),
      ],
    );
  }

  Widget _buildDraftRow(int idx, _DraftRow d) {
    final typeColor = _txType == 'deposit' ? _depositColor : _withdrawColor;

    return _card(
      bg: d.hasWarning ? const Color(0xFFFFF3E0) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _cherry,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${idx + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (d.hasWarning)
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 18),
              if (d.hasWarning) const SizedBox(width: 4),
              if (d.hasWarning)
                const Text(
                  'စစ်ဆေးပါ',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                onPressed: () => _removeDraft(idx),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Name
          TextField(
            controller: d.name,
            decoration: _dec('နာမည် *', icon: Icons.person_outline),
            onChanged: (_) => setState(() => d.hasWarning = !d.isValid),
          ),
          const SizedBox(height: 8),

          // Method / desc
          TextField(
            controller: d.desc,
            decoration: _dec('Method / Description', icon: Icons.description_outlined),
          ),
          const SizedBox(height: 8),

          // Phone
          TextField(
            controller: d.phone,
            keyboardType: TextInputType.phone,
            decoration: _dec('Phone', icon: Icons.phone_outlined),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: d.amount,
                  keyboardType: TextInputType.number,
                  decoration: _dec('ငွေပမာဏ *', icon: Icons.payments_outlined),
                  onChanged: (_) => setState(() => d.hasWarning = !d.isValid),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: d.commission,
                  keyboardType: TextInputType.number,
                  decoration: _dec('ကော်မရှင်', icon: Icons.percent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Total per row
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Row Total',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: typeColor,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _fmtMMK(d.totalKs),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: typeColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return _card(
      bg: const Color(0xFFFFF3F7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Summary'),
          _summaryRow('Rows', '${_drafts.length}'),
          _summaryRow('Total Amount', _fmtMMK(_summaryAmount)),
          _summaryRow('Total Commission', _fmtMMK(_summaryCommission)),
          const Divider(height: 16),
          _summaryRow('Grand Total', _fmtMMK(_summaryTotal), big: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool big = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: big ? _cherryDark : Colors.black54,
                fontSize: big ? 15 : 13,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: big ? _cherry : Colors.black87,
              fontSize: big ? 16 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmBtn() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _cherryDark,
            foregroundColor: Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: _saving ? null : _confirmSaveAll,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_alt_rounded),
          label: Text(
            _saving
                ? 'Saving…'
                : 'Confirm Save All (${_drafts.length} rows)',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ),
      ),
    );
  }

  Widget _btn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool small = false,
  }) {
    return SizedBox(
      height: small ? 40 : 46,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: EdgeInsets.symmetric(horizontal: small ? 12 : 16),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: small ? 16 : 18),
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: small ? 12 : 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bulk Paste Import',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFF3F7),
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            _buildPasteSection(),
            _buildDraftSection(),
          ],
        ),
      ),
    );
  }
}
