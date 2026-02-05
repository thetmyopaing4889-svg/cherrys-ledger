import 'package:flutter/material.dart';
import '../models/boss.dart';
import '../state/boss_store.dart';
import 'add_boss_screen.dart';
import 'boss_detail_screen.dart';

class BossListScreen extends StatefulWidget {
  const BossListScreen({super.key});

  @override
  State<BossListScreen> createState() => _BossListScreenState();
}

class _BossListScreenState extends State<BossListScreen> {
  final BossStore _store = BossStore();
  bool _loading = true;

  static const _bg = Color(0xFFFFF3F7);
  static const _cherry = Color(0xFFFF2D55);
  static const _cherryDark = Color(0xFF9F1239);

  @override
  void initState() {
    super.initState();
    _loadBosses();
  }

  Future<void> _loadBosses() async {
    setState(() => _loading = true);
    await _store.load();
    if (!mounted) return;
    setState(() => _loading = false);
  }

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

  Future<void> _openAddBoss() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddBossScreen(store: _store)),
    );

    if (changed == true) {
      await _loadBosses();
    }
  }

  void _openBossDetail(Boss boss) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BossDetailScreen(boss: boss)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bosses = _store.bosses;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // ✅ remove back arrow on top
        title: const Text(
          "Boss List",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _cherry,
        onPressed: _openAddBoss,
        icon: const Icon(Icons.add),
        label: const Text(
          "Add Boss",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderCard(),
              const SizedBox(height: 16),
              const Text(
                "Boss Accounts",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : bosses.isEmpty
                    ? _EmptyState(onAdd: _openAddBoss)
                    : ListView.separated(
                        itemCount: bosses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, i) {
                          final b = bosses[i];
                          final bal = _formatMMK(b.openingBalanceMmk);
                          return InkWell(
                            borderRadius: BorderRadius.circular(26),
                            onTap: () => _openBossDetail(b),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: const Color(0xFFFFCFE8),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _cherry.withOpacity(0.18),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: _cherryDark,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${b.name} (${b.country})",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          bal,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize:
                                                32, // ✅ big balance like you want
                                            height: 1.05,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.2,
                                            color: _cherryDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.black.withOpacity(0.35),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const c1 = Color(0xFF9F1239);
    const c2 = Color(0xFFFF2D55);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [c1, c2],
        ),
        boxShadow: [
          BoxShadow(
            color: c2.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.bookmark, color: Colors.white),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Cherry’s Ledger",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Manage bosses, balances, and\ntransactions easily",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8F1),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.wallet,
                size: 42,
                color: Color(0xFF9F1239),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "No Boss Added Yet",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap + Add Boss to create your first ledger boss.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black.withOpacity(0.55),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8F1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFFFCFE8), width: 2),
              ),
              child: const Text(
                "Tip: Create Boss → Add Transactions → Reports",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF9F1239),
                ),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text(
                "Add Boss",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
