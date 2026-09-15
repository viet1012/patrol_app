import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/auth_api.dart';
import '../model/auth_result.dart';
import '../register/register_page.dart';
import '../session/session_store.dart';
import 'change_password_screen.dart';
import 'forgot_password_bottom_sheet.dart';
import 'styles/auth_styles.dart';
import 'widgets/auth_status_dialog.dart';
import 'widgets/login_card.dart';
import 'widgets/loading_dialog.dart';

export 'widgets/auth_input.dart';
export 'widgets/loading_dialog.dart';

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
        return AuthStatusDialog(
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

    SessionStore.clearAuthenticatedAccount();
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

      _logLoginResult(result);

      if (result.success == true) {
        debugPrint('AUTH SUCCESS CONFIRMED: account=$normalizedAccount');
        SessionStore.markAuthenticated(normalizedAccount);

        if (!mounted) return;

        html.window.sessionStorage.remove(_reloadSessionKey);
        context.go('/home', extra: {'accountCode': normalizedAccount});
        return;
      }

      SessionStore.clearAuthenticatedAccount();
      await SessionStore.clear();
      return;
    } catch (error, stackTrace) {
      SessionStore.clearAuthenticatedAccount();
      debugPrint('Auto login error: $error');
      debugPrintStack(stackTrace: stackTrace);

      await SessionStore.clear();
    } finally {
      _isAutoLoggingIn = false;
    }
  }

  Future<void> _login() async {
    if (_isLoggingIn || _isAutoLoggingIn) return;

    SessionStore.clearAuthenticatedAccount();

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

    if (result.success == true) {
      html.window.sessionStorage.remove(_reloadSessionKey);

      if (_rememberMe) {
        await SessionStore.saveCreds(account: code, password: password);
      } else {
        await SessionStore.clear();
      }

      debugPrint('AUTH SUCCESS CONFIRMED: account=$code');
      SessionStore.markAuthenticated(code);

      if (!mounted) return;

      context.go('/home', extra: {'accountCode': code});
      return;
    }

    SessionStore.clearAuthenticatedAccount();
    await _handleLoginFailure(result);
    return;
  }

  Future<AuthResult> _loginWithRetry({
    required String account,
    required String password,
  }) async {
    var result = await AuthApi.login(account: account, password: password);
    _logLoginResult(result);

    if (!result.success && result.isServerError) {
      await Future<void>.delayed(const Duration(milliseconds: 800));

      result = await AuthApi.login(account: account, password: password);
      _logLoginResult(result);
    }

    return result;
  }

  void _logLoginResult(AuthResult result) {
    debugPrint(
      'LOGIN RESULT: '
      'success=${result.success}, '
      'code=${result.code}, '
      'serverError=${result.isServerError}, '
      'message=${result.message}',
    );
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
        return AuthStatusDialog(
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
            decoration: AuthStyles.background,
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
                      rememberMe: _rememberMe,
                      isLoggingIn: _isLoggingIn || _isAutoLoggingIn,
                      onToggleRemember: (value) {
                        setState(() {
                          _rememberMe = value;
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
