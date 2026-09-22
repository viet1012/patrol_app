import 'package:chuphinh/widget/glass_action_button.dart';
import 'package:flutter/material.dart';

class PatrolReportFilterPopup extends StatelessWidget {
  final String column;
  final LayerLink layerLink;
  final List<String> values;
  final Set<String> selectedValues;
  final ScrollController scrollController;
  final ValueChanged<String> onSearchChanged;
  final void Function(String value, bool checked) onValueChanged;
  final VoidCallback onClear;
  final VoidCallback onClose;

  const PatrolReportFilterPopup({
    super.key,
    required this.column,
    required this.layerLink,
    required this.values,
    required this.selectedValues,
    required this.scrollController,
    required this.onSearchChanged,
    required this.onValueChanged,
    required this.onClear,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: layerLink,
      offset: const Offset(0, 44),
      showWhenUnlinked: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 260,
          height: 340,
          decoration: BoxDecoration(
            color: const Color(0xFF172A33).withOpacity(.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white24)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        column,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: onClose,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search value',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    prefixIconColor: Colors.white54,
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blueAccent),
                    ),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              Expanded(
                child: values.isEmpty
                    ? const Center(
                        child: Text(
                          'No values',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : Scrollbar(
                        controller: scrollController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: scrollController,
                          primary: false,
                          padding: EdgeInsets.zero,
                          itemCount: values.length,
                          itemBuilder: (_, index) {
                            final value = values[index];
                            final checked = selectedValues.contains(value);
                            return InkWell(
                              onTap: () => onValueChanged(value, !checked),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: checked,
                                      onChanged: (ok) =>
                                          onValueChanged(value, ok == true),
                                      checkColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.white54,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        value,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white24)),
                ),
                child: Row(
                  children: [
                    GlassActionButton(
                      icon: Icons.cleaning_services,
                      onTap: onClear,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
