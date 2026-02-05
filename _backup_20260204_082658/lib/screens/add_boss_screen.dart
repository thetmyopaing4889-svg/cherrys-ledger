import 'package:flutter/material.dart';
import '../models/boss.dart';
import '../state/boss_store.dart';

class AddBossScreen extends StatefulWidget {
  final BossStore store;
  const AddBossScreen({super.key, required this.store});

  @override
  State<AddBossScreen> createState() => _AddBossScreenState();
}

class _AddBossScreenState extends State<AddBossScreen> {
  final _name = TextEditingController();
  final _country = TextEditingController();
  final _opening = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  bool _saving = false;

  static const _bg = Color(0xFFFFF3F7);
  static const _cherry = Color(0xFFFF2D55);
  static const _cherryDark = Color(0xFF9F1239);

  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    _opening.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  String _id() => DateTime.now().millisecondsSinceEpoch.toString();

  int _parseMmk(String s) {
    final t = s.replaceAll(',', '').trim();
    return int.tryParse(t) ?? 0;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final country = _country.text.trim();
    final opening = _parseMmk(_opening.text);

    if (name.isEmpty) {
      _toast("Boss Name is required");
      return;
    }
    if (country.isEmpty) {
      _toast("Country is required");
      return;
    }
    if (opening <= 0) {
      _toast("Opening Balance (MMK) is required");
      return;
    }

    setState(() => _saving = true);

    final boss = Boss(
      id: _id(),
      name: name,
      country: country,
      openingBalanceMmk: opening,
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    await widget.store.addBoss(boss);

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, true); // ✅ tell BossList to refresh
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _dec({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFFFCFE8), width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: _cherry, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Add Boss",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFFFCFE8), width: 2),
              boxShadow: [
                BoxShadow(
                  color: _cherry.withOpacity(0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Boss Info",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _name,
                  decoration: _dec(
                    hint: "Boss Name (required)",
                    icon: Icons.person,
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _country,
                  decoration: _dec(
                    hint: "Country (required) e.g. Malaysia",
                    icon: Icons.public,
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _opening,
                  keyboardType: TextInputType.number,
                  decoration: _dec(
                    hint: "Opening Balance (MMK) (required)",
                    icon: Icons.account_balance_wallet,
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: _dec(hint: "Phone (optional)", icon: Icons.call),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _address,
                  decoration: _dec(
                    hint: "Address (optional)",
                    icon: Icons.home,
                  ),
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cherry,
                      foregroundColor: Colors.white,
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            "Save Boss",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Offline mode: boss will appear in Boss List after saving.",
                  style: TextStyle(
                    color: _cherryDark.withOpacity(0.75),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
