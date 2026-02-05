import 'package:flutter/material.dart';
import '../models/boss.dart';

class BossDetailScreen extends StatelessWidget {
  final Boss boss;
  const BossDetailScreen({super.key, required this.boss});

  static const _bg = Color(0xFFFFF3F7);
  static const _cherryDark = Color(0xFF9F1239);

  static String _formatMMK(int v) {
    final s = v.toString();
    final out = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      out.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) out.write(',');
    }
    return "${out.toString()} MMK";
  }

  @override
  Widget build(BuildContext context) {
    final bal = _formatMMK(boss.openingBalanceMmk);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Boss Detail",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFFFCFE8), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${boss.name} (${boss.country})",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      bal,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: _cherryDark,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (boss.phone.trim().isNotEmpty)
                      Text(
                        "Phone: ${boss.phone}",
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    if (boss.address.trim().isNotEmpty)
                      Text(
                        "Address: ${boss.address}",
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Center(
                  child: Text(
                    "Next: Transactions + Reports (Locked logic later)",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.black.withOpacity(0.55),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
