import 'package:flutter/material.dart';
import '../utils/ocr_parser.dart';
import 'scan_screen.dart';
import 'reports_menu_screen.dart';
import '../main.dart';
import '../models/boss.dart';
import 'add_boss_screen.dart';
import 'new_transaction_screen.dart';

class BossDetailScreen extends StatefulWidget {
  final String bossId;
  const BossDetailScreen({super.key, required this.bossId});

  @override
  State<BossDetailScreen> createState() => _BossDetailScreenState();
}

class _BossDetailScreenState extends State<BossDetailScreen> {
  int _currentBalance(String bossId, int opening) {
    final all = txStore.listByBoss(bossId);
    final dep = all.where((t) => t.type == "deposit").fold<int>(0, (s, t) => s + t.totalKs);
    final wd  = all.where((t) => t.type == "withdraw").fold<int>(0, (s, t) => s + t.totalKs);
    return opening + dep - wd;
  }

  static const _cherry = Color(0xFFFF2D55);
  static const _cherryDark = Color(0xFF9F1239);
  static const _border = Color(0xFFFFCFE0);

  @override
  void initState() {
    super.initState();
    bossStore.addListener(_onStore);
    txStore.load();
    txStore.addListener(_onStore);
  }

  @override
  void dispose() {
    bossStore.removeListener(_onStore);
    txStore.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() => setState(() {});

  static String formatMMK(int v) {
    final s = v.toString();
    final out = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      out.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) out.write(',');
    }
    return "${out.toString()} MMK";
  }

  Future<void> _edit(Boss b) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AddBossScreen(editBoss: b)));
  }

  Future<void> _delete(Boss b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Boss?"),
        content: Text("Delete ${b.name} (${b.country}) ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      await bossStore.deleteBoss(b.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = bossStore.getById(widget.bossId);

    if (b == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            "Boss Detail",
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFFFFF3F7),
          surfaceTintColor: Colors.transparent,
        ),
        body: const Center(child: Text("Boss not found.")),
      );
    }

    final currentBal = _currentBalance(b.id, b.openingBalanceMmk);
    final bigBal = formatMMK(currentBal);


    return Scaffold(
      appBar: AppBar(
        title: Text(
          b.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFF3F7),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(onPressed: () => _edit(b), icon: const Icon(Icons.edit)),
          IconButton(
            onPressed: () => _delete(b),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            // Big balance gradient card (like your nice screenshot)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(colors: [_cherryDark, _cherry]),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                    color: _cherry.withOpacity(0.25),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${b.name} (${b.country})",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    bigBal,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Current Balance (MMK)",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.80),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _InfoTile(label: "Phone", value: b.phone.isEmpty ? "-" : b.phone),
            const SizedBox(height: 10),
            _InfoTile(
              label: "Address",
              value: b.address.isEmpty ? "-" : b.address,
            ),
            const SizedBox(height: 10),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.post_add_rounded,
                    text: "New\nTransaction",
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewTransactionScreen(bossId: b.id),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.bar_chart_rounded,
                    text: "Reports",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ReportsMenuScreen(bossId: b.id, bossName: b.name),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  static const _border = Color(0xFFFFCFE0);
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8A8A8A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  static const _cherry = Color(0xFFFF2D55);

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _cherry,
          foregroundColor: Colors.white,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
