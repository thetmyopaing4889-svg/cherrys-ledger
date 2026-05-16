import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChargeRates {
  final double kbzRate;   // e.g. 0.0002 = 0.02%
  final double cbRate;    // e.g. 0.00025 = 0.025%
  final double yomaRate;  // e.g. 0.00015 = 0.015%
  final Map<String, double> extraRates; // e.g. {"AYA": 0.0002}

  const ChargeRates({
    this.kbzRate  = 0.0002,
    this.cbRate   = 0.00025,
    this.yomaRate = 0.00015,
    this.extraRates = const {},
  });

  static const ChargeRates defaults = ChargeRates();

  Map<String, dynamic> toJson() => {
    'kbzRate':    kbzRate,
    'cbRate':     cbRate,
    'yomaRate':   yomaRate,
    'extraRates': extraRates,
  };

  static ChargeRates fromJson(Map<String, dynamic> j) => ChargeRates(
    kbzRate:    (j['kbzRate']  as num?)?.toDouble() ?? 0.0002,
    cbRate:     (j['cbRate']   as num?)?.toDouble() ?? 0.00025,
    yomaRate:   (j['yomaRate'] as num?)?.toDouble() ?? 0.00015,
    extraRates: (j['extraRates'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
        {},
  );

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
