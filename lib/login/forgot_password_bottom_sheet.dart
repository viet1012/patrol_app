import 'package:flutter/material.dart';

import '../api/auth_api.dart';
import 'login_page.dart';

class ForgotPasswordBottomSheet extends StatefulWidget {
  const ForgotPasswordBottomSheet({super.key});

  @override
  State<ForgotPasswordBottomSheet> createState() =>
      _ForgotPasswordBottomSheetState();
}

class _ForgotPasswordBottomSheetState extends State<ForgotPasswordBottomSheet> {
  final _codeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String? _error;
  bool _loading = false;

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (code.isEmpty || email.isEmpty) {
      setState(() => _error = "Please enter all fields");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AuthApi.forgotPassword(account: code, email: email);

    setState(() => _loading = false);

    if (!result.success) {
      setState(() => _error = result.message);
      return;
    }

    if (!mounted) return;

    Navigator.pop(context, true); // success
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF020617),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Forgot Password",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          /// Employee ID
          AppInput(
            controller: _codeCtrl,
            label: "Employee ID",
            icon: Icons.badge_outlined,
            isNumber: true,
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
          ),

          const SizedBox(height: 12),

          /// Email
          AppInput(
            controller: _emailCtrl,
            label: "Email",
            icon: Icons.email_outlined,
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
          ),

          const SizedBox(height: 16),

          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _verify,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text(
                      "Verify",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
