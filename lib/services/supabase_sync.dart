import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/boss.dart';
import '../models/ledger_tx.dart';

/// Offline-first Supabase sync service.
/// All methods are fire-and-forget safe — they never throw to the caller.
class SupabaseSyncService {
  static const _url = 'https://xnaplcnajoysobpendzo.supabase.co';
  static const _key = 'sb_publishable_2Msg5VeHXduv06TWIuXUyA__PPEUXhf';

  static SupabaseClient get _db => Supabase.instance.client;

  // ── Initialise ──────────────────────────────────────────────

  static Future<void> init() async {
    await Supabase.initialize(url: _url, anonKey: _key);
  }

  // ── Push helpers ─────────────────────────────────────────────

  static Future<void> upsertBoss(Boss b) async {
    try {
      await _db.from('bosses').upsert(_bossToRow(b));
    } catch (_) {}
  }

  static Future<void> upsertBosses(List<Boss> bosses) async {
    if (bosses.isEmpty) return;
    try {
      await _db.from('bosses').upsert(bosses.map(_bossToRow).toList());
    } catch (_) {}
  }

  static Future<void> deleteBossRemote(String id) async {
    try {
      await _db.from('bosses').delete().eq('id', id);
    } catch (_) {}
  }

  static Future<void> upsertTx(LedgerTx t) async {
    try {
      await _db.from('transactions').upsert(_txToRow(t));
    } catch (_) {}
  }

  static Future<void> upsertTxs(List<LedgerTx> txs) async {
    if (txs.isEmpty) return;
    try {
      await _db.from('transactions').upsert(txs.map(_txToRow).toList());
    } catch (_) {}
  }

  // ── Pull & merge ─────────────────────────────────────────────

  /// Returns remote bosses and transactions not present in local lists.
  /// Call after local load to merge any data from the other phone.
  static Future<({List<Boss> newBosses, List<LedgerTx> newTxs})>
      pullAndMerge({
    required List<Boss> localBosses,
    required List<LedgerTx> localTxs,
  }) async {
    final newBosses = <Boss>[];
    final newTxs    = <LedgerTx>[];

    try {
      final localBossIds = {for (final b in localBosses) b.id};
      final localTxIds   = {for (final t in localTxs)   t.id};

      // Pull bosses
      final remoteBosses =
          await _db.from('bosses').select().eq('deleted', false);
      for (final row in remoteBosses as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final id  = map['id'] as String? ?? '';
        if (id.isNotEmpty && !localBossIds.contains(id)) {
          newBosses.add(_bossFromRow(map));
        }
      }

      // Pull transactions (including deleted so soft-deletes propagate)
      final remoteTxs = await _db.from('transactions').select();
      for (final row in remoteTxs as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final id  = map['id'] as String? ?? '';
        if (id.isNotEmpty && !localTxIds.contains(id)) {
          newTxs.add(_txFromRow(map));
        }
      }
    } catch (_) {
      // Offline — return empty lists, app continues normally
    }

    return (newBosses: newBosses, newTxs: newTxs);
  }

  // ── Converters ───────────────────────────────────────────────

  static Map<String, dynamic> _bossToRow(Boss b) => {
        'id':                   b.id,
        'name':                 b.name,
        'country':              b.country,
        'phone':                b.phone,
        'address':              b.address,
        'opening_balance_mmk':  b.openingBalanceMmk,
        'updated_at':           DateTime.now().toUtc().toIso8601String(),
        'deleted':              false,
      };

  static Boss _bossFromRow(Map<String, dynamic> r) => Boss(
        id:                 r['id']                   as String,
        name:               r['name']                 as String? ?? '',
        country:            r['country']              as String? ?? '',
        phone:              r['phone']                as String? ?? '',
        address:            r['address']              as String? ?? '',
        openingBalanceMmk:  (r['opening_balance_mmk'] as num?)?.toInt() ?? 0,
        createdAtMs:        DateTime.now().millisecondsSinceEpoch,
      );

  static Map<String, dynamic> _txToRow(LedgerTx t) => {
        'id':            t.id,
        'boss_id':       t.bossId,
        'date_ms':       t.dateMs,
        'seq_no':        t.seqNo,
        'description':   t.description,
        'person_name':   t.personName,
        'type':          t.type,
        'amount_ks':     t.amountKs,
        'commission_ks': t.commissionKs,
        'total_ks':      t.totalKs,
        'updated_at':    DateTime.now().toUtc().toIso8601String(),
        'deleted':       t.deleted,
      };

  static LedgerTx _txFromRow(Map<String, dynamic> r) => LedgerTx(
        id:           r['id']            as String,
        bossId:       r['boss_id']       as String? ?? '',
        dateMs:       (r['date_ms']      as num?)?.toInt() ?? 0,
        seqNo:        (r['seq_no']       as num?)?.toInt() ?? 0,
        description:  r['description']   as String? ?? '',
        personName:   r['person_name']   as String? ?? '',
        type:         r['type']          as String? ?? 'deposit',
        amountKs:     (r['amount_ks']    as num?)?.toInt() ?? 0,
        commissionKs: (r['commission_ks'] as num?)?.toInt() ?? 0,
        totalKs:      (r['total_ks']     as num?)?.toInt() ?? 0,
        deleted:      (r['deleted']      as bool?) ?? false,
      );
}
