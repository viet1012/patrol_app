import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../after/after_report_screen.dart';
import '../app_idle_detector.dart';
import '../homeScreen/patrol_home_screen.dart';
import '../login/login_page.dart';
import '../model/auth_me.dart';
import '../session/session_store.dart';
import '../table/patrol_report_table.dart';

final router = GoRouter(
  navigatorKey: appNavigatorKey,

  // ============================================================
  // GLOBAL AUTH GUARD
  // ============================================================
  redirect: (context, state) {
    final authenticatedAccount = SessionStore.authenticatedAccount;

    final isAuthenticated =
        authenticatedAccount != null &&
        authenticatedAccount.trim().isNotEmpty;

    final isLoginPage = state.matchedLocation == '/';

    // Chưa login -> chỉ được ở Login
    if (!isAuthenticated) {
      return isLoginPage ? null : '/';
    }

    // Đã login mà đang ở Login:
    // KHÔNG tự redirect sang Home.
    // LoginPage sẽ tự xử lý auto-login/manual-login.
    return null;
  },

  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const LoginPage(),
      ),
    ),

    GoRoute(
      path: '/home',
      builder: (context, state) {
        final accountCode = SessionStore.authenticatedAccount;
        debugPrint('HOME BUILDER: authenticated=$accountCode');

        // Defensive guard.
        // Không bao giờ tạo Home nếu chưa authenticated.
        if (accountCode == null || accountCode.trim().isEmpty) {
          return const LoginPage();
        }

        return PatrolHomeScreen(
          accountCode: accountCode.trim(),
        );
      },
    ),

    GoRoute(
      path: '/home/summary',
      builder: (context, state) {
        final authenticatedAccount =
            SessionStore.authenticatedAccount;

        if (authenticatedAccount == null ||
            authenticatedAccount.trim().isEmpty) {
          return const LoginPage();
        }

        final extra = state.extra;
        final group =
            state.uri.queryParameters['group'] ?? '';
        final plant =
            state.uri.queryParameters['plant'] ?? '';

        AuthMe? me;

        if (extra is Map<String, dynamic>) {
          me = extra['me'] as AuthMe?;
        }

        if (me == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go('/home');
            }
          });

          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return PatrolReportTable(
          patrolGroup: group,
          plant: plant,
          accountCode: authenticatedAccount.trim(),
          auth: me,
        );
      },
    ),

    GoRoute(
      path: '/after/:qr',
      builder: (context, state) {
        final authenticatedAccount =
            SessionStore.authenticatedAccount;

        if (authenticatedAccount == null ||
            authenticatedAccount.trim().isEmpty) {
          return const LoginPage();
        }

        final qr = state.pathParameters['qr'] ?? '';
        final extra = state.extra;

        if (extra is Map<String, dynamic>) {
          final qrCode =
              extra['qrCode']?.toString() ?? qr;
          final pg = extra['patrolGroup'];

          if (pg is! PatrolGroup) {
            return const _MissingExtraPage();
          }

          return AfterReportScreen(
            // Không tin accountCode từ extra nữa.
            accountCode: authenticatedAccount.trim(),
            qrCode: qrCode,
            patrolGroup: pg,
          );
        }

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
      appBar: AppBar(
        title: const Text('Invalid link'),
      ),
      body: const Center(
        child: Text(
          'Thiếu dữ liệu điều hướng (extra).\n'
          'Vui lòng mở từ trong app.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
