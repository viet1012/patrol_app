import 'package:flutter/material.dart';
import 'main.dart';

class LanguageToggleSwitch extends StatefulWidget {
  const LanguageToggleSwitch({super.key});

  @override
  State<LanguageToggleSwitch> createState() => _LanguageToggleSwitchState();
}

class _LanguageToggleSwitchState extends State<LanguageToggleSwitch> {
  bool isVietnamese = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode;
    if (isVietnamese != (lang == 'vi')) {
      setState(() {
        isVietnamese = lang == 'vi';
      });
    }
  }

  void _toggleLanguage() {
    final newLocale = isVietnamese ? const Locale('ja') : const Locale('vi');
    MyApp.of(context)!.setLocale(newLocale);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleLanguage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 60,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isVietnamese
                ? const [Color(0xFFCA4141), Color(0xFFEFD187)] // VN: đỏ vàng
                : const [
                    Color(0xFFE53935),
                    Color(0xFFF5F5F5),
                  ], // JP: đỏ + trắng sáng
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            isVietnamese
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        "VI",
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        "JP",
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              alignment: isVietnamese
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Container(
                width: 30,
                height: 30,
                child: Center(
                  child: Text(
                    isVietnamese ? "🇻🇳" : "🇯🇵",
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
