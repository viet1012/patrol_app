import 'package:flutter/material.dart';

class AuthStyles {
  static const background = BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF121826), Color(0xFF1F2937), Color(0xFF374151)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  static const cardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF020617)],
  );

  static const sheetGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF020617)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static InputDecoration input({
    required String label,
    required IconData icon,
    Widget? suffix,
    double borderRadius = 14,
    bool showOutlineBorder = true,
  }) {
    final emptyBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide.none,
    );

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF020617),
      disabledBorder: emptyBorder,
      enabledBorder: showOutlineBorder
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(color: Colors.white.withOpacity(.08)),
            )
          : emptyBorder,
      focusedBorder: showOutlineBorder
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: const BorderSide(
                color: Color(0xFF38BDF8),
                width: 1.2,
              ),
            )
          : emptyBorder,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      border: emptyBorder,
    );
  }
}
