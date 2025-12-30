import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/auth_api.dart';

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

  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

  String? _error;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final oldP = _oldCtrl.text.trim();
    final newP = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    setState(() => _error = null);

    if (oldP.isEmpty || newP.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill all fields');
      return;
    }

    if (newP != confirm) {
      setState(() => _error = 'New passwords do not match');
      return;
    }

    final result = await AuthApi.changePassword(
      account: widget.account,
      oldPassword: oldP,
      newPassword: newP,
    );

    if (!result.success) {
      setState(() => _error = result.message);
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, 'success');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          gradient: LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF020617)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              "Change Password",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),
            const Text(
              "Update your password",
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 24),

            _passwordInput(
              ctrl: _oldCtrl,
              label: "Old Password",
              show: _showOld,
              onToggle: () => setState(() => _showOld = !_showOld),
            ),

            const SizedBox(height: 16),

            _passwordInput(
              ctrl: _newCtrl,
              label: "New Password",
              show: _showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
            ),

            const SizedBox(height: 16),

            _passwordInput(
              ctrl: _confirmCtrl,
              label: "Confirm New Password",
              show: _showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Update Password",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _passwordInput({
    required TextEditingController ctrl,
    required String label,
    required bool show,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: !show,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
        suffixIcon: IconButton(
          icon: Icon(
            show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.white60,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: const Color(0xFF020617),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
