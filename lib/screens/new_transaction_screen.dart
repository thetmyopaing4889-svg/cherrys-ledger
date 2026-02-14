import 'package:flutter/material.dart';
import 'scan_screen.dart';
import '../utils/ocr_parser.dart';
import '../main.dart';
import '../models/ledger_tx.dart';

class NewTransactionScreen extends StatefulWidget {
  final String bossId;
  final LedgerTx? existing;
  final String? scanText;

  const NewTransactionScreen({
    super.key,
    required this.bossId,
    this.existing,
    this.scanText,
  });

  @override
  State<NewTransactionScreen> createState() => _NewTransactionScreenState();
}

class _NewTransactionScreenState extends State<NewTransactionScreen> {
  static const _cherry = Color(0xFFE11D48);
  static const _border = Color(0xFFFFCFE0);
  static const _deposit = Color(0xFF16A34A);
  static const _withdraw = Color(0xFFDC2626);

  DateTime _date = DateTime.now();
  late int _seqNo;

  String _type = "deposit"; // deposit / withdraw

  final _desc = TextEditingController();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _comm = TextEditingController(text: "0");

  int _parseInt(String s) {
    final cleaned = s.replaceAll(',', '').trim();
    return int.tryParse(cleaned) ?? 0;
  }

  int get _amountKs => _parseInt(_amount.text);
  int get _commissionKs => _parseInt(_comm.text);
  int get _totalKs => _amountKs + _commissionKs;

  @override
  void initState() {
    super.initState();

    txStore.load();

    final ex = widget.existing;

    if (ex != null) {
      // EDIT MODE
      _date = DateTime.fromMillisecondsSinceEpoch(ex.dateMs);
      _date = DateTime(_date.year, _date.month, _date.day);

      _seqNo = ex.seqNo;
      _type = ex.type;

      _desc.text = ex.description;
      _name.text = ex.personName;

      _amount.text = ex.amountKs.toString();
      _comm.text = ex.commissionKs.toString();
    } else {
      // NEW MODE
      _seqNo = txStore.nextSeqNo(widget.bossId);
      _date = DateTime(_date.year, _date.month, _date.day);

      final st = (widget.scanText ?? '').trim();
      if (st.isNotEmpty) {
        final parsed = OcrParser.parse(st); // Map<String, dynamic>

        final name = (parsed.name?? "").toString().trim();
        final method = (parsed.method?? "").toString().trim();
        final phone = (parsed.phone?? "").toString().trim();

        final amountRaw = (parsed.amount ?? 0).toString();
        final amount = int.tryParse(amountRaw) ?? 0;

        // force withdraw only
        _type = "withdraw";

        if (name.isNotEmpty) _name.text = name;

        final parts = <String>[];
        if (method.isNotEmpty) parts.add(method);
        if (phone.isNotEmpty) parts.add(phone);
        if (parts.isNotEmpty) _desc.text = parts.join(" ");

        if (amount > 0) _amount.text = amount.toString();
        // commission always manual -> do nothing
      }
    }

    _amount.addListener(_rebuild);
    _comm.addListener(_rebuild);
    _rebuild();
  }


  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _desc.dispose();
    _name.dispose();
    _amount.dispose();
    _comm.dispose();
    super.dispose();
  }

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

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _cherry),
      ),
    );
  }

  String _fmtMMK(int v) {
    final s = v.toString();
    final out = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      out.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) out.write(',');
    }
    return "${out.toString()} MMK";
  }

  Future<void> _save() async {
    final desc = _desc.text.trim();
    final name = _name.text.trim();

    if (desc.isEmpty || name.isEmpty || _amountKs <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "လိုအပ်တဲ့အချက်တွေ ဖြည့်ပေးပါ (နာမည် / အကြောင်းအရာ / ငွေပမာဏ)",
          ),
        ),
      );
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    final base = widget.existing;

    final tx = (base != null)
        ? base.copyWith(
            // keep id + seqNo same on edit
            bossId: widget.bossId,
            dateMs: _date.millisecondsSinceEpoch,
            description: desc,
            personName: name,
            type: _type,
            amountKs: _amountKs,
            commissionKs: _commissionKs,
            totalKs: _totalKs,
            deleted: false,
          )
        : LedgerTx(
            id: "t_$now",
            bossId: widget.bossId,
            dateMs: _date.millisecondsSinceEpoch,
            seqNo: _seqNo,
            description: desc,
            personName: name,
            type: _type,
            amountKs: _amountKs,
            commissionKs: _commissionKs,
            totalKs: _totalKs,
            deleted: false,
          );

    if (base != null) {
      await txStore.updateTx(tx);
    } else {
      await txStore.addTx(tx);
    }
  
    if (mounted) Navigator.pop(context, true);
  }
  @override
  Widget build(BuildContext context) {
    final typeColor = _type == "deposit" ? _deposit : _withdraw;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing != null ? "Edit Transaction" : "New Transaction",
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFF3F7),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: "Scan",
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              final scannedText = await Navigator.of(context).push<String?>(
                MaterialPageRoute(builder: (_) => const ScanScreen()),
              );
              if (!context.mounted) return;

              final t = (scannedText ?? "").trim();
              if (t.isEmpty) return;

              final parsed = OcrParser.parse(t);

              setState(() {
                _type = "withdraw";

                final name = parsed.name.trim();
                final phone = parsed.phone.trim();
                final method = parsed.method.trim();
                final amount = parsed.amount;

                if (name.isNotEmpty) {
                  _name.text = name;
                  final parts = <String>[];
                  if (method.isNotEmpty) parts.add(method);
                  if (phone.isNotEmpty) parts.add(phone);
                  _desc.text = parts.join(" ");
                } else {
                  if (phone.isNotEmpty) _name.text = phone;
                  _desc.text = method;
                }

                if (amount > 0) _amount.text = amount.toString();
              });
            },
          ),
// removed stray onPressed
              final scannedText = await Navigator.of(context).push<String?>(
                MaterialPageRoute(builder: (_) => const ScanScreen()),
              );
              if (!context.mounted) return;

              final t = (scannedText ?? "").trim();
              if (t.isEmpty) return;

              final parsed = OcrParser.parse(t);

              setState(() {
                // force withdraw only
                _type = "withdraw";

                final name = parsed.name.trim();
                final phone = parsed.phone.trim();
                final method = parsed.method.trim();
                final amount = parsed.amount;

                if (name.isNotEmpty) {
                  _name.text = name;
                  final parts = <String>[];
                  if (method.isNotEmpty) parts.add(method);
                  if (phone.isNotEmpty) parts.add(phone);
                  _desc.text = parts.join(" ");
                } else {
                  // no name -> keep phone in name field
                  if (phone.isNotEmpty) _name.text = phone;
                  _desc.text = method;
                }

                if (amount > 0) _amount.text = amount.toString();
                // commission is always manual
              });
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(0.06),
              ),
            ],
          ),
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: _dec("ရက်စွဲ", Icons.calendar_month),
                        child: Text(
                          "${_date.day}/${_date.month}/${_date.year}",
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InputDecorator(
                      decoration: _dec("အမှတ်စဉ်", Icons.confirmation_number),
                      child: Text(
                        "$_seqNo",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _desc,
                decoration: _dec(
                  "အကြောင်းအရာ (Kapay/WavePay...)",
                  Icons.description,
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _name,
                decoration: _dec("နာမည်", Icons.person),
              ),
              const SizedBox(height: 12),

              // Deposit / Withdraw Toggle
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F7),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TypeBtn(
                        text: "ငွေသွင်း",
                        active: _type == "deposit",
                        color: _deposit,
                        onTap: () => setState(() => _type = "deposit"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TypeBtn(
                        text: "ငွေထုတ်",
                        active: _type == "withdraw",
                        color: _withdraw,
                        onTap: () => setState(() => _type = "withdraw"),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: _dec("ငွေပမာဏ (ကျပ်)", Icons.payments),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _comm,
                keyboardType: TextInputType.number,
                decoration: _dec("ကော်မရှင်", Icons.percent),
              ),
              const SizedBox(height: 14),

              // Total (auto)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F7),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "စုစုပေါင်းငွေ",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: typeColor,
                        ),
                      ),
                    ),
                    Text(
                      _fmtMMK(_totalKs),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: typeColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cherry,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: _save,
                        child: const Text(
                          "Save",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String text;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _TypeBtn({
    required this.text,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? color : const Color(0xFFFFCFE0)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
