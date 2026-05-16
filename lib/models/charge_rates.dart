import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChargeRates {
  final double kbzRate;
  final double cbRate;
  final double yomaRate;
  final Map<String, double> extraRates;
  // null = use defaultWaveFeeTable
  final List<Map<String, int>>? waveFeeTable;

  const ChargeRates({
    this.kbzRate      = 0.0002,
    this.cbRate       = 0.00025,
    this.yomaRate     = 0.00015,
    this.extraRates   = const {},
    this.waveFeeTable,
  });

  static const ChargeRates defaults = ChargeRates();

  static const List<Map<String, int>> defaultWaveFeeTable = [
    {'max': 10000,   'fee': 500},
    {'max': 25000,   'fee': 700},
    {'max': 50000,   'fee': 1000},
    {'max': 100000,  'fee': 1500},
    {'max': 150000,  'fee': 2000},
    {'max': 200000,  'fee': 2500},
    {'max': 300000,  'fee': 3000},
    {'max': 400000,  'fee': 4000},
    {'max': 500000,  'fee': 4500},
    {'max': 600000,  'fee': 5500},
    {'max': 700000,  'fee': 6000},
    {'max': 800000,  'fee': 6700},
    {'max': 900000,  'fee': 7500},
    {'max': 1000000, 'fee': 8000},
    {'max': 2000000, 'fee': 15000},
    {'max': 3000000, 'fee': 20000},
  ];

  List<Map<String, int>> get effectiveWaveFeeTable =>
      waveFeeTable ?? defaultWaveFeeTable;

  Map<String, dynamic> toJson() => {
    'kbzRate':      kbzRate,
    'cbRate':       cbRate,
    'yomaRate':     yomaRate,
    'extraRates':   extraRates,
    if (waveFeeTable != null) 'waveFeeTable': waveFeeTable,
  };

  static ChargeRates fromJson(Map<String, dynamic> j) {
    List<Map<String, int>>? wft;
    final raw = j['waveFeeTable'];
    if (raw is List) {
      wft = raw
          .map((e) => (e as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt())))
          .toList();
    }
    return ChargeRates(
      kbzRate:      (j['kbzRate']  as num?)?.toDouble() ?? 0.0002,
      cbRate:       (j['cbRate']   as num?)?.toDouble() ?? 0.00025,
      yomaRate:     (j['yomaRate'] as num?)?.toDouble() ?? 0.00015,
      extraRates:   (j['extraRates'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      waveFeeTable: wft,
    );
  }

  static Future<ChargeRates> loadForBoss(String bossId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString('charge_rates_$bossId');
      if (raw == null || raw.isEmpty) return const ChargeRates();
      return ChargeRates.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ChargeRates();
    }
  }

  Future<void> saveForBoss(String bossId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('charge_rates_$bossId', jsonEncode(toJson()));
  }
}
