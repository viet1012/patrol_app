import 'package:auto_size_text/auto_size_text.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

import '../translator.dart'; // nếu bạn dùng .tr(context)

class CommonSearchableDropdown extends StatelessWidget {
  final String label;
  final String? selectedValue;
  final List<String> items;
  final ValueChanged<String?>? onChanged;
  final bool isRequired;

  /// Optional: bạn muốn cho phép add item mới khi user search
  final bool allowAddNew;

  const CommonSearchableDropdown({
    super.key,
    required this.label,
    required this.selectedValue,
    required this.items,
    required this.onChanged,
    this.isRequired = false,
    this.allowAddNew = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownSearch<String>(
          popupProps: PopupProps.menu(
            showSearchBox: true,
            isFilterOnline: true,
            fit: FlexFit.loose,
            menuProps: MenuProps(
              backgroundColor: const Color(0xFF161D23),
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),

            /// 🔴 NO DATA FOUND CUSTOM
            emptyBuilder: (context, searchEntry) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 40,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "No data found",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },

            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: "search_or_add_new".tr(context),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.white.withOpacity(0.7),
                ),
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),

            itemBuilder: (context, item, isSelected) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected
                      ? Colors.white.withOpacity(0.12)
                      : Colors.transparent,
                ),
                child: AutoSizeText(
                  item,
                  maxLines: 2,
                  minFontSize: 11,
                  stepGranularity: 0.5,
                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),

          /// ✅ FILTER + ADD NEW (optional)
          asyncItems: (String filter) async {
            final lower = filter.toLowerCase();

            final result = items
                .where((e) => e.toLowerCase().contains(lower))
                .toList();

            if (allowAddNew) {
              final trimmed = filter.trim();
              if (trimmed.isNotEmpty && !items.contains(trimmed)) {
                result.insert(0, trimmed);
              }
            }

            return result;
          },

          compareFn: (item, selectedItem) => item.trim() == selectedItem.trim(),

          selectedItem: selectedValue ?? '',

          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              hintText: label,
              hintMaxLines: 1,
              floatingLabelBehavior: FloatingLabelBehavior.never,

              filled: true,
              fillColor: Colors.white.withOpacity(0.08),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.35)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: const Color(0xFF4DD0E1).withOpacity(0.45),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF4DD0E1),
                  width: 1.6,
                ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ),

          dropdownBuilder: (context, selectedItem) {
            final bool isEmpty = selectedItem == null || selectedItem.isEmpty;

            Color textColor;
            FontWeight fontWeight;

            if (isEmpty && isRequired) {
              textColor = Colors.red.withOpacity(.6);
              fontWeight = FontWeight.w600;
            } else if (!isEmpty) {
              textColor = Colors.white;
              fontWeight = FontWeight.bold;
            } else {
              textColor = Colors.white.withOpacity(0.6);
              fontWeight = FontWeight.w500;
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: AutoSizeText(
                    isEmpty ? label : selectedItem,
                    maxLines: 2,
                    minFontSize: 11,
                    stepGranularity: 0.5,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: fontWeight,
                      color: textColor,
                    ),
                  ),
                ),
                if (isRequired && isEmpty) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: Colors.red.withOpacity(.6),
                  ),
                ],
              ],
            );
          },

          onChanged: onChanged,
        ),
      ],
    );
  }
}
