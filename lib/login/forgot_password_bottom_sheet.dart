import 'package:flutter/material.dart';

import '../api/auth_api.dart';
import 'error_box.dart';
import 'widgets/auth_bottom_sheet_shell.dart';
import 'widgets/auth_input.dart';
import 'widgets/auth_submit_button.dart';

class ForgotPasswordBottomSheet extends StatefulWidget {
  final String? account;
  const ForgotPasswordBottomSheet({super.key, this.account});

  @override
  State<ForgotPasswordBottomSheet> createState() =>
      _ForgotPasswordBottomSheetState();
}

class _ForgotPasswordBottomSheetState extends State<ForgotPasswordBottomSheet> {
  final _codeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  String? _error;
  bool _isServerError = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _codeCtrl.text = widget.account!;
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _emailFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _clearError(String _) {
    if (_error == null) return;
    setState(() {
      _error = null;
      _isServerError = false;
    });
  }

  Future<void> _verify() async {
    if (_isSubmitting) return;
    final code = _codeCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (code.isEmpty || email.isEmpty) {
      setState(() {
        _error = 'Please enter all fields';
        _isServerError = false;
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
      _isServerError = false;
    });
    final result = await AuthApi.forgotPassword(account: code, email: email);
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _isSubmitting = false;
        _error = result.message;
        _isServerError = result.isServerError;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AuthBottomSheetShell(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      borderRadius: 20,
      color: const Color(0xFF020617),
      showHandle: false,
      keyboardInsetInside: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Forgot Password',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          AppInput(
            controller: _codeCtrl,
            label: 'Employee ID',
            icon: Icons.badge_outlined,
            isNumber: true,
            enabled: !_isSubmitting,
            onChanged: _clearError,
          ),
          const SizedBox(height: 12),
          AppInput(
            controller: _emailCtrl,
            label: 'Email',
            icon: Icons.email_outlined,
            focusNode: _emailFocus,
            enabled: !_isSubmitting,
            onChanged: _clearError,
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            const SizedBox(height: 10),
            ErrorBox(message: _error!, isServerError: _isServerError),
          ],
          const SizedBox(height: 10),
          AuthSubmitButton(
            label: 'Verify',
            isLoading: _isSubmitting,
            onPressed: _verify,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
