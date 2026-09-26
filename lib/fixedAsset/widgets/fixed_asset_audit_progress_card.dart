import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../model/fixed_asset_audit_summary.dart';

/// Card tiến độ kiểm kê kỳ 3 tháng (số liệu từ backend /audit-summary).
/// Chỉ hiển thị: state và việc load/retry do `FixedAssetScreen` sở hữu.
class FixedAssetAuditProgressCard extends StatelessWidget {
  final FixedAssetAuditSummary? summary;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  const FixedAssetAuditProgressCard({
    super.key,
    required this.summary,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  static const Color _accent = Color(0xFF4DD0E1);
  static const Color _success = Color(0xFF22C55E);

  static final DateFormat _monthFormat = DateFormat('MMM');

  /// 64.0 -> "64", 64.5 -> "64.5", 64.27 -> "64.27".
  String _formatPercent(double value) {
    var text = value.toStringAsFixed(2);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return text;
  }

  /// Nhãn kỳ từ periodStart/periodEnd của backend, ví dụ "Jul–Sep 2026".
  String _formatPeriod(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '';

    final startMonth = _monthFormat.format(start);
    final endMonth = _monthFormat.format(end);

    if (start.year == end.year) {
      return '$startMonth–$endMonth ${end.year}';
    }
    return '$startMonth ${start.year}–$endMonth ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    final error = this.error;

    final period = summary == null
        ? ''
        : _formatPeriod(summary.periodStart, summary.periodEnd);

    final Widget body;

    if (summary != null) {
      final percent = summary.completionPercent;
      final done = percent >= 100;

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            '${summary.auditedMachines} / '
                            '${summary.totalMachines}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: '  ·  ${summary.remainingMachines} remaining',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatPercent(percent)}%',
                style: TextStyle(
                  color: done ? _success : _accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (percent / 100.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(.10),
              valueColor: AlwaysStoppedAnimation<Color>(
                done ? _success : _accent,
              ),
            ),
          ),
        ],
      );
    } else if (error != null) {
      body = Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Unable to load progress',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(.65),
                fontSize: 12,
              ),
            ),
          ),
          _retrySummaryButton(),
        ],
      );
    } else {
      // Loading lần đầu: skeleton gọn.
      body = ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          minHeight: 6,
          backgroundColor: Colors.white.withOpacity(.08),
          valueColor: AlwaysStoppedAnimation<Color>(_accent.withOpacity(.5)),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'AUDIT PROGRESS',
                style: TextStyle(
                  color: Colors.white.withOpacity(.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
              const Spacer(),
              // Refresh chạy nền khi đã có số liệu cũ.
              if (loading && summary != null) ...[
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: _accent,
                  ),
                ),
                const SizedBox(width: 6),
              ] else if (error != null && summary != null) ...[
                _retrySummaryButton(),
                const SizedBox(width: 4),
              ],
              if (period.isNotEmpty)
                Text(
                  period,
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          body,
        ],
      ),
    );
  }

  Widget _retrySummaryButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: loading ? null : onRetry,
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.refresh_rounded, size: 16, color: _accent),
      ),
    );
  }
}
