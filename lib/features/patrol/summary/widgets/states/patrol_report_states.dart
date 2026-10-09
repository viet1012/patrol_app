import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';
import 'package:flutter/material.dart';

typedef _T = PatrolReportTokens;

/// Skeleton cho lần tải đầu: thanh công cụ + các dòng xám nhấp nháy nhẹ.
class PatrolReportSkeleton extends StatefulWidget {
  final int rows;

  const PatrolReportSkeleton({super.key, this.rows = 12});

  @override
  State<PatrolReportSkeleton> createState() => _PatrolReportSkeletonState();
}

class _PatrolReportSkeletonState extends State<PatrolReportSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.45,
    end: 1,
  ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Widget _bar({double? width, double height = 14, double radius = _T.r10}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _T.skeletonBase,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _T.isMobile(context);
    final rowHeight = isMobile ? 48.0 : 56.0;

    return FadeTransition(
      opacity: _opacity,
      child: Padding(
        padding: const EdgeInsets.all(_T.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 0; i < (isMobile ? 3 : 5); i++) ...[
                  _bar(width: 72, height: 32, radius: _T.rPill),
                  const SizedBox(width: _T.s8),
                ],
              ],
            ),
            const SizedBox(height: _T.s12),
            Row(
              children: [
                _bar(width: _T.tapTarget, height: _T.tapTarget),
                const SizedBox(width: _T.s8),
                _bar(width: _T.tapTarget, height: _T.tapTarget),
                const SizedBox(width: _T.s8),
                Expanded(child: _bar(height: _T.tapTarget)),
              ],
            ),
            const SizedBox(height: _T.s12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_T.r10),
                child: Column(
                  children: [
                    Container(height: 44, color: _T.glassBorder),
                    for (var i = 0; i < widget.rows; i++)
                      Container(
                        height: rowHeight,
                        padding: const EdgeInsets.symmetric(horizontal: _T.s12),
                        color: i.isEven ? _T.glass : Colors.transparent,
                        child: Row(
                          children: [
                            _bar(width: 36),
                            const SizedBox(width: _T.s16),
                            _bar(width: 72),
                            const SizedBox(width: _T.s16),
                            Expanded(child: _bar()),
                            const SizedBox(width: _T.s16),
                            if (!isMobile) ...[
                              Expanded(child: _bar()),
                              const SizedBox(width: _T.s16),
                            ],
                            _bar(width: 64, height: 22, radius: _T.rPill),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khung glass dùng chung cho trang lỗi / empty.
class _MessageCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final List<Widget> actions;

  const _MessageCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(_T.s16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: _T.s16 + _T.s8,
              vertical: _T.s16 + _T.s12,
            ),
            decoration: BoxDecoration(
              color: _T.glass,
              borderRadius: BorderRadius.circular(_T.r14),
              border: Border.all(color: _T.glassBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(_T.s12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor.withValues(alpha: 0.15),
                  ),
                  child: Icon(icon, color: iconColor, size: 36),
                ),
                const SizedBox(height: _T.s16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _T.textPrimary,
                    fontSize: _T.fsXl,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: _T.s8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _T.textSecondary,
                    fontSize: _T.fsMd,
                  ),
                ),
                const SizedBox(height: _T.s16),
                Wrap(
                  spacing: _T.s8,
                  runSpacing: _T.s8,
                  alignment: WrapAlignment.center,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lỗi tải dữ liệu, có nút Retry.
class PatrolReportErrorView extends StatelessWidget {
  final String title;
  final String message;

  /// null = ẩn nút Retry.
  final VoidCallback? onRetry;
  final VoidCallback onBack;

  const PatrolReportErrorView({
    super.key,
    required this.message,
    required this.onBack,
    this.onRetry,
    this.title = 'Could not load reports',
  });

  @override
  Widget build(BuildContext context) {
    return _MessageCard(
      icon: Icons.error_outline_rounded,
      iconColor: Colors.redAccent,
      title: title,
      message: message,
      actions: [
        OutlinedButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Back'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _T.textSecondary,
            side: const BorderSide(color: _T.border),
            minimumSize: const Size(0, _T.tapTarget),
          ),
        ),
        if (onRetry != null)
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(
              backgroundColor: _T.accentStrong,
              minimumSize: const Size(0, _T.tapTarget),
            ),
          ),
      ],
    );
  }
}

/// Lọc ra 0 dòng (khác với chưa có report nào).
class PatrolReportNoMatchView extends StatelessWidget {
  final VoidCallback onClearFilters;

  const PatrolReportNoMatchView({super.key, required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(_T.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off_outlined, size: 40, color: _T.textMuted),
            const SizedBox(height: _T.s8),
            Text(
              'No matching reports',
              style: TextStyle(
                fontSize: _T.fsXl,
                fontWeight: FontWeight.w700,
                color: _T.textPrimary,
              ),
            ),
            const SizedBox(height: _T.s4),
            Text(
              'Try removing some filters or widening the date range.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: _T.fsMd, color: _T.textSecondary),
            ),
            const SizedBox(height: _T.s12),
            FilledButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('Clear filters'),
              style: FilledButton.styleFrom(
                backgroundColor: _T.accentStrong,
                minimumSize: const Size(0, _T.tapTarget),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
