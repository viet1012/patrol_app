import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../styles/auth_styles.dart';

class AppInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final bool isNumber;
  final bool enabled;
  final FocusNode? focusNode;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final double borderRadius;
  final bool showOutlineBorder;

  const AppInput({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.onChanged,
    this.obscure = false,
    this.isNumber = false,
    this.enabled = true,
    this.focusNode,
    this.suffix,
    this.textInputAction,
    this.onSubmitted,
    this.borderRadius = 14,
    this.showOutlineBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber
          ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
          : null,
      textInputAction: textInputAction,
      autofillHints: isNumber
          ? const <String>[AutofillHints.username]
          : obscure
          ? const <String>[AutofillHints.password]
          : null,
      enableSuggestions: !obscure,
      autocorrect: !obscure,
      style: const TextStyle(color: Colors.white),
      decoration: AuthStyles.input(
        label: label,
        icon: icon,
        suffix: suffix,
        borderRadius: borderRadius,
        showOutlineBorder: showOutlineBorder,
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
