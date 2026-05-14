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

  ////////////////////////////////////////////////////////////
  /// SHOW
  ////////////////////////////////////////////////////////////
  static void show(
    BuildContext context, {
    String message = "Connecting to server...",
  }) {
    if (_isShowing) return;

    _isShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
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
              ////////////////////////////////////////////////////////////
              /// LOADING
              ////////////////////////////////////////////////////////////
              const SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: Color(0xFF38BDF8),
                ),
              ),

              const SizedBox(height: 20),

              ////////////////////////////////////////////////////////////
              /// TEXT
              ////////////////////////////////////////////////////////////
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
                "Please wait a moment...",
                textAlign: TextAlign.center,

                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// HIDE
  ////////////////////////////////////////////////////////////
  static void hide(BuildContext context) {
    if (!_isShowing) return;

    _isShowing = false;

    Navigator.of(context, rootNavigator: true).pop();
  }
}
////////////////////////////////////////////////////////////
/// LOGIN PAGE
////////////////////////////////////////////////////////////

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  ////////////////////////////////////////////////////////////
  /// CONTROLLERS
  ////////////////////////////////////////////////////////////

  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passFocus = FocusNode();

  ////////////////////////////////////////////////////////////
  /// STATES
  ////////////////////////////////////////////////////////////

  String? _errorMsg;

  bool _showPassword = false;
  bool _rememberMe = true;
  bool _isServerError = false;

  ////////////////////////////////////////////////////////////
  /// IDLE DETECTOR
  ////////////////////////////////////////////////////////////

  DateTime _lastActivity = DateTime.now();

  Timer? _idleTimer;

  bool _idleWarningShown = false;

  ////////////////////////////////////////////////////////////
  /// INIT
  ////////////////////////////////////////////////////////////

  @override
  void initState() {
    super.initState();

    _autoLogin();

    ////////////////////////////////////////////////////////////
    /// CHECK IDLE EVERY 1 MINUTE
    ////////////////////////////////////////////////////////////
    _idleTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkIdle(),
    );
  }

  ////////////////////////////////////////////////////////////
  /// DISPOSE
  ////////////////////////////////////////////////////////////

  @override
  void dispose() {
    _idleTimer?.cancel();

    _codeCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();

    super.dispose();
  }

  ////////////////////////////////////////////////////////////
  /// UPDATE ACTIVITY
  ////////////////////////////////////////////////////////////

  void _updateActivity() {
    _lastActivity = DateTime.now();

    ////////////////////////////////////////////////////////////
    /// RESET WARNING
    ////////////////////////////////////////////////////////////
    _idleWarningShown = false;
  }

  ////////////////////////////////////////////////////////////
  /// CHECK IDLE
  ////////////////////////////////////////////////////////////

  Future<void> _checkIdle() async {
    ////////////////////////////////////////////////////////////
    /// AVOID MULTIPLE DIALOGS
    ////////////////////////////////////////////////////////////
    if (_idleWarningShown) return;

    final idleMinutes = DateTime.now().difference(_lastActivity).inMinutes;

    ////////////////////////////////////////////////////////////
    /// SHOW AFTER 30 MINUTES
    ////////////////////////////////////////////////////////////
    if (idleMinutes < 30) return;

    _idleWarningShown = true;

    if (!mounted) return;

    ////////////////////////////////////////////////////////////
    /// SHOW WARNING
    ////////////////////////////////////////////////////////////
    final shouldRefresh = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
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
              ////////////////////////////////////////////////////////////
              /// ICON
              ////////////////////////////////////////////////////////////
              Container(
                width: 64,
                height: 64,

                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),

                child: const Icon(
                  Icons.access_time_rounded,
                  color: Colors.orangeAccent,
                  size: 34,
                ),
              ),

              const SizedBox(height: 16),

              ////////////////////////////////////////////////////////////
              /// TITLE
              ////////////////////////////////////////////////////////////
              const Text(
                "Session Idle",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 16),

              ////////////////////////////////////////////////////////////
              /// MESSAGE
              ////////////////////////////////////////////////////////////
              const ErrorBox(
                message:
                    "This page has been idle for a long time.\n\n"
                    "The connection may become unstable.\n"
                    "Please refresh the page for the best experience.",

                isServerError: true,
              ),

              const SizedBox(height: 20),

              ////////////////////////////////////////////////////////////
              /// BUTTONS
              ////////////////////////////////////////////////////////////
              Row(
                children: [
                  ////////////////////////////////////////////////////////////
                  /// CONTINUE
                  ////////////////////////////////////////////////////////////
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },

                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,

                        side: const BorderSide(color: Colors.white24),

                        padding: const EdgeInsets.symmetric(vertical: 14),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),

                      child: const Text("Continue"),
                    ),
                  ),

                  const SizedBox(width: 12),

                  ////////////////////////////////////////////////////////////
                  /// REFRESH
                  ////////////////////////////////////////////////////////////
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },

                      icon: const Icon(Icons.refresh),

                      label: const Text("Refresh"),

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
      ),
    );

    ////////////////////////////////////////////////////////////
    /// REFRESH PAGE
    ////////////////////////////////////////////////////////////
    if (shouldRefresh == true) {
      html.window.location.reload();
    }
  }

  ////////////////////////////////////////////////////////////
  /// AUTO LOGIN
  ////////////////////////////////////////////////////////////

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

  ////////////////////////////////////////////////////////////
  /// LOGIN
  ////////////////////////////////////////////////////////////
  bool _reloadSuggested = false;

  Future<void> _login1() async {
    final idleMinutes = DateTime.now().difference(_lastActivity).inMinutes;

    if (idleMinutes >= 30) {
      html.window.location.reload();
      return;
    }
    ////////////////////////////////////////////////////////////
    /// UPDATE USER ACTIVITY
    ////////////////////////////////////////////////////////////
    _updateActivity();

    final code = _codeCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    ////////////////////////////////////////////////////////////
    /// CLEAR ERROR
    ////////////////////////////////////////////////////////////
    setState(() {
      _errorMsg = null;
      _isServerError = false;
    });

    ////////////////////////////////////////////////////////////
    /// VALIDATE
    ////////////////////////////////////////////////////////////
    if (code.isEmpty || pass.isEmpty) {
      setState(() {
        _errorMsg = "Please enter code and password";
      });

      return;
    }

    ////////////////////////////////////////////////////////////
    /// SHOW LOADING
    ////////////////////////////////////////////////////////////
    LoadingDialog.show(context);

    AuthResult result;

    try {
      ////////////////////////////////////////////////////////////
      /// LOGIN
      ////////////////////////////////////////////////////////////
      result = await AuthApi.login(account: code, password: pass);

      ////////////////////////////////////////////////////////////
      /// RETRY ONLY REAL SERVER ERROR
      ////////////////////////////////////////////////////////////
      final shouldRetry = !result.success && result.isServerError;

      if (shouldRetry) {
        ////////////////////////////////////////////////////////////
        /// WAIT
        ////////////////////////////////////////////////////////////
        await Future.delayed(const Duration(milliseconds: 500));

        ////////////////////////////////////////////////////////////
        /// RETRY
        ////////////////////////////////////////////////////////////
        result = await AuthApi.login(account: code, password: pass);
      }
    } catch (_) {
      result = AuthResult(
        success: false,
        message: AppMessage.serverError,
        isServerError: true,
      );
    } finally {
      ////////////////////////////////////////////////////////////
      /// ALWAYS HIDE LOADING
      ////////////////////////////////////////////////////////////
      if (mounted) {
        LoadingDialog.hide(context);
      }
    }

    ////////////////////////////////////////////////////////////
    /// LOGIN FAILED
    ////////////////////////////////////////////////////////////
    if (!result.success) {
      ////////////////////////////////////////////////////////////
      /// SPECIAL MESSAGE FOR LONG IDLE
      ////////////////////////////////////////////////////////////
      final idleMinutes = DateTime.now().difference(_lastActivity).inMinutes;

      String message = result.message;

      if (idleMinutes >= 30 && result.isServerError) {
        message =
            "${result.message}\n\n"
            "This page has been idle for a long time.\n"
            "Please refresh the page and try again.";
      }

      ////////////////////////////////////////////////////////////
      /// NETWORK / CONNECTION LOST
      ////////////////////////////////////////////////////////////
      if (result.message == AppMessage.cannotConnect ||
          result.message == AppMessage.timeout ||
          result.message == AppMessage.networkError) {
        ////////////////////////////////////////////////////////////
        /// FIRST TIME -> ASK RELOAD
        ////////////////////////////////////////////////////////////
        if (!_reloadSuggested) {
          _reloadSuggested = true;

          final shouldReload = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black87,

            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,

              child: Container(
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
                    //////////////////////////////////////////////////////
                    /// ICON
                    //////////////////////////////////////////////////////
                    Container(
                      width: 64,
                      height: 64,

                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),

                      child: const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.redAccent,
                        size: 34,
                      ),
                    ),

                    const SizedBox(height: 16),

                    //////////////////////////////////////////////////////
                    /// TITLE
                    //////////////////////////////////////////////////////
                    const Text(
                      "Connection Lost",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 16),

                    //////////////////////////////////////////////////////
                    /// ERROR BOX
                    //////////////////////////////////////////////////////
                    const ErrorBox(
                      message:
                          "Unable to connect to the server.\n\n"
                          "The page may be outdated or the connection was interrupted.\n\n"
                          "Please reload the page and try again.",

                      isServerError: true,
                    ),

                    const SizedBox(height: 20),

                    //////////////////////////////////////////////////////
                    /// BUTTONS
                    //////////////////////////////////////////////////////
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context, false);
                            },

                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,

                              side: const BorderSide(color: Colors.white24),

                              padding: const EdgeInsets.symmetric(vertical: 14),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),

                            child: const Text("Cancel"),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context, true);
                            },

                            icon: const Icon(Icons.refresh),

                            label: const Text("Reload"),

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
            ),
          );

          if (shouldReload == true) {
            html.window.location.reload();
          }

          return;
        }

        ////////////////////////////////////////////////////////////
        /// AFTER RELOAD STILL FAIL
        ////////////////////////////////////////////////////////////
        setState(() {
          _errorMsg =
              "Unable to connect to the server.\n\n"
              "Please contact IT Support.";

          _isServerError = true;
        });

        return;
      }

      setState(() {
        _errorMsg = message;
        _isServerError = result.isServerError;
      });

      return;
    }

    ////////////////////////////////////////////////////////////
    /// REMEMBER ME
    ////////////////////////////////////////////////////////////
    if (_rememberMe) {
      await SessionStore.saveCreds(account: code, password: pass);
    } else {
      await SessionStore.clear();
    }

    ////////////////////////////////////////////////////////////
    /// NAVIGATE
    ////////////////////////////////////////////////////////////
    if (!mounted) return;

    context.go('/home', extra: {'accountCode': code});
  }

  Future<void> _login() async {
    ////////////////////////////////////////////////////////////
    /// CHECK IDLE BEFORE UPDATE ACTIVITY
    ////////////////////////////////////////////////////////////
    final idleMinutes = DateTime.now().difference(_lastActivity).inMinutes;

    if (idleMinutes >= 30) {
      html.window.location.reload();
      return;
    }

    ////////////////////////////////////////////////////////////
    /// UPDATE USER ACTIVITY
    ////////////////////////////////////////////////////////////
    _updateActivity();

    final code = _codeCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    ////////////////////////////////////////////////////////////
    /// CLEAR ERROR
    ////////////////////////////////////////////////////////////
    setState(() {
      _errorMsg = null;
      _isServerError = false;
    });

    ////////////////////////////////////////////////////////////
    /// VALIDATE
    ////////////////////////////////////////////////////////////
    if (code.isEmpty || pass.isEmpty) {
      setState(() {
        _errorMsg = "Please enter code and password";
      });

      return;
    }

    ////////////////////////////////////////////////////////////
    /// SHOW LOADING
    ////////////////////////////////////////////////////////////
    LoadingDialog.show(context, message: "Signing in...");

    AuthResult result;

    try {
      ////////////////////////////////////////////////////////////
      /// LOGIN
      ////////////////////////////////////////////////////////////
      result = await AuthApi.login(account: code, password: pass);

      ////////////////////////////////////////////////////////////
      /// RETRY ONLY REAL SERVER / NETWORK ERROR
      ////////////////////////////////////////////////////////////
      final shouldRetry = !result.success && result.isServerError;

      if (shouldRetry) {
        await Future.delayed(const Duration(milliseconds: 800));

        result = await AuthApi.login(account: code, password: pass);
      }
    } catch (_) {
      result = AuthResult(
        success: false,
        message: AppMessage.serverError,
        isServerError: true,
      );
    } finally {
      ////////////////////////////////////////////////////////////
      /// ALWAYS HIDE LOADING
      ////////////////////////////////////////////////////////////
      if (mounted) {
        LoadingDialog.hide(context);
      }
    }

    if (!mounted) return;

    ////////////////////////////////////////////////////////////
    /// LOGIN FAILED
    ////////////////////////////////////////////////////////////
    if (!result.success) {
      String message = result.message;

      ////////////////////////////////////////////////////////////
      /// NETWORK / CONNECTION LOST
      ////////////////////////////////////////////////////////////
      final isNetworkError =
          result.message == AppMessage.cannotConnect ||
          result.message == AppMessage.timeout ||
          result.message == AppMessage.networkError;

      if (isNetworkError) {
        final alreadyReloaded =
            html.window.sessionStorage['LOGIN_RELOADED_ONCE'] == 'true';

        //////////////////////////////////////////////////////////
        /// FIRST TIME -> ASK USER TO RELOAD
        //////////////////////////////////////////////////////////
        if (!alreadyReloaded) {
          final shouldReload = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black87,

            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,

              child: Container(
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
                    //////////////////////////////////////////////////////
                    /// ICON
                    //////////////////////////////////////////////////////
                    Container(
                      width: 64,
                      height: 64,

                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),

                      child: const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.redAccent,
                        size: 34,
                      ),
                    ),

                    const SizedBox(height: 16),

                    //////////////////////////////////////////////////////
                    /// TITLE
                    //////////////////////////////////////////////////////
                    const Text(
                      "Connection Lost",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 16),

                    //////////////////////////////////////////////////////
                    /// ERROR BOX
                    //////////////////////////////////////////////////////
                    const ErrorBox(
                      message:
                          "Unable to connect to the server.\n\n"
                          "The page may be outdated or the connection was interrupted.\n\n"
                          "Please reload the page and try again.",

                      isServerError: true,
                      showContact: false,
                    ),

                    const SizedBox(height: 20),

                    //////////////////////////////////////////////////////
                    /// BUTTONS hintText: "search_or_add_new".tr(context),
                    //////////////////////////////////////////////////////
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context, false);
                            },

                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),

                            child: const Text("Cancel"),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context, true);
                            },

                            icon: const Icon(Icons.refresh),

                            label: const Text("Reload"),

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
            ),
          );

          if (shouldReload == true) {
            html.window.sessionStorage['LOGIN_RELOADED_ONCE'] = 'true';
            html.window.location.reload();
          }
          return;
        }

        //////////////////////////////////////////////////////////
        /// AFTER RELOAD STILL FAIL -> CONTACT IT
        //////////////////////////////////////////////////////////
        setState(() {
          _errorMsg =
              "Unable to connect to the server.\n\n"
              "Please contact IT Support.";
          _isServerError = true;
        });

        return;
      }

      ////////////////////////////////////////////////////////////
      /// LONG IDLE MESSAGE
      ////////////////////////////////////////////////////////////
      final idleMinutesAfterLogin = DateTime.now()
          .difference(_lastActivity)
          .inMinutes;

      if (idleMinutesAfterLogin >= 30 && result.isServerError) {
        message =
            "${result.message}\n\n"
            "This page has been idle for a long time.\n"
            "Please refresh the page and try again.";
      }

      ////////////////////////////////////////////////////////////
      /// NORMAL ERROR
      ////////////////////////////////////////////////////////////
      setState(() {
        _errorMsg = message;
        _isServerError = result.isServerError;
      });

      return;
    }

    ////////////////////////////////////////////////////////////
    /// LOGIN SUCCESS -> CLEAR RELOAD FLAG
    ////////////////////////////////////////////////////////////
    html.window.sessionStorage.remove('LOGIN_RELOADED_ONCE');

    ////////////////////////////////////////////////////////////
    /// REMEMBER ME
    ////////////////////////////////////////////////////////////
    if (_rememberMe) {
      await SessionStore.saveCreds(account: code, password: pass);
    } else {
      await SessionStore.clear();
    }

    if (!mounted) return;

    ////////////////////////////////////////////////////////////
    /// NAVIGATE
    ////////////////////////////////////////////////////////////
    context.go('/home', extra: {'accountCode': code});
  }

  ////////////////////////////////////////////////////////////
  /// REGISTER
  ////////////////////////////////////////////////////////////

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

  ////////////////////////////////////////////////////////////
  /// CHANGE PASSWORD
  ////////////////////////////////////////////////////////////

  Future<void> _showChangePassword() async {
    final account = _codeCtrl.text.trim();

    if (account.isEmpty) {
      setState(() {
        _errorMsg = "Please enter Employee ID first";

        _isServerError = false;
      });

      return;
    }

    final result = await AuthApi.checkAccountExists(account);

    if (!result.success) {
      setState(() {
        _errorMsg = result.message;
        _isServerError = result.isServerError;
      });

      return;
    }

    final exists = result.data == true;

    if (!exists) {
      setState(() {
        _errorMsg = "Account does not exist";
        _isServerError = false;
      });

      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangePasswordBottomSheet(account: account),
    );
  }

  ////////////////////////////////////////////////////////////
  /// FORGOT PASSWORD
  ////////////////////////////////////////////////////////////

  Future<void> _forgotPassword() async {
    final account = _codeCtrl.text.trim();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ForgotPasswordBottomSheet(account: account.isEmpty ? null : account),
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

  ////////////////////////////////////////////////////////////
  /// BUILD
  ////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    return Listener(
      ////////////////////////////////////////////////////////////
      /// DETECT USER ACTIVITY
      ////////////////////////////////////////////////////////////
      onPointerDown: (_) => _updateActivity(),
      onPointerMove: (_) => _updateActivity(),

      child: Scaffold(
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

              onToggleRemember: (v) {
                setState(() {
                  _rememberMe = v;
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

              onInputChanged: (_) {
                _updateActivity();

                if (_errorMsg != null) {
                  setState(() {
                    _errorMsg = null;
                  });
                }
              },
            ),
          ),
        ),
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
