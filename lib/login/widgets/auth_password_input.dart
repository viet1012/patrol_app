import 'package:flutter/material.dart';

import 'auth_input.dart';

class AuthPasswordInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final double borderRadius;
  final bool showOutlineBorder;
  final bool outlinedVisibilityIcons;

  const AuthPasswordInput({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.icon = Icons.lock_outline,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.borderRadius = 14,
    this.showOutlineBorder = true,
    this.outlinedVisibilityIcons = false,
  });

  @override
  State<AuthPasswordInput> createState() => _AuthPasswordInputState();
}

class _AuthPasswordInputState extends State<AuthPasswordInput> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return AppInput(
      controller: widget.controller,
      focusNode: widget.focusNode,
      label: widget.label,
      icon: widget.icon,
      obscure: !_showPassword,
      enabled: widget.enabled,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      borderRadius: widget.borderRadius,
      showOutlineBorder: widget.showOutlineBorder,
      suffix: IconButton(
        tooltip: _showPassword ? 'Hide password' : 'Show password',
        onPressed: widget.enabled
            ? () => setState(() => _showPassword = !_showPassword)
            : null,
        icon: Icon(
          _showPassword
              ? widget.outlinedVisibilityIcons
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_off
              : widget.outlinedVisibilityIcons
              ? Icons.visibility_outlined
              : Icons.visibility,
          color: Colors.white60,
        ),
      ),
    );
  }
}
