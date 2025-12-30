import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/auth_api.dart';

class RegisterBottomSheet extends StatefulWidget {
  const RegisterBottomSheet({super.key});

  @override
  State<RegisterBottomSheet> createState() => _RegisterBottomSheetState();
}

class _RegisterBottomSheetState extends State<RegisterBottomSheet> {
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;

  String? _errorMsg;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _register() async {
    final code = _codeCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();

    setState(() => _errorMsg = null);

    if (code.isEmpty || pass.isEmpty || confirm.isEmpty) {
      setState(() => _errorMsg = "Please fill all fields");
      return;
    }

    if (pass != confirm) {
      setState(() => _errorMsg = "Passwords do not match");
      return;
    }

    final result = await AuthApi.register(account: code, password: pass);

    if (!result.success) {
      setState(() => _errorMsg = result.message);
      return;
    }

    // ✅ ĐĂNG KÝ THÀNH CÔNG
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🎉 Register successful"),
        backgroundColor: Color(0xFF16A34A), // green
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    // Đóng bottom sheet sau 1 chút cho user kịp thấy
    await Future.delayed(const Duration(milliseconds: 600));
    Navigator.pop(context);
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
            // drag handle
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 18),

            // icon
            Image.asset(
              'assets/flags/favicon.png',
              width: 120,
              height: 120,
              filterQuality: FilterQuality.high,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 14),

            const Text(
              "Create Account",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              "Register to get started",
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 24),

            _input(
              controller: _codeCtrl,
              label: "Employee ID",
              icon: Icons.badge_outlined,
              isNumber: true,
            ),

            const SizedBox(height: 16),

            _input(
              controller: _passCtrl,
              label: "Password",
              icon: Icons.lock_outline,
              obscure: true,
            ),

            const SizedBox(height: 16),

            _input(
              controller: _confirmPassCtrl,
              label: "Confirm Password",
              icon: Icons.lock_reset_outlined,
              obscure: true,
              isConfirm: true,
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Register",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMsg!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    bool isNumber = false,
    bool isConfirm = false,
  }) {
    final isPasswordField = obscure;

    bool showPassword = isConfirm ? _showConfirmPassword : _showPassword;

    return TextField(
      controller: controller,
      obscureText: isPasswordField ? !showPassword : false,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),

        // 👁 icon xem / ẩn mật khẩu
        suffixIcon: isPasswordField
            ? IconButton(
                icon: Icon(
                  showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white60,
                ),
                onPressed: () {
                  setState(() {
                    if (isConfirm) {
                      _showConfirmPassword = !_showConfirmPassword;
                    } else {
                      _showPassword = !_showPassword;
                    }
                  });
                },
              )
            : null,

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
