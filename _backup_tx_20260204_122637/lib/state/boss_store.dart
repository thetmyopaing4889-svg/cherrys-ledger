import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/boss.dart';

class BossStore extends ChangeNotifier {
  static const _kKey = "cherrys_ledger_bosses_v1";

  final List<Boss> _bosses = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<Boss> get bosses => List.unmodifiable(_bosses);

  Future<void> load() async {
    if (_loaded) return;
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kKey);
    _bosses.clear();
    if (raw != null && raw.trim().isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final x in list) {
        _bosses.add(Boss.fromJson(Map<String, dynamic>.from(x as Map)));
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(_bosses.map((e) => e.toJson()).toList());
    await sp.setString(_kKey, raw);
  }

  Future<void> addBoss(Boss b) async {
    _bosses.add(b);
    await _save();
    notifyListeners();
  }

  Future<void> updateBoss(Boss b) async {
    final idx = _bosses.indexWhere((x) => x.id == b.id);
    if (idx >= 0) {
      _bosses[idx] = b;
      await _save();
      notifyListeners();
    }
  }

  Future<void> deleteBoss(String id) async {
    _bosses.removeWhere((x) => x.id == id);
    await _save();
    notifyListeners();
  }

  Boss? getById(String id) {
    try {
      return _bosses.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }
}
