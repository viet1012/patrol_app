import 'package:flutter/material.dart';

/// Location card: header + [picSelector] (full width) + [manualSelectors]
/// (4 dropdown cascade). Chỉ hiển thị, không gọi API.
class FixedAssetLocationSection extends StatelessWidget {
  final Widget picSelector;
  final Widget manualSelectors;

  const FixedAssetLocationSection({
    super.key,
    required this.picSelector,
    required this.manualSelectors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LOCATION',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(.6),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(
              children: [
                picSelector,
                const SizedBox(height: 8),
                manualSelectors,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
