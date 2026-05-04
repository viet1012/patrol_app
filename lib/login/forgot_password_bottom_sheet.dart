import 'package:flutter/material.dart';

import '../api/auth_api.dart';

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
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),

          const SizedBox(height: 16),

          /// Employee ID
          TextField(
            controller: _codeCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Employee ID",
              prefixIcon: Icon(Icons.badge),
            ),
          ),

          const SizedBox(height: 12),

          /// Email
          TextField(
            controller: _emailCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Email",
              prefixIcon: Icon(Icons.email),
            ),
          ),

          const SizedBox(height: 16),

          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _verify,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text("Verify"),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
