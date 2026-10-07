import 'package:flutter/material.dart';

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
