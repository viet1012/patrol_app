part of '../test.dart';

extension _CameraScreenFormWidgets on _CameraScreenState {
  Future<void> _loadInitialDataComment() async {
    try {
      final data = await AutoCmpApi.getAllComment(widget.lang);
      setState(() {
        allOptionsComment = data;
        isLoading = false;
      });
    } catch (e) {
      // Xử lý lỗi
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadInitialDataCounter() async {
    try {
      final data = await AutoCmpApi.getAllCounter(widget.lang);
      setState(() {
        allOptionsCounter = data;
        isLoading = false;
      });
    } catch (e) {
      // Xử lý lỗi
      setState(() => isLoading = false);
    }
  }

  Widget _buildRiskSection() {
    switch (widget.patrolGroup) {
      case PatrolGroup.QualityPatrol:
        return _buildQualityRiskSection();
      case PatrolGroup.Audit:
      case PatrolGroup.AssetUpdate:
      case PatrolGroup.Patrol:
        return _buildPatrolRiskSection();
    }
  }

  Widget _buildPatrolRiskSection() {
    final displayScore = RiskScoreCalculator.scoreSymbol(
      freqKey: _freq,
      probKey: _prob,
      sevKey: _sev,
      frequencyOptions: frequencyOptions,
      probabilityOptions: probabilityOptions,
      severityOptions: severityOptions,
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildRiskDropdown(
                labelKey: "label_freq",
                valueKey: _freq,
                items: frequencyOptions,
                onChanged: (v) => setState(() => _freq = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRiskDropdown(
                labelKey: "label_prob",
                valueKey: _prob,
                items: probabilityOptions,
                onChanged: (v) => setState(() => _prob = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildRiskDropdown(
                labelKey: "label_sev",
                valueKey: _sev,
                items: severityOptions,
                onChanged: (v) => setState(() => _sev = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _buildRiskScoreField(displayScore)),
          ],
        ),
      ],
    );
  }

  Widget _buildRiskScoreField(String displayScore) {
    return TextField(
      enabled: false,
      controller: TextEditingController(text: displayScore),
      decoration: InputDecoration(
        labelText: "label_risk".tr(context),
        filled: true,
        fillColor: Colors.deepOrange.withOpacity(0.15),
        labelStyle: TextStyle(
          fontSize: 14,
          color: Colors.white.withOpacity(0.65),
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: Colors.deepOrange,
          fontWeight: FontWeight.bold,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.deepOrange.withOpacity(0.6)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 18,
        color: (displayScore == "V" || displayScore == "IV")
            ? Colors.red
            : Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildQualityRiskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 5. Tần suất phát sinh
        _buildRiskDropdown(
          labelKey: "label_freq",
          valueKey: _qaFreq,
          items: qaFrequencyOptions,
          onChanged: (v) => setState(() => _qaFreq = v),
        ),

        const SizedBox(height: 12),

        // 6. 5M phát sinh  (dropdown)
        _buildRiskDropdown(
          labelKey: "label_5m",
          valueKey: _qa5m,
          items: fiveMOptions,
          onChanged: (v) => setState(() => _qa5m = v),
        ),

        const SizedBox(height: 12),

        // 7. Mức độ ảnh hưởng đến chất lượng sản phẩm (dropdown)
        _buildRiskDropdown(
          labelKey: "label_quality_impact",
          valueKey: _qaImpact,
          items: qualityImpactOptions,
          onChanged: (v) => setState(() => _qaImpact = v),
        ),
      ],
    );
  }

  // 🔴 HÀM PHỤ TRỢ: _buildSearchableDropdown (Giữ nguyên)
  Widget _buildSearchableDropdown({
    required String label,
    required String? selectedValue,
    required List<String> items,
    required Function(String?)? onChanged,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          child: DropdownSearch<String>(
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
                          "No data found", // hoặc "No data found"
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
                style: TextStyle(
                  color: Colors.white, // <-- set màu chữ nhập thành trắng
                ),
              ),

              itemBuilder: (context, item, isSelected) {
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),

            // ... (các logic asyncItems, compareFn, v.v. giữ nguyên)
            asyncItems: (String filter) async {
              var result = items
                  .where((e) => e.toLowerCase().contains(filter.toLowerCase()))
                  .toList();

              // Nếu filter không rỗng và chưa có trong items thì thêm vào đầu danh sách
              if (filter.isNotEmpty && !items.contains(filter.trim())) {
                result.insert(0, filter.trim());
              }
              return result;
            },
            compareFn: (item, selectedItem) =>
                item.trim() == selectedItem.trim(),

            selectedItem: selectedValue ?? '',

            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                hintText: label,
                hintMaxLines: 1,
                floatingLabelBehavior: FloatingLabelBehavior.never,

                /// 🌫️ nền glass
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
                    color: Color(0xFF4DD0E1), // cyan
                    width: 1.6,
                  ),
                ),

                contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 12),

                /// 📝 hint
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
                  /// 📝 TEXT
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

                  /// ⭐ REQUIRED ICON
                  if (isRequired && isEmpty) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.star_rounded, // ⭐
                      size: 14,
                      color: Colors.red.withOpacity(.6),
                    ),
                  ],
                ],
              );
            },

            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // 🔴 HÀM PHỤ TRỢ: _buildRiskDropdown (Giữ nguyên)
  Widget _buildRiskDropdown({
    required String labelKey,
    required String? valueKey,
    required List<RiskOption> items,
    required Function(String?) onChanged,
  }) {
    // Tập key hợp lệ
    final validKeys = items.map((e) => e.labelKey).toSet();

    // ✅ Nếu valueKey null hoặc không nằm trong items -> trả null cho dropdown
    final safeValue = (valueKey != null && validKeys.contains(valueKey))
        ? valueKey
        : null;
    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      dropdownColor: const Color(0xFF2A2E32),

      // nền dropdown
      decoration: InputDecoration(
        labelText: labelKey.tr(context),

        /// 🌫️ nền mờ
        filled: true,
        fillColor: Colors.orange.withOpacity(0.08),

        /// 🔲 viền
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

        /// 📝 label bình thường
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.65),
          fontSize: 14,
        ),

        /// 🏷️ label khi bay lên
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
      selectedItemBuilder: (context) {
        return items.map((e) {
          return Container(
            alignment: Alignment.centerLeft,
            child: Text(
              e.labelKey.tr(context),
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: TextStyle(
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

      onChanged: (v) => setState(() => onChanged(v)),
    );
  }

  void showGlassDialog({
    required BuildContext context,
    IconData icon = Icons.info_outline,
    Color iconColor = Colors.blueAccent,
    String title = '',
    String message = '',
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// ICON
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: iconColor.withOpacity(0.15),
                    ),
                    child: Icon(icon, color: iconColor, size: 42),
                  ),

                  const SizedBox(height: 16),

                  /// TITLE
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),

                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),

                  /// BUTTON
                  SizedBox(
                    width: 150,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.9),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onPressed?.call();
                      },
                      child: Text(
                        buttonText,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
