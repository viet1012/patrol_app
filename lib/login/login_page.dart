import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../animate/glow_title.dart';
import '../api/auth_api.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../register/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  String? _errorMsg;
  bool _showPassword = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _login() async {
    final code = _codeCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    setState(() => _errorMsg = null);

    if (code.isEmpty || pass.isEmpty) {
      setState(() => _errorMsg = "Please enter code and password");
      return;
    }

    final result = await AuthApi.login(account: code, password: pass);

    if (!result.success) {
      setState(() => _errorMsg = result.message);
      return;
    }

    // ✅ LOGIN OK → CHUYỂN SANG HOME
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PatrolHomeScreen(accountCode: code)),
    );
  }

  void _showRegisterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RegisterBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF121826), // soft dark blue
              Color(0xFF1F2937), // slate blue
              Color(0xFF374151), // soft steel
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF020617)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 30,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/flags/favicon.png',
                  width: 120,
                  height: 120,
                  filterQuality: FilterQuality.high,
                  fit: BoxFit.contain,
                ),
                EmbossGlowTitle(text: 'V1.1', fontSize: 13),

                const SizedBox(height: 16),

                const Text(
                  "Welcome Back",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  "Sign in to continue",
                  style: TextStyle(color: Colors.white70),
                ),

                const SizedBox(height: 26),

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

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      elevation: 6,
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Login",
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
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],

                const SizedBox(height: 18),

                GestureDetector(
                  onTap: _showRegisterSheet,
                  child: const Text(
                    "Create new account",
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
  }) {
    final isPasswordField = obscure;

    return TextField(
      controller: controller,
      obscureText: isPasswordField ? !_showPassword : false,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),

        // 👁 ICON CON MẮT
        suffixIcon: isPasswordField
            ? IconButton(
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white60,
                ),
                onPressed: () {
                  setState(() {
                    _showPassword = !_showPassword;
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
