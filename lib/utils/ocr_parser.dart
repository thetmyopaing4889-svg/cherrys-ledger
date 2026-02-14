class OcrParser {
  static Map<String, dynamic> parse(String text) {
    // Normalize shorthand
    text = text.replaceAll("kp", "Kpay");
    text = text.replaceAll("wave with password", "WavePass");

    // Extract phone number
    final phoneRegex = RegExp(r'09\\d{7,9}');
    final phoneMatch = phoneRegex.firstMatch(text);
    String phone = phoneMatch != null ? phoneMatch.group(0)! : "";

    // Extract amount
    final amountRegex = RegExp(r'\\b\\d+\\b');
    final amountMatch = amountRegex.firstMatch(text);
    int amount = amountMatch != null ? int.parse(amountMatch.group(0)!) : 0;

    // Extract name (stub)
    String name = text
        .replaceAll(phone, "")
        .replaceAll(amount.toString(), "")
        .replaceAll("Kpay", "")
        .replaceAll("WavePass", "")
        .trim();

    return {
      "phone": phone,
      "name": name,
      "method": text.contains("Kpay") ? "Kpay" : text.contains("WavePass") ? "WavePass" : "",
      "amount": amount,
      "commission": 0, // user must confirm
    };
  }
}
