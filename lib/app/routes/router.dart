import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chuphinh/features/patrol/after/after_report_screen.dart';
import 'package:chuphinh/app/app_idle_detector.dart';
import 'package:chuphinh/shared/camera/camera_preview_box.dart';
import 'package:chuphinh/features/home/patrol_home_screen.dart';
import 'package:chuphinh/core/models/patrol_group.dart';
import 'package:chuphinh/features/auth/login/login_page.dart';
import 'package:chuphinh/app/routes/route_target.dart';
import 'package:chuphinh/app/splash/splash_page.dart';
import 'package:chuphinh/core/session/auth_session.dart';
import 'package:chuphinh/core/session/session_store.dart';
import 'package:chuphinh/features/patrol/summary/patrol_report_table_page.dart';

final router = GoRouter(
  navigatorKey: appNavigatorKey,
  // CameraPreviewBox tự suspend khi route của nó bị page route khác che.
  observers: [CameraPreviewRouteObserver.instance],

  // Chạy lại redirect khi khôi phục phiên (F5) xong.
  refreshListenable: AuthSession.instance,

  // ============================================================
  // GLOBAL AUTH GUARD
  // ============================================================
  redirect: (context, state) {
    final location = state.matchedLocation;
    final isLoginPage = location == RouteTarget.login;
    final isSplash = location == RouteTarget.splash;

    // URL đích: ở splash thì lấy từ ?from=, còn lại là URL hiện tại.
    final target = isSplash
        ? state.uri.queryParameters['from']
        : state.uri.toString();

    // Đang khôi phục phiên: chờ ở màn hình splash, giữ URL đích.
    if (AuthSession.instance.isRestoring) {
      if (isSplash) return null;
      final from = RouteTarget.safe(target);
      return from == null
          ? RouteTarget.splash
          : '${RouteTarget.splash}?from=${Uri.encodeComponent(from)}';
    }

    final authenticatedAccount = SessionStore.authenticatedAccount;

    final isAuthenticated =
        authenticatedAccount != null && authenticatedAccount.trim().isNotEmpty;

    // Chưa login -> chỉ được ở Login (giữ ?from= để quay lại sau khi login).
    if (!isAuthenticated) {
      if (isLoginPage) return null;
      final from = RouteTarget.safe(target);
      return from == null
          ? RouteTarget.login
          : '${RouteTarget.login}?from=${Uri.encodeComponent(from)}';
    }

    // Đã login, đang ở splash -> về trang đích.
    if (isSplash) return RouteTarget.afterLogin(target);

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
        child: LoginPage(from: state.uri.queryParameters['from']),
      ),
    ),

    GoRoute(
      path: RouteTarget.splash,
      pageBuilder: (context, state) =>
          NoTransitionPage(key: state.pageKey, child: const SplashPage()),
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

        return PatrolHomeScreen(accountCode: accountCode.trim());
      },
    ),

    GoRoute(
      path: '/home/summary',
      builder: (context, state) {
        final authenticatedAccount = SessionStore.authenticatedAccount;

        if (authenticatedAccount == null ||
            authenticatedAccount.trim().isEmpty) {
          return const LoginPage();
        }

        // Mọi tham số (group, plant, bộ lọc) nằm trong URL.
        return PatrolReportTablePage(
          accountCode: authenticatedAccount.trim(),
          uri: state.uri,
        );
      },
    ),

    GoRoute(
      path: '/after/:qr',
      builder: (context, state) {
        final authenticatedAccount = SessionStore.authenticatedAccount;

        if (authenticatedAccount == null ||
            authenticatedAccount.trim().isEmpty) {
          return const LoginPage();
        }

        // /after/<qr>?group=<PatrolGroup.name>
        final qr = (state.pathParameters['qr'] ?? '').trim();
        final groupName = state.uri.queryParameters['group'];
        final pg = PatrolGroup.values
            .where((g) => g.name == groupName)
            .firstOrNull;

        if (qr.isEmpty || pg == null) {
          return const _InvalidLinkPage();
        }

        return AfterReportScreen(
          accountCode: authenticatedAccount.trim(),
          qrCode: qr,
          patrolGroup: pg,
        );
      },
    ),
  ],
);

class _InvalidLinkPage extends StatelessWidget {
  const _InvalidLinkPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invalid link')),
      body: const Center(
        child: Text(
          'Link thiếu hoặc sai tham số (qr, group).\n'
          'Vui lòng mở từ trong app.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
