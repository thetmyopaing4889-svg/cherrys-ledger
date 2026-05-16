import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GlobalSettingsScreen extends StatefulWidget {
  const GlobalSettingsScreen({super.key});

  @override
  State<GlobalSettingsScreen> createState() => _GlobalSettingsScreenState();
}

class _GlobalSettingsScreenState extends State<GlobalSettingsScreen> {
  static const _cherry     = Color(0xFFFF2D55);
  static const _cherryDark = Color(0xFF9F1239);
  static const _border     = Color(0xFFFFCFE0);
  static const _bgPink     = Color(0xFFFFF3F7);
  static const _geminiPref = 'gemini_api_key';

  final _keyCtrl = TextEditingController();
  bool _loading  = true;
  bool _saving   = false;
  bool _obscure  = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _keyCtrl.text = prefs.getString(_geminiPref) ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    final key = _keyCtrl.text.trim();
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (key.isEmpty) {
        await prefs.remove(_geminiPref);
      } else {
        await prefs.setString(_geminiPref, key);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings သိမ်းပြီးပါပြီ။')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('API Key ဖျက်မလား?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Gemini AI parse feature သုံးမရတော့ဘဲ\nRegex parser သာ အသုံးပြုမည်။'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('မဖျက်ဘူး')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _cherry, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ဖျက်မည်', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (ok == true) {
      _keyCtrl.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_geminiPref);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('API Key ဖျက်ပြီးပါပြီ။')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Settings',
            style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: _bgPink,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Gemini API Key ────────────────────────────────────
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('Gemini AI — API Key'),
                        const Text(
                          'Bulk Paste Import မှာ AI Parser သုံးဖို့ လိုအပ်သည်။\n'
                          'Key မထည့်ထားလျှင် Regex parser သာ အသုံးပြုမည်။',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _keyCtrl,
                          obscureText: _obscure,
                          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            labelText: 'Gemini API Key',
                            hintText: 'AIzaSy...',
                            hintStyle: const TextStyle(color: Colors.black26, fontSize: 12),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscure ? Icons.visibility_off : Icons.visibility,
                                  size: 18, color: Colors.black38),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _border)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _cherry)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Get key link hint
                        Row(children: [
                          const Icon(Icons.open_in_new, size: 13, color: Colors.blueGrey),
                          const SizedBox(width: 4),
                          const Text(
                            'aistudio.google.com မှာ free key ရနိုင်သည်',
                            style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _cherryDark,
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: _saving ? null : _save,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 16, height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.save_alt_rounded),
                                label: Text(_saving ? 'Saving…' : 'Save Key',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900, fontSize: 14)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 46,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _clear,
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text('Clear',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),

                  // ── Info card ─────────────────────────────────────────
                  _card(
                    bg: const Color(0xFFF0F9FF),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(children: [
                          Icon(Icons.info_outline, size: 15, color: Colors.blueGrey),
                          SizedBox(width: 6),
                          Text('AI Parser အကြောင်း',
                              style: TextStyle(fontSize: 12,
                                  fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                        ]),
                        SizedBox(height: 8),
                        Text(
                          '• Regex parser က amount/method မဖတ်နိုင်သော row တွေကိုသာ AI ဆီ ပို့မည်\n'
                          '• "Parse All" တစ်ကြိမ်နှိပ်ရင် API call တစ်ကြိမ်သာ ဖြစ်သည်\n'
                          '• Gemini 1.5 Flash free tier သုံးသောကြောင့် cost မရှိ\n'
                          '• Internet မရှိလျှင် Regex parser သာ အလုပ်လုပ်မည်',
                          style: TextStyle(fontSize: 11, color: Colors.blueGrey, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _card({required Widget child, Color? bg}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg ?? Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
                blurRadius: 12,
                offset: const Offset(0, 6),
                color: Colors.black.withOpacity(0.05)),
          ],
        ),
        child: child,
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900,
                color: Color(0xFF9F1239))),
      );
}
