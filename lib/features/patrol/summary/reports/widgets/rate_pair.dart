import 'package:flutter/material.dart';

import 'package:chuphinh/shared/utils/formatters.dart';
import 'package:chuphinh/features/patrol/summary/reports/widgets/summary_grid_style.dart';

const _goodColor = Colors.green;
const _badColor = Colors.redAccent;

List<TextSpan> _rateSpans(String label, double? rate, Color color) => [
  TextSpan(text: '$label ', style: SummaryGridStyle.rateLabelStyle),
  TextSpan(
    text: fmtRate(rate),
    style: SummaryGridStyle.rateValueStyle.copyWith(color: color),
  ),
];

/// "Finished 72%   •   Remain 28%": giá trị đầu màu xanh, giá trị sau màu đỏ.
class RatePair extends StatelessWidget {
  final String goodLabel;
  final double? goodRate;
  final String badLabel;
  final double? badRate;

  const RatePair({
    super.key,
    required this.goodLabel,
    required this.goodRate,
    required this.badLabel,
    required this.badRate,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 1,
      text: TextSpan(
        children: [
          ..._rateSpans(goodLabel, goodRate, _goodColor),
          const TextSpan(
            text: '   •   ',
            style: TextStyle(color: Colors.black38, fontSize: 14),
          ),
          ..._rateSpans(badLabel, badRate, _badColor),
        ],
      ),
    );
  }
}

/// 1 tỉ lệ ("Finished 72%"), cùng style với [RatePair]; [good] chọn màu.
class RateValue extends StatelessWidget {
  final String label;
  final double? rate;
  final bool good;

  const RateValue({
    super.key,
    required this.label,
    required this.rate,
    required this.good,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 1,
      text: TextSpan(
        children: _rateSpans(label, rate, good ? _goodColor : _badColor),
      ),
    );
  }
}
