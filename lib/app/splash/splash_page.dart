import 'package:flutter/material.dart';

/// Màn hình chờ khi đang khôi phục phiên đăng nhập (sau F5 / mở link).
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  static const _bg = Color(0xFF0F2027);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(
              image: AssetImage('assets/flags/favicon.png'),
              width: 96,
              height: 96,
            ),
            SizedBox(height: 20),
            Text(
              'S-Patrol',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
