import 'package:flutter/material.dart';
import 'daily_report_screen.dart';

class ReportsMenuScreen extends StatelessWidget {
  final String bossId;
  final String bossName;

  const ReportsMenuScreen({
    super.key,
    required this.bossId,
    required this.bossName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Report ရွေးရန်",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _bigBtn(
              context,
              title: "Daily Report (နေ့စဉ်)",
              icon: Icons.calendar_today_rounded,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        DailyReportScreen(bossId: bossId, bossName: bossName),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _bigBtn(
              context,
              title: "Monthly Report (လစဉ်)",
              icon: Icons.date_range_rounded,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Monthly Report ကို နောက်တစ်ဆင့် ဆက်လုပ်မယ်"),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _bigBtn(
              context,
              title: "Yearly Report (နှစ်စဉ်)",
              icon: Icons.bar_chart_rounded,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Yearly Report ကို နောက်တစ်ဆင့် ဆက်လုပ်မယ်"),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigBtn(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD0DA)),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(0.06),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEFF3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFFE91E63)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
