import 'package:flutter/material.dart';
import '../main.dart';
import '../models/boss.dart';
import 'add_boss_screen.dart';
import 'boss_detail_screen.dart';

class BossListScreen extends StatefulWidget {
  const BossListScreen({super.key});

  @override
  State<BossListScreen> createState() => _BossListScreenState();
}

class _BossListScreenState extends State<BossListScreen> {
  static const _cherry = Color(0xFFFF2D55);
  static const _cherryDark = Color(0xFF9F1239);

  @override
  void initState() {
    super.initState();
    bossStore.load();
    txStore.load();
    bossStore.addListener(_onStore);
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

  int _currentBalance(String bossId, int opening) {
    final all = txStore.listByBoss(bossId);
    final dep =
        all.where((t) => t.type == "deposit").fold<int>(0, (s, t) => s + t.totalKs);
    final wd =
        all.where((t) => t.type == "withdraw").fold<int>(0, (s, t) => s + t.totalKs);
    return opening + dep - wd;
  }

  Future<void> _openAddBoss({Boss? edit}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddBossScreen(editBoss: edit)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bosses = bossStore.bosses;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Boss List",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false, // ✅ remove back arrow
        backgroundColor: const Color(0xFFFFF3F7),
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _cherry,
        foregroundColor: Colors.white,
        onPressed: () => _openAddBoss(),
        icon: const Icon(Icons.add),
        label: const Text(
          "Add Boss",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderCard(),
            const SizedBox(height: 16),
            const Text(
              "Boss Accounts",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: !bossStore.isLoaded
                  ? const Center(child: CircularProgressIndicator())
                  : bosses.isEmpty
                      ? _EmptyState()
                      : ListView.separated(
                          itemCount: bosses.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final b = bosses[i];
                            final bigBal = formatMMK(
                              _currentBalance(b.id, b.openingBalanceMmk),
                            );
                            return _BossCard(
                              title: "${b.name} (${b.country})",
                              balance: bigBal,
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BossDetailScreen(bossId: b.id),
                                  ),
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  static const _cherry = Color(0xFFFF2D55);
  static const _cherryDark = Color(0xFF9F1239);

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: const Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white24,
            child: Icon(Icons.bookmark, color: Colors.white),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Cherry’s Ledger",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
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
  static const _border = Color(0xFFFFCFE0);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
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
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10),
            Icon(
              Icons.account_balance_wallet_rounded,
              size: 56,
              color: Color(0xFF9F1239),
            ),
            SizedBox(height: 14),
            Text(
              "No Boss Added Yet",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 6),
            Text(
              "Tap + Add Boss to create your first ledger boss.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// NOTE: _BossCard widget ကို မင်း project ထဲမှာ အောက်ပိုင်းမှာရှိပြီးသားဖြစ်တာများလို့
// ဒီ file ကို overwrite လုပ်လို့ _BossCard class မရှိရင် build error တက်မယ်။
// အဲ့လိုဖြစ်ရင် _BossCard ရှိတဲ့ code ကို ဒီ file အောက်ဆုံးမှာ ပြန်ထည့်ရမယ်။

class _BossCard extends StatelessWidget {
  static const _cherry = Color(0xFFFF2D55);
  static const _border = Color(0xFFFFCFE0);
  static const _cherryDark = Color(0xFF9F1239);

  final String title;
  final String balance;
  final VoidCallback onTap;

  const _BossCard({
    required this.title,
    required this.balance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              offset: const Offset(0, 8),
              color: Colors.black.withOpacity(0.06),
            ),
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: _cherryDark,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    balance,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
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
  }
}
