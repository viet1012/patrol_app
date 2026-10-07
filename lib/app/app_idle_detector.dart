import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppIdleDetector extends StatefulWidget {
  final Widget child;

  const AppIdleDetector({super.key, required this.child});

  @override
  State<AppIdleDetector> createState() => _AppIdleDetectorState();
}

class _AppIdleDetectorState extends State<AppIdleDetector> {
  static const Duration idleLimit = Duration(minutes: 30);
  static const Duration checkEvery = Duration(minutes: 1);

  // static const Duration idleLimit = Duration(seconds: 10);
  // static const Duration checkEvery = Duration(seconds: 2);

  DateTime _lastActivity = DateTime.now();
  Timer? _timer;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(checkEvery, (_) {
      _checkIdle();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateActivity() {
    _lastActivity = DateTime.now();
  }

  Future<void> _checkIdle() async {
    if (_isDialogShowing) return;

    final idleTime = DateTime.now().difference(_lastActivity);

    if (idleTime < idleLimit) return;

    final navContext = appNavigatorKey.currentContext;

    if (navContext == null) return;

    _isDialogShowing = true;

    final shouldReload = await showDialog<bool>(
      context: navContext,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(8),
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
                    color: Colors.orange.withOpacity(.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time_rounded,
                    color: Colors.orangeAccent,
                    size: 36,
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'App has been idle',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'The app has not been used for a long time.\n'
                  'Please reload to keep data updated.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    // Expanded(
                    //   child: OutlinedButton(
                    //     onPressed: () {
                    //       Navigator.of(dialogContext).pop(false);
                    //     },
                    //     style: OutlinedButton.styleFrom(
                    //       foregroundColor: Colors.white70,
                    //       side: const BorderSide(color: Colors.white24),
                    //       padding: const EdgeInsets.symmetric(vertical: 14),
                    //       shape: RoundedRectangleBorder(
                    //         borderRadius: BorderRadius.circular(14),
                    //       ),
                    //     ),
                    //     child: const Text('Continue'),
                    //   ),
                    // ),
                    //
                    // const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(true);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reload'),
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
      },
    );

    _isDialogShowing = false;

    if (shouldReload == true) {
      html.window.location.reload();
      return;
    }

    _updateActivity();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _updateActivity(),
      onPointerMove: (_) => _updateActivity(),
      onPointerSignal: (_) => _updateActivity(),
      child: widget.child,
    );
  }
}
