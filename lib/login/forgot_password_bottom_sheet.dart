import 'package:flutter/material.dart';

import '../api/auth_api.dart';
import 'error_box.dart';
import 'login_page.dart'; // chứa AppInput

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
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    if (widget.account != null) {
      _codeCtrl.text = widget.account!;

      // 👉 delay để UI render xong rồi mới focus
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _emailFocus.requestFocus();
        }
      });
    }
  }

  ////////////////////////////////////////////////////////////
  /// VERIFY
  ////////////////////////////////////////////////////////////
  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (code.isEmpty || email.isEmpty) {
      setState(() {
        _error = "Please enter all fields";
        _isServerError = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _isServerError = false;
    });

    final result = await AuthApi.forgotPassword(account: code, email: email);

    if (!mounted) return;

    setState(() => _loading = false);

    if (!result.success) {
      setState(() {
        _error = result.message;
        _isServerError = result.isServerError;
      });
      return;
    }

    Navigator.pop(context, true);
  }

  ////////////////////////////////////////////////////////////
  /// UI
  ////////////////////////////////////////////////////////////
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

          ////////////////////////////////////////////////////////////
          /// Employee ID
          ////////////////////////////////////////////////////////////
          AppInput(
            controller: _codeCtrl,
            label: "Employee ID",
            icon: Icons.badge_outlined,
            isNumber: true,
            onChanged: (_) {
              if (_error != null) {
                setState(() {
                  _error = null;
                  _isServerError = false;
                });
              }
            },
          ),

          const SizedBox(height: 12),

          ////////////////////////////////////////////////////////////
          /// Email
          ////////////////////////////////////////////////////////////
          AppInput(
            controller: _emailCtrl,
            label: "Email",
            icon: Icons.email_outlined,
            focusNode: _emailFocus,
            // 👈 KEY
            onChanged: (_) {
              if (_error != null) {
                setState(() {
                  _error = null;
                  _isServerError = false;
                });
              }
            },
          ),
          const SizedBox(height: 16),

          ////////////////////////////////////////////////////////////
          /// ERROR BOX
          ////////////////////////////////////////////////////////////
          if (_error != null) ...[
            const SizedBox(height: 10),
            ErrorBox(message: _error!, isServerError: _isServerError),
          ],

          const SizedBox(height: 10),

          ////////////////////////////////////////////////////////////
          /// BUTTON
          ////////////////////////////////////////////////////////////
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
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
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

  ////////////////////////////////////////////////////////////
  /// DISPOSE
  ////////////////////////////////////////////////////////////
  @override
  void dispose() {
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    _emailFocus.dispose(); // 👈 nhớ
    super.dispose();
  }
}
