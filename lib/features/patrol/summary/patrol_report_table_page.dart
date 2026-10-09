import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chuphinh/core/api/auth_me_api.dart';
import 'package:chuphinh/core/models/auth_me.dart';
import 'package:chuphinh/core/models/patrol_group.dart';
import 'package:chuphinh/features/patrol/summary/patrol_report_table.dart';
import 'package:chuphinh/features/patrol/summary/widgets/states/patrol_report_states.dart';
import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';

/// Route `/home/summary?group=..&plant=..[&bộ lọc]`.
///
/// Tự tải quyền (AuthMe) theo tài khoản đang đăng nhập thay vì nhận qua
/// `extra`, nên F5 / mở link trực tiếp vẫn hoạt động.
class PatrolReportTablePage extends StatefulWidget {
  final String accountCode;
  final Uri uri;

  const PatrolReportTablePage({
    super.key,
    required this.accountCode,
    required this.uri,
  });

  @override
  State<PatrolReportTablePage> createState() => _PatrolReportTablePageState();
}

class _PatrolReportTablePageState extends State<PatrolReportTablePage> {
  late Future<AuthMe?> _me = AuthMeApi.fetch(widget.accountCode);

  String get _group => widget.uri.queryParameters['group'] ?? '';
  String get _plant => widget.uri.queryParameters['plant'] ?? '';

  PatrolGroup? get _patrolGroup =>
      PatrolGroup.values.where((g) => g.name == _group).firstOrNull;

  void _goHome() => context.go('/home');

  @override
  Widget build(BuildContext context) {
    final group = _patrolGroup;
    if (group == null) {
      return _scaffold(
        PatrolReportErrorView(
          title: 'Invalid link',
          message: 'Unknown patrol group "$_group".',
          onBack: _goHome,
        ),
      );
    }

    return FutureBuilder<AuthMe?>(
      future: _me,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _scaffold(const PatrolReportSkeleton());
        }

        final me = snapshot.data;
        if (me == null) {
          return _scaffold(
            PatrolReportErrorView(
              title: 'Could not load permissions',
              message: 'Please check the connection and try again.',
              onRetry: () => setState(() {
                _me = AuthMeApi.fetch(widget.accountCode);
              }),
              onBack: _goHome,
            ),
          );
        }

        // Cùng điều kiện với nút mở bảng ở Home.
        if (!me.can(group, PatrolAction.summary)) {
          return _scaffold(
            PatrolReportErrorView(
              title: 'No permission',
              message: 'You do not have permission to view this table.',
              onBack: _goHome,
            ),
          );
        }

        return PatrolReportTable(
          patrolGroup: _group,
          plant: _plant,
          accountCode: widget.accountCode,
          auth: me,
          queryParameters: widget.uri.queryParametersAll,
        );
      },
    );
  }

  Widget _scaffold(Widget child) => Scaffold(
    backgroundColor: PatrolReportTokens.pageBg,
    body: SafeArea(child: child),
  );
}
