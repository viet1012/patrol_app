import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../api/auth_api.dart';
import '../common/app_version_text.dart';
import '../register/register_page.dart';
import '../session/session_store.dart';
import 'change_password_screen.dart';
import 'error_box.dart';
import 'forgot_password_bottom_sheet.dart';

class LoadingDialog {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passFocus = FocusNode();

  String? _errorMsg;
  bool _showPassword = false;
  bool _rememberMe = true;
  bool _isServerError = false; // thêm ? class

  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  Future<void> _autoLogin() async {
    final creds = await SessionStore.getCreds();
    if (creds == null) return;

    final (account, password) = creds;
    final result = await AuthApi.login(account: account, password: password);

    if (!mounted) return;

    if (!result.success) {
      await SessionStore.clear();
      return;
    }

    context.go('/home', extra: {'accountCode': account});
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final code = _codeCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    setState(() => _errorMsg = null);

    if (code.isEmpty || pass.isEmpty) {
      setState(() => _errorMsg = "Please enter code and password");
      return;
    }

    // 👉 SHOW LOADING
    LoadingDialog.show(context);

    final result = await AuthApi.login(account: code, password: pass);

    // 👉 HIDE LOADING
    if (mounted) {
      LoadingDialog.hide(context);
    }

    if (!result.success) {
      setState(() {
        _errorMsg = result.message;
        _isServerError = result.isServerError;
      });
      return;
    }

    if (_rememberMe) {
      await SessionStore.saveCreds(account: code, password: pass);
    } else {
      await SessionStore.clear();
    }

    if (!mounted) return;
    context.go('/home', extra: {'accountCode': code});
  }

  Future<void> _login1() async {
    final code = _codeCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    setState(() => _errorMsg = null);

    if (code.isEmpty || pass.isEmpty) {
      setState(() => _errorMsg = "Please enter code and password");
      return;
    }

    final result = await AuthApi.login(account: code, password: pass);

    if (!result.success) {
      setState(() {
        _errorMsg = result.message;
        _isServerError = result.isServerError; // ?? KEY
      });
      return;
    }

    if (_rememberMe) {
      await SessionStore.saveCreds(account: code, password: pass);
    } else {
      await SessionStore.clear();
    }

    if (!mounted) return;
    context.go('/home', extra: {'accountCode': code});
  }

  Future<void> _showRegister() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RegisterBottomSheet(),
    );

    if (result != null && result.isNotEmpty) {
      _codeCtrl.text = result;
      _passCtrl.clear();
      Future.delayed(const Duration(milliseconds: 200), () {
        _passFocus.requestFocus();
      });
    }
  }

  Future<void> _showChangePassword() async {
    final account = _codeCtrl.text.trim();

    // =========================================================
    // 👉 1. VALIDATE INPUT
    // =========================================================
    if (account.isEmpty) {
      setState(() {
        _errorMsg = "Please enter Employee ID first";
        _isServerError = false;
      });
      return;
    }

    // =========================================================
    // 👉 2. CALL API
    // =========================================================
    final result = await AuthApi.checkAccountExists(account);

    // =========================================================
    // 👉 3. SERVER / NETWORK ERROR
    // =========================================================
    if (!result.success) {
      setState(() {
        _errorMsg = result.message;
        _isServerError = result.isServerError;
      });
      return;
    }

    // =========================================================
    // 👉 4. BUSINESS ERROR
    // =========================================================
    final exists = result.data == true;

    if (!exists) {
      setState(() {
        _errorMsg = "Account does not exist";
        _isServerError = false;
      });
      return;
    }

    // =========================================================
    // 👉 5. SUCCESS → OPEN BOTTOM SHEET
    // =========================================================
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangePasswordBottomSheet(account: account),
    );
  }

  Future<void> _forgotPassword() async {
    final account = _codeCtrl.text.trim();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ForgotPasswordBottomSheet(
        account: account.isEmpty ? null : account, // 👈 KEY
      ),
    );

    if (result == true) {
      LoadingDialog.show(context);
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      LoadingDialog.hide(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Your request has been submitted successfully.\n"
            "Please check Microsoft Teams.",
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppStyles.bg,
        child: Center(
          child: LoginCard(
            codeCtrl: _codeCtrl,
            passCtrl: _passCtrl,
            passFocus: _passFocus,
            errorMsg: _errorMsg,
            isServerError: _isServerError,
            showPassword: _showPassword,
            rememberMe: _rememberMe,
            onToggleRemember: (v) => setState(() => _rememberMe = v),
            onTogglePassword: () =>
                setState(() => _showPassword = !_showPassword),
            onLogin: _login,
            onRegister: _showRegister,
            onChangePassword: _showChangePassword,
            onInputChanged: (_) {
              if (_errorMsg != null) {
                setState(() => _errorMsg = null);
              }
            },
            onForgotPassword: _forgotPassword,
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// STYLE
////////////////////////////////////////////////////////////

class AppStyles {
  static const bg = BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF121826), Color(0xFF1F2937), Color(0xFF374151)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  static const cardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF020617)],
  );

  static InputDecoration input({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF020617),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// CARD
////////////////////////////////////////////////////////////

class LoginCard extends StatelessWidget {
  final TextEditingController codeCtrl;
  final TextEditingController passCtrl;
  final FocusNode passFocus;

  final String? errorMsg;
  final bool isServerError;
  final bool showPassword;
  final bool rememberMe;

  final Function(bool) onToggleRemember;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onChangePassword;
  final ValueChanged<String> onInputChanged;
  final VoidCallback onForgotPassword;

  const LoginCard({
    super.key,
    required this.codeCtrl,
    required this.passCtrl,
    required this.passFocus,
    required this.errorMsg,
    required this.showPassword,
    required this.rememberMe,
    required this.onToggleRemember,
    required this.onTogglePassword,
    required this.onLogin,
    required this.onRegister,
    required this.onChangePassword,
    required this.onInputChanged,
    required this.onForgotPassword,
    required this.isServerError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppStyles.cardGradient,
        borderRadius: BorderRadius.circular(20),
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
          const _Logo(),
          const SizedBox(height: 10),
          const AppVersionText(),

          const SizedBox(height: 16),
          const _Title(),

          const SizedBox(height: 20),

          AppInput(
            controller: codeCtrl,
            label: "Employee ID",
            icon: Icons.badge_outlined,
            isNumber: true,
            onChanged: onInputChanged,
          ),

          const SizedBox(height: 14),

          AppInput(
            controller: passCtrl,
            label: "Password",
            icon: Icons.lock_outline,
            obscure: !showPassword,
            focusNode: passFocus,
            onChanged: onInputChanged,
            suffix: IconButton(
              icon: Icon(
                showPassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.white60,
              ),
              onPressed: onTogglePassword,
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Checkbox(
                value: rememberMe,
                onChanged: (v) => onToggleRemember(v ?? true),
              ),
              const Text(
                "Remember me",
                style: TextStyle(color: Colors.white70),
              ),
              Spacer(),
              GestureDetector(
                onTap: onForgotPassword,
                child: const Text(
                  "Forgot password?",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Login",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // if (errorMsg != null) ...[
          //   const SizedBox(height: 10),
          //   Text(errorMsg!, style: const TextStyle(color: Colors.redAccent)),
          // ],
          if (errorMsg != null) ...[
            const SizedBox(height: 10),
            ErrorBox(message: errorMsg!, isServerError: isServerError),
          ],
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onChangePassword,
                child: const Text(
                  "Change password",
                  style: TextStyle(color: Colors.white70),
                ),
              ),

              GestureDetector(
                onTap: onRegister,
                child: const Text(
                  "Create account",
                  style: TextStyle(color: Color(0xFF38BDF8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// INPUT
////////////////////////////////////////////////////////////

class AppInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final bool isNumber;
  final FocusNode? focusNode;
  final Widget? suffix;
  final ValueChanged<String> onChanged;

  const AppInput({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.isNumber = false,
    this.focusNode,
    this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: const TextStyle(color: Colors.white),
      decoration: AppStyles.input(label: label, icon: icon, suffix: suffix),
      onChanged: onChanged,
    );
  }
}

////////////////////////////////////////////////////////////
/// SMALL WIDGETS
////////////////////////////////////////////////////////////

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/flags/favicon.png', width: 100, height: 100);
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          "Welcome Back",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text("Sign in to continue", style: TextStyle(color: Colors.white70)),
      ],
    );
  }
}
