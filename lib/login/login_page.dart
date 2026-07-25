import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../api/auth_api.dart';
import '../common/app_version_text.dart';
import '../model/auth_result.dart';
import '../register/register_page.dart';
import '../session/session_store.dart';
import 'change_password_screen.dart';
import 'error_box.dart';
import 'forgot_password_bottom_sheet.dart';

class LoadingDialog {
  static bool _isShowing = false;
  static BuildContext? _dialogContext;

  static bool get isShowing => _isShowing;

  static Future<void> show(
    BuildContext context, {
    String message = 'Connecting to server...',
  }) async {
    if (_isShowing) return;

    _isShowing = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      useRootNavigator: true,
      builder: (dialogContext) {
        _dialogContext = dialogContext;

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please wait a moment...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      },
    );

    _isShowing = false;
    _dialogContext = null;
  }

  static void hide() {
    if (!_isShowing) return;

    final dialogContext = _dialogContext;

    _isShowing = false;
    _dialogContext = null;

    if (dialogContext == null) return;

    final navigator = Navigator.of(dialogContext, rootNavigator: true);

    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Duration _idleLimit = Duration(minutes: 30);
  static const Duration _idleCheckInterval = Duration(minutes: 1);
  static const String _reloadSessionKey = 'LOGIN_RELOADED_ONCE';

  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  final FocusNode _codeFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();

  Timer? _idleTimer;

  String? _errorMsg;

  bool _showPassword = false;
  bool _rememberMe = true;
  bool _isServerError = false;
  bool _isLoggingIn = false;
  bool _isAutoLoggingIn = false;
  bool _idleWarningShown = false;

  DateTime _lastActivity = DateTime.now();

  @override
  void initState() {
    super.initState();

    _startIdleMonitor();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLogin();
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();

    _codeCtrl.dispose();
    _passCtrl.dispose();

    _codeFocus.dispose();
    _passFocus.dispose();

    super.dispose();
  }

  void _startIdleMonitor() {
    _idleTimer?.cancel();

    _idleTimer = Timer.periodic(_idleCheckInterval, (_) => _checkIdle());
  }

  void _updateActivity() {
    _lastActivity = DateTime.now();
    _idleWarningShown = false;
  }

  Duration get _idleDuration => DateTime.now().difference(_lastActivity);

  bool get _isIdleExpired => _idleDuration >= _idleLimit;

  Future<void> _checkIdle() async {
    if (!mounted || _idleWarningShown || !_isIdleExpired) {
      return;
    }

    _idleWarningShown = true;

    final shouldRefresh = await _showIdleDialog();

    if (!mounted) return;

    if (shouldRefresh == true) {
      html.window.location.reload();
      return;
    }

    _updateActivity();
  }

  Future<bool?> _showIdleDialog() {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _StatusDialog(
          icon: Icons.access_time_rounded,
          iconColor: Colors.orangeAccent,
          title: 'Session Idle',
          message:
              'This page has been idle for a long time.\n\n'
              'The connection may become unstable.\n'
              'Please refresh the page for the best experience.',
          secondaryText: 'Continue',
          primaryText: 'Refresh',
          primaryIcon: Icons.refresh,
          onSecondary: () {
            Navigator.pop(dialogContext, false);
          },
          onPrimary: () {
            Navigator.pop(dialogContext, true);
          },
        );
      },
    );
  }

  Future<void> _autoLogin() async {
    if (_isAutoLoggingIn || _isLoggingIn) return;

    _isAutoLoggingIn = true;

    try {
      final creds = await SessionStore.getCreds();

      if (creds == null || !mounted) return;

      final (account, password) = creds;

      final normalizedAccount = account.trim();
      final normalizedPassword = password.trim();

      if (normalizedAccount.isEmpty || normalizedPassword.isEmpty) {
        await SessionStore.clear();
        return;
      }

      final result = await AuthApi.login(
        account: normalizedAccount,
        password: normalizedPassword,
      );

      if (!mounted) return;

      if (!result.success) {
        await SessionStore.clear();
        return;
      }

      html.window.sessionStorage.remove(_reloadSessionKey);

      context.go('/home', extra: {'accountCode': normalizedAccount});
    } catch (error, stackTrace) {
      debugPrint('Auto login error: $error');
      debugPrintStack(stackTrace: stackTrace);

      await SessionStore.clear();
    } finally {
      _isAutoLoggingIn = false;
    }
  }

  Future<void> _login() async {
    if (_isLoggingIn || _isAutoLoggingIn) return;

    if (_isIdleExpired) {
      html.window.location.reload();
      return;
    }

    _updateActivity();

    final code = _codeCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (code.isEmpty || password.isEmpty) {
      setState(() {
        _errorMsg = 'Please enter code and password';
        _isServerError = false;
      });

      if (code.isEmpty) {
        _codeFocus.requestFocus();
      } else {
        _passFocus.requestFocus();
      }

      return;
    }

    setState(() {
      _isLoggingIn = true;
      _errorMsg = null;
      _isServerError = false;
    });

    unawaited(LoadingDialog.show(context, message: 'Signing in...'));

    AuthResult result;

    try {
      result = await _loginWithRetry(account: code, password: password);
    } catch (error, stackTrace) {
      debugPrint('Login error: $error');
      debugPrintStack(stackTrace: stackTrace);

      result = AuthResult(
        success: false,
        message: AppMessage.serverError,
        isServerError: true,
      );
    } finally {
      LoadingDialog.hide();

      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
      }
    }

    if (!mounted) return;

    if (!result.success) {
      await _handleLoginFailure(result);
      return;
    }

    html.window.sessionStorage.remove(_reloadSessionKey);

    if (_rememberMe) {
      await SessionStore.saveCreds(account: code, password: password);
    } else {
      await SessionStore.clear();
    }

    if (!mounted) return;

    context.go('/home', extra: {'accountCode': code});
  }

  Future<AuthResult> _loginWithRetry({
    required String account,
    required String password,
  }) async {
    var result = await AuthApi.login(account: account, password: password);

    if (!result.success && result.isServerError) {
      await Future<void>.delayed(const Duration(milliseconds: 800));

      result = await AuthApi.login(account: account, password: password);
    }

    return result;
  }

  Future<void> _handleLoginFailure(AuthResult result) async {
    if (!mounted) return;

    if (_isNetworkError(result.message)) {
      await _handleNetworkFailure();
      return;
    }

    var message = result.message;

    if (_isIdleExpired && result.isServerError) {
      message =
          '${result.message}\n\n'
          'This page has been idle for a long time.\n'
          'Please refresh the page and try again.';
    }

    setState(() {
      _errorMsg = message;
      _isServerError = result.isServerError;
    });
  }

  bool _isNetworkError(String message) {
    return message == AppMessage.cannotConnect ||
        message == AppMessage.timeout ||
        message == AppMessage.networkError;
  }

  Future<void> _handleNetworkFailure() async {
    final alreadyReloaded =
        html.window.sessionStorage[_reloadSessionKey] == 'true';

    if (!alreadyReloaded) {
      final shouldReload = await _showConnectionLostDialog();

      if (!mounted) return;

      if (shouldReload == true) {
        html.window.sessionStorage[_reloadSessionKey] = 'true';
        html.window.location.reload();
      }

      return;
    }

    setState(() {
      _errorMsg =
          'Unable to connect to the server.\n\n'
          'Please contact IT Support.';
      _isServerError = true;
    });
  }

  Future<bool?> _showConnectionLostDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return _StatusDialog(
          icon: Icons.wifi_off_rounded,
          iconColor: Colors.redAccent,
          title: 'Connection Lost',
          message:
              'Unable to connect to the server.\n\n'
              'The page may be outdated or the connection was interrupted.\n\n'
              'Please reload the page and try again.',
          secondaryText: 'Cancel',
          primaryText: 'Reload',
          primaryIcon: Icons.refresh,
          onSecondary: () {
            Navigator.pop(dialogContext, false);
          },
          onPrimary: () {
            Navigator.pop(dialogContext, true);
          },
        );
      },
    );
  }

  Future<void> _showRegister() async {
    _updateActivity();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RegisterBottomSheet(),
    );

    if (!mounted || result == null || result.trim().isEmpty) {
      return;
    }

    _codeCtrl.text = result.trim();
    _passCtrl.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _passFocus.requestFocus();
      }
    });
  }

  Future<void> _showChangePassword() async {
    _updateActivity();

    final account = _codeCtrl.text.trim();

    if (account.isEmpty) {
      setState(() {
        _errorMsg = 'Please enter Employee ID first';
        _isServerError = false;
      });

      _codeFocus.requestFocus();
      return;
    }

    final result = await AuthApi.checkAccountExists(account);

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _errorMsg = result.message;
        _isServerError = result.isServerError;
      });

      return;
    }

    if (result.data != true) {
      setState(() {
        _errorMsg = 'Account does not exist';
        _isServerError = false;
      });

      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ChangePasswordBottomSheet(account: account);
      },
    );
  }

  Future<void> _forgotPassword() async {
    _updateActivity();

    final account = _codeCtrl.text.trim();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ForgotPasswordBottomSheet(
          account: account.isEmpty ? null : account,
        );
      },
    );

    if (!mounted || result != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Your request has been submitted successfully.\n'
          'Please check Microsoft Teams.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _onInputChanged(String _) {
    _updateActivity();

    if (_errorMsg == null) return;

    setState(() {
      _errorMsg = null;
      _isServerError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Listener(
      onPointerDown: (_) => _updateActivity(),
      child: Focus(
        onKeyEvent: (_, __) {
          _updateActivity();
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: Container(
            decoration: AppStyles.bg,
            child: SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, 24, 16, bottomInset + 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.sizeOf(context).height -
                        MediaQuery.paddingOf(context).vertical -
                        bottomInset -
                        48,
                  ),
                  child: Center(
                    child: LoginCard(
                      codeCtrl: _codeCtrl,
                      passCtrl: _passCtrl,
                      codeFocus: _codeFocus,
                      passFocus: _passFocus,
                      errorMsg: _errorMsg,
                      isServerError: _isServerError,
                      showPassword: _showPassword,
                      rememberMe: _rememberMe,
                      isLoggingIn: _isLoggingIn || _isAutoLoggingIn,
                      onToggleRemember: (value) {
                        setState(() {
                          _rememberMe = value;
                        });
                      },
                      onTogglePassword: () {
                        setState(() {
                          _showPassword = !_showPassword;
                        });
                      },
                      onLogin: _login,
                      onRegister: _showRegister,
                      onChangePassword: _showChangePassword,
                      onForgotPassword: _forgotPassword,
                      onInputChanged: _onInputChanged,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginCard extends StatelessWidget {
  final TextEditingController codeCtrl;
  final TextEditingController passCtrl;

  final FocusNode codeFocus;
  final FocusNode passFocus;

  final String? errorMsg;

  final bool isServerError;
  final bool showPassword;
  final bool rememberMe;
  final bool isLoggingIn;

  final ValueChanged<bool> onToggleRemember;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onChangePassword;
  final VoidCallback onForgotPassword;
  final ValueChanged<String> onInputChanged;

  const LoginCard({
    super.key,
    required this.codeCtrl,
    required this.passCtrl,
    required this.codeFocus,
    required this.passFocus,
    required this.errorMsg,
    required this.isServerError,
    required this.showPassword,
    required this.rememberMe,
    required this.isLoggingIn,
    required this.onToggleRemember,
    required this.onTogglePassword,
    required this.onLogin,
    required this.onRegister,
    required this.onChangePassword,
    required this.onForgotPassword,
    required this.onInputChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: AppStyles.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.08)),
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
            focusNode: codeFocus,
            label: 'Employee ID',
            icon: Icons.badge_outlined,
            isNumber: true,
            enabled: !isLoggingIn,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
              passFocus.requestFocus();
            },
            onChanged: onInputChanged,
          ),
          const SizedBox(height: 14),
          AppInput(
            controller: passCtrl,
            focusNode: passFocus,
            label: 'Password',
            icon: Icons.lock_outline,
            obscure: !showPassword,
            enabled: !isLoggingIn,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!isLoggingIn) {
                onLogin();
              }
            },
            onChanged: onInputChanged,
            suffix: IconButton(
              tooltip: showPassword ? 'Hide password' : 'Show password',
              onPressed: isLoggingIn ? null : onTogglePassword,
              icon: Icon(
                showPassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.white60,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: Checkbox(
                  value: rememberMe,
                  onChanged: isLoggingIn
                      ? null
                      : (value) {
                          onToggleRemember(value ?? false);
                        },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),

              const SizedBox(width: 4),

              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isLoggingIn
                      ? null
                      : () => onToggleRemember(!rememberMe),
                  child: const Text(
                    'Remember me',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              TextButton(
                onPressed: isLoggingIn ? null : onForgotPassword,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot password?',
                  maxLines: 1,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isLoggingIn ? null : onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                disabledBackgroundColor: const Color(
                  0xFF2563EB,
                ).withOpacity(.45),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isLoggingIn
                    ? const SizedBox(
                        key: ValueKey('login-loading'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Login',
                        key: ValueKey('login-text'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: errorMsg == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ErrorBox(
                      message: errorMsg!,
                      isServerError: isServerError,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: isLoggingIn ? null : onChangePassword,
                child: const Text(
                  'Change password',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: isLoggingIn ? null : onRegister,
                child: const Text(
                  'Create account',
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

class AppInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  final bool obscure;
  final bool isNumber;
  final bool enabled;

  final FocusNode? focusNode;
  final Widget? suffix;

  final TextInputAction? textInputAction;

  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  const AppInput({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.onChanged,
    this.obscure = false,
    this.isNumber = false,
    this.enabled = true,
    this.focusNode,
    this.suffix,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber
          ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
          : null,
      textInputAction: textInputAction,
      autofillHints: isNumber
          ? const <String>[AutofillHints.username]
          : const <String>[AutofillHints.password],
      enableSuggestions: !obscure,
      autocorrect: !obscure,
      style: const TextStyle(color: Colors.white),
      decoration: AppStyles.input(label: label, icon: icon, suffix: suffix),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class _StatusDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String secondaryText;
  final String primaryText;
  final IconData primaryIcon;
  final VoidCallback onSecondary;
  final VoidCallback onPrimary;

  const _StatusDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.secondaryText,
    required this.primaryText,
    required this.primaryIcon,
    required this.onSecondary,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ErrorBox(message: message, isServerError: true, showContact: false),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(secondaryText),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onPrimary,
                    icon: Icon(primaryIcon),
                    label: Text(primaryText),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/flags/favicon.png',
      width: 100,
      height: 100,
      filterQuality: FilterQuality.medium,
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'Welcome Back',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text('Sign in to continue', style: TextStyle(color: Colors.white70)),
      ],
    );
  }
}
