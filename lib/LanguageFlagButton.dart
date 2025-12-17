import 'package:flutter/material.dart';
import 'main.dart';

class LanguageToggleSwitch extends StatefulWidget {
  final Function(String langCode)? onLanguageChanged; // 👈 callback

  const LanguageToggleSwitch({super.key, this.onLanguageChanged});

  @override
  State<LanguageToggleSwitch> createState() => _LanguageToggleSwitchState();
}

class _LanguageToggleSwitchState extends State<LanguageToggleSwitch> {
  bool isVietnamese = true;

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   final lang = Localizations.localeOf(context).languageCode;
  //   final newIsVi = lang == 'vi';
  //
  //   if (isVietnamese != (lang == 'vi')) {
  //     setState(() {
  //       isVietnamese = lang == 'vi';
  //     });
  //
  //     // 🔁 sync lại cho cha
  //     widget.onLanguageChanged?.call(newIsVi ? "VI" : "JP");
  //   }
  // }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final lang = Localizations.localeOf(context).languageCode;
    final newIsVi = lang == 'vi';

    if (isVietnamese != newIsVi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => isVietnamese = newIsVi);
      });
    }
  }

  void _toggleLanguage() {
    final newLocale = isVietnamese ? const Locale('ja') : const Locale('vi');
    MyApp.of(context)!.setLocale(newLocale);

    final newLangCode = isVietnamese ? "JP" : "VI";
    // bắn ngược cho cha
    widget.onLanguageChanged?.call(newLangCode);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleLanguage,
      child: Container(
        width: 80,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          // gradient: LinearGradient(colors: Colors.white),
          color: Colors.blueGrey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 60,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            // gradient: LinearGradient(colors: Colors.white),
            color: Colors.blueGrey.shade400,
            borderRadius: BorderRadius.circular(4),
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
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

              AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment: isVietnamese
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: SizedBox(
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
      ),
    );
  }
}
