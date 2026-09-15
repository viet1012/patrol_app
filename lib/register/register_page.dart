import 'package:flutter/material.dart';

import '../api/auth_api.dart';
import '../common/common_ui_helper.dart';
import '../login/error_box.dart';
import '../login/styles/auth_styles.dart';
import '../login/widgets/auth_bottom_sheet_shell.dart';
import '../login/widgets/auth_input.dart';
import '../login/widgets/auth_password_input.dart';
import '../login/widgets/auth_submit_button.dart';

class RegisterBottomSheet extends StatefulWidget {
  const RegisterBottomSheet({super.key});

  @override
  State<RegisterBottomSheet> createState() => _RegisterBottomSheetState();
}

class _RegisterBottomSheetState extends State<RegisterBottomSheet> {
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  String? _errorMsg;
  bool _isServerError = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _clearError(String _) {
    if (_errorMsg == null) return;
    setState(() {
      _errorMsg = null;
      _isServerError = false;
    });
  }

  Future<void> _register() async {
    if (_isSubmitting) return;

    final code = _codeCtrl.text.trim();
    final password = _passCtrl.text.trim();
    final confirmation = _confirmPassCtrl.text.trim();

    setState(() {
      _errorMsg = null;
      _isServerError = false;
    });

    if (code.isEmpty || password.isEmpty || confirmation.isEmpty) {
      setState(() => _errorMsg = 'Please fill all fields');
      return;
    }

    if (password != confirmation) {
      setState(() => _errorMsg = 'Passwords do not match');
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await AuthApi.register(account: code, password: password);

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isSubmitting = false;
        _errorMsg = result.message;
        _isServerError = result.isServerError;
      });
      return;
    }

    CommonUI.showSnackBar(
      context: context,
      message: 'Registration successful',
      color: Colors.green,
    );

    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return AuthBottomSheetShell(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      borderRadius: 28,
      gradient: AuthStyles.sheetGradient,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/flags/favicon.png', width: 120, height: 120),
          const SizedBox(height: 14),
          const Text(
            'Create Account',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Register to get started',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          AppInput(
            controller: _codeCtrl,
            label: 'Employee ID',
            icon: Icons.badge_outlined,
            isNumber: true,
            enabled: !_isSubmitting,
            borderRadius: 16,
            showOutlineBorder: false,
            onChanged: _clearError,
          ),
          const SizedBox(height: 16),
          AuthPasswordInput(
            controller: _passCtrl,
            label: 'Password',
            enabled: !_isSubmitting,
            borderRadius: 16,
            showOutlineBorder: false,
            outlinedVisibilityIcons: true,
            onChanged: _clearError,
          ),
          const SizedBox(height: 16),
          AuthPasswordInput(
            controller: _confirmPassCtrl,
            label: 'Confirm Password',
            icon: Icons.lock_reset_outlined,
            enabled: !_isSubmitting,
            borderRadius: 16,
            showOutlineBorder: false,
            outlinedVisibilityIcons: true,
            onChanged: _clearError,
          ),
          const SizedBox(height: 16),
          AuthSubmitButton(
            label: 'Register',
            isLoading: _isSubmitting,
            onPressed: _register,
            height: 48,
            borderRadius: 16,
            elevation: 6,
            fontWeight: FontWeight.w600,
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            ErrorBox(message: _errorMsg!, isServerError: _isServerError),
          ],
        ],
      ),
    );
  }
}
