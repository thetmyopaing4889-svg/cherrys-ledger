import 'package:flutter/material.dart';
import 'boss_list_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset("assets/images/welcome.png", fit: BoxFit.cover),
          ),

          // Love Text (White + Cherry + Glow)
          Positioned(
            top: 240,
            left: 0,
            right: 0,
            child: Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "မိန်းမကို ",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(blurRadius: 12, color: Color(0xFFFF1D48)),
                        ],
                      ),
                    ),
                    TextSpan(
                      text: "အရမ်းချစ်တယ်",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF1D48),
                        shadows: [Shadow(blurRadius: 14, color: Colors.white)],
                      ),
                    ),
                    TextSpan(
                      text: " အာဘွား ",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(blurRadius: 12, color: Color(0xFFFF1D48)),
                        ],
                      ),
                    ),
                    const TextSpan(text: "😘", style: TextStyle(fontSize: 24)),
                  ],
                ),
              ),
            ),
          ),

          // Enter Ledger Button (Cherry Color)
          Positioned(
            bottom: 60,
            left: 30,
            right: 30,
            child: SizedBox(
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const BossListScreen()),
                  );
                },
                child: const Text(
                  "Enter Ledger  →",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
