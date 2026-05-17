import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ledger_tx.dart';
import '../services/supabase_sync.dart';

class TxStore extends ChangeNotifier {
  List<LedgerTx> get items => _txs;

  static const _kKey = 'cherrys_ledger_transactions_v1';

  final List<LedgerTx> _txs = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;

    // 1. Load local data first (fast, offline-safe)
    final sp  = await SharedPreferences.getInstance();
    final raw = sp.getString(_kKey);
    _txs.clear();
    if (raw != null && raw.trim().isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final x in list) {
        _txs.add(LedgerTx.fromJson(Map<String, dynamic>.from(x as Map)));
      }
    }
    _loaded = true;
    notifyListeners();

    // 2. Pull from Supabase in background and merge
    _syncFromCloud();
  }

  Future<void> _syncFromCloud() async {
    try {
      final result = await SupabaseSyncService.pullAndMerge(
        localBosses: [],
        localTxs:    List.from(_txs),
      );
      if (result.newTxs.isNotEmpty) {
        _txs.addAll(result.newTxs);
        await _save();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final sp  = await SharedPreferences.getInstance();
    final raw = jsonEncode(_txs.map((e) => e.toJson()).toList());
    await sp.setString(_kKey, raw);
  }

  List<LedgerTx> listByBoss(String bossId) {
    final out = _txs.where((t) => t.bossId == bossId && !t.deleted).toList();
    out.sort((a, b) {
      final d = b.dateMs.compareTo(a.dateMs);
      if (d != 0) return d;
      return b.seqNo.compareTo(a.seqNo);
    });
    return out;
  }

  int nextSeqNo(String bossId) {
    int maxSeq = 0;
    for (final t in _txs) {
      if (t.bossId == bossId && !t.deleted) {
        if (t.seqNo > maxSeq) maxSeq = t.seqNo;
      }
    }
    return maxSeq + 1;
  }

  Future<void> addTx(LedgerTx t) async {
    _txs.add(t);
    await _save();
    notifyListeners();
    SupabaseSyncService.upsertTx(t);
  }

  Future<void> softDelete(String txId) async {
    final idx = _txs.indexWhere((x) => x.id == txId);
    if (idx >= 0) {
      _txs[idx] = _txs[idx].copyWith(deleted: true);
      await _save();
      notifyListeners();
      SupabaseSyncService.upsertTx(_txs[idx]);
    }
  }

  Future<void> updateTx(LedgerTx t) async {
    final idx = _txs.indexWhere((x) => x.id == t.id);
    if (idx < 0) return;
    _txs[idx] = t;
    await _save();
    notifyListeners();
    SupabaseSyncService.upsertTx(t);
  }

  /// Push all local transactions to Supabase (initial setup for second phone).
  Future<void> pushAll() => SupabaseSyncService.upsertTxs(_txs);
}
