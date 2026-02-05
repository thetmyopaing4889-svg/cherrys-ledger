import 'package:flutter/material.dart';
import '../main.dart';
import '../models/boss.dart';

class AddBossScreen extends StatefulWidget {
  final Boss? editBoss;
  const AddBossScreen({super.key, this.editBoss});

  @override
  State<AddBossScreen> createState() => _AddBossScreenState();
}

class _AddBossScreenState extends State<AddBossScreen> {
  static const _cherry = Color(0xFFFF2D55);
  static const _cherryDark = Color(0xFF9F1239);
  static const _border = Color(0xFFFFCFE0);

  final _name = TextEditingController();
  final _country = TextEditingController();
  final _opening = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  bool get _isEdit => widget.editBoss != null;

  @override
  void initState() {
    super.initState();
    final b = widget.editBoss;
    if (b != null) {
      _name.text = b.name;
      _country.text = b.country;
      _opening.text = b.openingBalanceMmk.toString();
      _phone.text = b.phone;
      _address.text = b.address;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    _opening.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  int _parseInt(String s) {
    final cleaned = s.replaceAll(',', '').trim();
    return int.tryParse(cleaned) ?? 0;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final country = _country.text.trim();
    final opening = _parseInt(_opening.text);

    if (name.isEmpty || country.isEmpty || opening <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill required fields (Name, Country, Opening Balance).")),
      );
      return;
    }

    if (_isEdit) {
      final old = widget.editBoss!;
      final updated = old.copyWith(
        name: name,
        country: country,
        openingBalanceMmk: opening,
        phone: _phone.text.trim(),
        address: _address.text.trim(),
      );
      await bossStore.updateBoss(updated);
    } else {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = "b_$now";
      final b = Boss(
        id: id,
        name: name,
        country: country,
        openingBalanceMmk: opening,
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        createdAtMs: now,
      );
      await bossStore.addBoss(b);
    }

    if (mounted) Navigator.pop(context);
  }

  InputDecoration _dec(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? "Edit Boss" : "Add Boss",
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFF3F7),
        surfaceTintColor: Colors.transparent,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Boss Info", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),

              TextField(controller: _name, decoration: _dec("Boss Name (required)", Icons.person)),
              const SizedBox(height: 12),
              TextField(controller: _country, decoration: _dec("Country (required) e.g. Malaysia", Icons.public)),
              const SizedBox(height: 12),
              TextField(
                controller: _opening,
                keyboardType: TextInputType.number,
                decoration: _dec("Opening Balance (MMK) (required)", Icons.account_balance_wallet_rounded),
              ),
              const SizedBox(height: 12),
              TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: _dec("Phone (optional)", Icons.call)),
              const SizedBox(height: 12),
              TextField(controller: _address, decoration: _dec("Address (optional)", Icons.home)),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cherry,
                    foregroundColor: Colors.white,
                    elevation: 10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: _save,
                  child: Text(
                    _isEdit ? "Save Changes" : "Save Boss",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Offline mode: boss will be saved on this phone.",
                style: TextStyle(color: _cherryDark.withOpacity(0.75), fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
