import 'package:flutter/material.dart';

import 'package:chuphinh/shared/utils/formatters.dart';

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

  static const _labelStyle = TextStyle(color: Colors.black54);

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        children: [
          TextSpan(text: '$goodLabel ', style: _labelStyle),
          TextSpan(
            text: fmtRate(goodRate),
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w800,
            ),
          ),
          const TextSpan(
            text: '   •   ',
            style: TextStyle(color: Colors.black38),
          ),
          TextSpan(text: '$badLabel ', style: _labelStyle),
          TextSpan(
            text: fmtRate(badRate),
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
