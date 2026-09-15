import 'package:flutter/material.dart';

import '../api/auth_api.dart';
import 'error_box.dart';
import 'styles/auth_styles.dart';
import 'widgets/auth_bottom_sheet_shell.dart';
import 'widgets/auth_password_input.dart';
import 'widgets/auth_submit_button.dart';

class ChangePasswordBottomSheet extends StatefulWidget {
  final String account;
  const ChangePasswordBottomSheet({super.key, required this.account});

  @override
  State<ChangePasswordBottomSheet> createState() =>
      _ChangePasswordBottomSheetState();
}

class _ChangePasswordBottomSheetState extends State<ChangePasswordBottomSheet> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _isServerError = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _clearError(String _) {
    if (_error == null) return;
    setState(() {
      _error = null;
      _isServerError = false;
    });
  }

  Future<void> _changePassword() async {
    if (_isSubmitting) return;
    final oldPassword = _oldCtrl.text.trim();
    final newPassword = _newCtrl.text.trim();
    final confirmation = _confirmCtrl.text.trim();
    setState(() {
      _error = null;
      _isServerError = false;
    });
    if (oldPassword.isEmpty || newPassword.isEmpty || confirmation.isEmpty) {
      setState(() => _error = 'Please fill all fields');
      return;
    }
    if (newPassword != confirmation) {
      setState(() => _error = 'New passwords do not match');
      return;
    }
    setState(() => _isSubmitting = true);
    final result = await AuthApi.changePassword(
      account: widget.account,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _isSubmitting = false;
        _error = result.message;
        _isServerError = result.isServerError;
      });
      return;
    }
    Navigator.pop(context, 'success');
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
          const Text(
            'Change Password',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Update your password',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          AuthPasswordInput(
            controller: _oldCtrl,
            label: 'Old Password',
            enabled: !_isSubmitting,
            borderRadius: 16,
            showOutlineBorder: false,
            outlinedVisibilityIcons: true,
            onChanged: _clearError,
          ),
          const SizedBox(height: 16),
          AuthPasswordInput(
            controller: _newCtrl,
            label: 'New Password',
            enabled: !_isSubmitting,
            borderRadius: 16,
            showOutlineBorder: false,
            outlinedVisibilityIcons: true,
            onChanged: _clearError,
          ),
          const SizedBox(height: 16),
          AuthPasswordInput(
            controller: _confirmCtrl,
            label: 'Confirm New Password',
            enabled: !_isSubmitting,
            borderRadius: 16,
            showOutlineBorder: false,
            outlinedVisibilityIcons: true,
            onChanged: _clearError,
          ),
          const SizedBox(height: 24),
          AuthSubmitButton(
            label: 'Update Password',
            isLoading: _isSubmitting,
            onPressed: _changePassword,
            height: 48,
            borderRadius: 16,
            fontWeight: FontWeight.w600,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBox(message: _error!, isServerError: _isServerError),
          ],
        ],
      ),
    );
  }
}
