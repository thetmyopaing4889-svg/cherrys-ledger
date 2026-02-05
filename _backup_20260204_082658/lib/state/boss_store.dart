import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/boss.dart';

class BossStore {
  static const _kBossesKey = 'bosses_v1';

  final List<Boss> _bosses = [];

  List<Boss> get bosses => List.unmodifiable(_bosses);

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kBossesKey);
    _bosses.clear();
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _bosses.add(Boss.fromJson(item));
          } else if (item is Map) {
            _bosses.add(Boss.fromJson(item.cast<String, dynamic>()));
          }
        }
      }
    } catch (_) {
      // if corrupted, keep empty
    }
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    final list = _bosses.map((b) => b.toJson()).toList();
    await sp.setString(_kBossesKey, jsonEncode(list));
  }

  Future<void> addBoss(Boss boss) async {
    _bosses.add(boss);
    await _save();
  }

  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kBossesKey);
    _bosses.clear();
  }
}
