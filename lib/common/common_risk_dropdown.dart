import 'package:flutter/material.dart';

import '../model/reason_model.dart';
import '../translator.dart';

class CommonRiskDropdown extends StatelessWidget {
  final String labelKey;
  final String? valueKey;
  final List<RiskOption> items;
  final ValueChanged<String?> onChanged;
  final Color? fillColor;

  const CommonRiskDropdown({
    super.key,
    required this.labelKey,
    required this.valueKey,
    required this.items,
    required this.onChanged,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final values = items.map((e) => e.labelKey).toList();

    // n?u valueKey không n?m trong list => set null d? không assert
    final safeValue = (valueKey != null && values.contains(valueKey))
        ? valueKey
        : null;
    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      dropdownColor: const Color(0xFF2A2E32),

      decoration: InputDecoration(
        labelText: labelKey.tr(context),

        filled: true,
        fillColor: fillColor ?? Colors.orange.withOpacity(0.08),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.35),
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: const Color(0xFF7986CB).withOpacity(0.45),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7986CB), width: 1.8),
        ),

        contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 14),

        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.65),
          fontSize: 14,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF7986CB),
          fontWeight: FontWeight.bold,
        ),
      ),

      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),

      selectedItemBuilder: (_) {
        return items.map((e) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              e.labelKey.tr(context),
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }).toList();
      },

      items: items.map((e) {
        return DropdownMenuItem<String>(
          value: e.labelKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.labelKey.tr(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                "(${e.score})",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),

      onChanged: onChanged,
    );
  }
}
