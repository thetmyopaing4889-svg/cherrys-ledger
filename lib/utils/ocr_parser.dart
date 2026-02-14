class OcrParsed {
  final String phone;
  final String method; // "Kpay" | "WavePay" | "WavePass" | ""
  final String name;
  final int amount;

  const OcrParsed({
    required this.phone,
    required this.method,
    required this.name,
    required this.amount,
  });
}

class OcrParser {
  static OcrParsed parse(String raw) {
    // 0) Pre-normalize
    var s = raw.toLowerCase();

    // unify whitespace/newlines
    s = s.replaceAll('\r', '\n');
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAll(RegExp(r'\n{2,}'), '\n').trim();

    // normalize kpay variants
    s = s.replaceAll(RegExp(r'\b(kbz\s*pay|kbzpay|k\s*pay|kpay|kp)\b'), 'kpay');

    // normalize wave pass variants -> wavepass
    s = s.replaceAll(
      RegExp(r'\b(wave\s*(with\s*)?(pw|pass|password|passcode)|wave\s*(pw|pass|password|passcode))\b'),
      'wavepass',
    );

    // normalize wave account variants to wave (method group)
    s = s.replaceAll(RegExp(r'\b(wave\s*acc|wave\s*account|wave\s*a\/c)\b'), 'wave');

    // 1) Phone extract (first match)
    final phoneMatch = RegExp(r'09\d{7,9}').firstMatch(s);
    final phone = phoneMatch?.group(0) ?? '';

    // 2) Method extract (keyword-based)
    String method = '';
    if (s.contains('wavepass') || RegExp(r'\bwave\b.*\b(pw|pass|password|passcode)\b').hasMatch(s)) {
      method = 'WavePass';
    } else if (s.contains('wave')) {
      method = 'WavePay';
    } else if (s.contains('kpay')) {
      method = 'Kpay';
    }

    // 3) Amount extract
    int amount = _extractAmount(s, phone);

    // 4) Name extract (tolerant)
    final name = _extractName(s, phone, method, amount);

    return OcrParsed(phone: phone, method: method, name: name, amount: amount);
  }

  static int _extractAmount(String s, String phone) {
    // Rule A: unit words (Myanmar + English shorthand)
    // 30 သိန်း / 30l / 30L / 30 lakh
    final lakh = RegExp(r'(\d+(?:[.,]\d+)?)\s*(သိန်း|l|lakh)\b');
    final thousand10 = RegExp(r'(\d+(?:[.,]\d+)?)\s*(သောင်း)\b');

    final m1 = lakh.firstMatch(s);
    if (m1 != null) {
      final n = _toInt(m1.group(1));
      if (n > 0) return n * 100000;
    }

    final m2 = thousand10.firstMatch(s);
    if (m2 != null) {
      final n = _toInt(m2.group(1));
      if (n > 0) return n * 10000;
    }

    // Rule B: largest number wins (exclude phone)
    var t = s;
    if (phone.isNotEmpty) t = t.replaceAll(phone, ' ');
    t = t.replaceAll(RegExp(r'09\d{7,9}'), ' ');

    // keep only numeric tokens
    final nums = RegExp(r'\b\d{3,}\b').allMatches(t).map((m) => int.tryParse(m.group(0)!) ?? 0).toList();
    if (nums.isEmpty) {
      // fallback even for small numbers like 30 (if no unit)
      final smalls = RegExp(r'\b\d+\b').allMatches(t).map((m) => int.tryParse(m.group(0)!) ?? 0).toList();
      if (smalls.isEmpty) return 0;
      smalls.sort();
      return smalls.last;
    }
    nums.sort();
    return nums.last;
  }

  static String _extractName(String s, String phone, String method, int amount) {
    // remove obvious tokens then pick meaningful line
    var t = s;

    if (phone.isNotEmpty) t = t.replaceAll(phone, ' ');
    if (amount > 0) {
      t = t.replaceAll(amount.toString(), ' ');
      // also remove unit forms if present
      t = t.replaceAll(RegExp(r'\b\d+(?:[.,]\d+)?\s*(သိန်း|သောင်း|l|lakh)\b'), ' ');
    }

    // remove method keywords
    t = t.replaceAll('kpay', ' ');
    t = t.replaceAll('wavepass', ' ');
    t = t.replaceAll(RegExp(r'\bwave\b'), ' ');

    // remove extra punctuation
    t = t.replaceAll(RegExp(r'[,:;|•·\-_=]+'), ' ');
    t = t.replaceAll(RegExp(r'[ ]+'), ' ');
    t = t.replaceAll(RegExp(r'\n[ ]+'), '\n').trim();

    // choose best line: first non-empty line with letters/myanmar chars
    final lines = t.split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    for (final line in lines) {
      // avoid pure numbers
      if (RegExp(r'^\d+$').hasMatch(line)) continue;
      return line;
    }

    // fallback: empty
    return '';
  }

  static int _toInt(String? s) {
    if (s == null) return 0;
    final cleaned = s.replaceAll(',', '').replaceAll('.', '').trim();
    return int.tryParse(cleaned) ?? 0;
  }
}
