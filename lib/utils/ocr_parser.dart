class OcrParsed {
  final String phone;
  final String name;
  final String method; // KPay / WavePay / WavePass / (unknown)
  final int amount;

  const OcrParsed({
    required this.phone,
    required this.name,
    required this.method,
    required this.amount,
  });
}

class OcrParser {
  static OcrParsed parse(String raw) {
    var text = raw.trim();

    // normalize spaces + lowercase for keyword checks
    final lower = text.toLowerCase();

    // method detection rules (your requirements)
    // - "wave with password" / "wave pass" / "pw" / "pass" => WavePass
    // - "wave" without pass => WavePay
    // - "kp" or "kpay" => KPay
    String method = "";
    final hasWave = lower.contains("wave");
    final hasKp = lower.contains(" kp") || lower.startsWith("kp ") || lower.contains("kpay") || lower.contains("kbzpay");

    final hasPass = lower.contains("wave with password") ||
        lower.contains("wavepass") ||
        lower.contains("wave pass") ||
        lower.contains("password") ||
        lower.contains(" pw") ||
        lower.contains("pass");

    if (hasWave && hasPass) {
      method = "WavePass";
    } else if (hasWave) {
      method = "WavePay";
    } else if (hasKp) {
      method = "KPay";
    }

    // phone: Myanmar 09xxxxxxxxx (7~9 digits after 09)
    final phoneRegex = RegExp(r'\b09\d{7,9}\b');
    final phoneMatch = phoneRegex.firstMatch(text);
    final phone = phoneMatch?.group(0) ?? "";

    // amount: pick the largest numeric chunk (handles commas)
    // examples: 30,000 / 30000 / 500000
    final numRegex = RegExp(r'\b\d[\d,]*\b');
    final nums = numRegex
        .allMatches(text)
        .map((m) => m.group(0) ?? "")
        .map((s) => s.replaceAll(",", ""))
        .where((s) => s.isNotEmpty)
        .toList();

    int amount = 0;
    if (nums.isNotEmpty) {
      // choose the biggest integer value (safer than "first")
      for (final n in nums) {
        final v = int.tryParse(n) ?? 0;
        if (v > amount) amount = v;
      }
    }

    // name: remove phone + amounts + obvious keywords
    var name = text;
    if (phone.isNotEmpty) name = name.replaceAll(phone, " ");
    for (final n in nums) {
      name = name.replaceAll(n, " ");
      name = name.replaceAll(_withCommas(n), " ");
    }

    // remove method keywords
    name = name
        .replaceAll(RegExp(r'\bkp\b', caseSensitive: false), " ")
        .replaceAll(RegExp(r'\bkpay\b', caseSensitive: false), " ")
        .replaceAll(RegExp(r'\bkbzpay\b', caseSensitive: false), " ")
        .replaceAll(RegExp(r'\bwave\b', caseSensitive: false), " ")
        .replaceAll(RegExp(r'\bpassword\b', caseSensitive: false), " ")
        .replaceAll(RegExp(r'\bpw\b', caseSensitive: false), " ")
        .replaceAll(RegExp(r'\bpass\b', caseSensitive: false), " ")
        .replaceAll(RegExp(r'\bwith\b', caseSensitive: false), " ");

    // remove common burmese fragments that appear in messages
    name = name
        .replaceAll(RegExp(r'သင့်ငွေ|ငွေ|ပို့|ရရှိ|လွှဲ|withdraw|wd', caseSensitive: false), " ")
        .replaceAll(RegExp(r'\s+'), " ")
        .trim();

    return OcrParsed(phone: phone, name: name, method: method, amount: amount);
  }

  static String _withCommas(String n) {
    // convert "30000" -> "30,000" style for replacement attempts
    final v = int.tryParse(n);
    if (v == null) return n;
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }
}
