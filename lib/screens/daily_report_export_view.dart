import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class DailyReportExportView extends StatelessWidget {
  final String bossName;
  final DateTime date;
  final Widget body;
  final int page;
  final int totalPages;

  const DailyReportExportView({
    super.key,
    required this.bossName,
    required this.date,
    required this.body,
    required this.page,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: MediaQuery.of(context).size.aspectRatio,
      child: Stack(
        children: [
          // Watermark
          Positioned.fill(
            child: Center(
              child: Transform.rotate(
                angle: -0.21, // ~ -12°
                child: Text(
                  "CHERRY’S LEDGER",
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Colors.black.withOpacity(0.06),
                  ),
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 12),
                Expanded(child: body),
                const SizedBox(height: 8),
                _footer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Cherry’s Ledger",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF9F1239),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Daily Report – ${date.day}/${date.month}/${date.year}",
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          "Boss: $bossName",
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _footer() {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        "Page $page / $totalPages",
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
