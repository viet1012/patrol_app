import 'package:flutter/material.dart';

import '../../common/app_version_text.dart';
import '../error_box.dart';
import '../styles/auth_styles.dart';
import 'auth_input.dart';
import 'auth_password_input.dart';
import 'auth_submit_button.dart';

class LoginCard extends StatelessWidget {
  final TextEditingController codeCtrl;
  final TextEditingController passCtrl;

  final FocusNode codeFocus;
  final FocusNode passFocus;

  final String? errorMsg;

  final bool isServerError;
  final bool rememberMe;
  final bool isLoggingIn;

  final ValueChanged<bool> onToggleRemember;
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
    required this.rememberMe,
    required this.isLoggingIn,
    required this.onToggleRemember,
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
        gradient: AuthStyles.cardGradient,
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
          AuthPasswordInput(
            controller: passCtrl,
            focusNode: passFocus,
            label: 'Password',
            enabled: !isLoggingIn,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!isLoggingIn) {
                onLogin();
              }
            },
            onChanged: onInputChanged,
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
          AuthSubmitButton(
            label: 'Login',
            isLoading: isLoggingIn,
            onPressed: onLogin,
            height: 48,
            textColor: Colors.white,
            loadingStrokeWidth: 2.4,
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
