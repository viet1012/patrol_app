import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../homeScreen/patrol_home_screen.dart';
import '../login/login_page.dart';
import '../qrCode/after_patrol.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const LoginPage()),

    // GoRoute(
    //   path: '/home',
    //   builder: (context, state) {
    //     final extra = state.extra;
    //     String accountCode = '';
    //
    //     if (extra is Map<String, dynamic>) {
    //       accountCode = (extra['accountCode'] ?? '').toString();
    //     }
    //
    //     return PatrolHomeScreen(accountCode: accountCode);
    //   },
    // ),
    GoRoute(
      path: '/home/after/:qr',
      builder: (context, state) {
        final qr = state.pathParameters['qr'] ?? '';
        final extra = state.extra;

        if (extra is Map<String, dynamic>) {
          final accountCode = extra['accountCode']?.toString();
          final qrCode = (extra['qrCode']?.toString()) ?? qr;

          final pg = extra['patrolGroup'];
          if (accountCode == null ||
              accountCode.isEmpty ||
              pg is! PatrolGroup) {
            debugPrint('[ROUTER] invalid extra=$extra');
            return const _MissingExtraPage();
          }

          return AfterPatrol(
            accountCode: accountCode,
            qrCode: qrCode,
            patrolGroup: pg,
          );
        }

        debugPrint('[ROUTER] extra is null or wrong type: $extra');
        return const _MissingExtraPage();
      },
    ),
  ],
);

class _MissingExtraPage extends StatelessWidget {
  const _MissingExtraPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invalid link')),
      body: const Center(
        child: Text(
          'Thiếu dữ liệu điều hướng (extra).\nVui lòng mở từ trong app.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
