part of '../test.dart';

extension _CameraScreenView on _CameraScreenState {

  Widget _buildCameraScreen(BuildContext context) {
    final groupList = getGroupsByPlant();

    final facList = <String>{
      if (_selectedPlant != null) ...getFacByPlant(_selectedPlant!),

      if (_qrFallbackMachine != null &&
          _norm(_qrFallbackMachine!.plant) == _norm(_selectedPlant) &&
          _qrFallbackMachine!.fac.isNotEmpty)
        _qrFallbackMachine!.fac,
    }.toList();

    final areaList = <String>{
      if (_selectedPlant != null && _selectedFac != null)
        ...getAreaByFac(_selectedPlant!, _selectedFac!),

      if (_qrFallbackMachine != null &&
          _norm(_qrFallbackMachine!.plant) == _norm(_selectedPlant) &&
          _norm(_qrFallbackMachine!.fac) == _norm(_selectedFac) &&
          _qrFallbackMachine!.area.isNotEmpty)
        _qrFallbackMachine!.area,
    }.toList();

    final machineList = <String>{
      if (_selectedPlant != null &&
          _selectedFac != null &&
          _selectedArea != null)
        ...getMachineByArea(_selectedPlant!, _selectedFac!, _selectedArea!),

      if (_qrFallbackMachine != null &&
          _norm(_qrFallbackMachine!.plant) == _norm(_selectedPlant) &&
          _norm(_qrFallbackMachine!.fac) == _norm(_selectedFac) &&
          _norm(_qrFallbackMachine!.area) == _norm(_selectedArea) &&
          _qrFallbackMachine!.macId.isNotEmpty)
        _qrFallbackMachine!.macId,
    }.toList();

    final minLength = (widget.lang == 'JP') ? 1 : 2;

    return Scaffold(
      // ? QUAN TR?NG: Giúp giao di?n t? co lên khi bàn phím hi?n
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Color(0xFF121826),
        // soft dark blue
        centerTitle: false,
        titleSpacing: 4,
        leading: GlassActionButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.titleScreen,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedPlant ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ValueListenableBuilder<List<Uint8List>>(
            valueListenable: _imagesNotifier,
            builder: (context, images, _) {
              final hasImages = images.isNotEmpty;
              final canSubmit = hasImages && !_isSubmitting;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasImages)
                    SizedBox(
                      width: 168,
                      height: 52,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          final image = images[index];

                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    image,
                                    width: 50,
                                    height: 50,
                                    cacheWidth: 100,
                                    cacheHeight: 100,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    filterQuality: FilterQuality.low,
                                  ),
                                ),
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: GestureDetector(
                                    onTap: _isSubmitting
                                        ? null
                                        : () {
                                            _cameraKey.currentState
                                                ?.removeImage(index);
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  GlassActionButton(
                    icon: _isSubmitting
                        ? Icons.hourglass_top_rounded
                        : Icons.send_rounded,
                    enabled: canSubmit,
                    onTap: canSubmit ? _sendReport : null,
                    backgroundColor: canSubmit ? const Color(0xFF22C55E) : null,
                    iconColor: canSubmit ? Colors.black : Colors.white54,
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,

        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF121826), // soft dark blue
              Color(0xFF1F2937), // slate blue
              Color(0xFF374151), // soft steel
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              // CAMERA + QR CHECK OVERLAY
              _buildCameraSection(),
              const SizedBox(height: 8),

              _buildBatterySavingTip(),

              const SizedBox(height: 16),
              if (widget.patrolGroup != PatrolGroup.AssetUpdate) ...[
                // CÁC DROPDOWN PHÍA TRÊN
                Row(
                  children: [
                    Expanded(
                      child: _buildSearchableDropdown(
                        label: "group".tr(context),
                        selectedValue: _selectedGroup,
                        items: groupList,
                        onChanged: (v) {
                          setState(() {
                            _selectedGroup = v;
                          });
                        },
                        isRequired: true,
                      ),
                    ),

                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSearchableDropdown(
                        label: "fac".tr(context),
                        selectedValue: _selectedFac,
                        items: _selectedPlant == null
                            ? <String>[]
                            : facList.cast<String>(),
                        onChanged: (v) {
                          setState(() {
                            _selectedFac = v;
                            _selectedArea = null;

                            final isFallbackMachine =
                                _qrFallbackMachine != null &&
                                _norm(_qrFallbackMachine!.macId) ==
                                    _norm(_selectedMachine);

                            if (!isFallbackMachine) {
                              _selectedMachine = null;
                            }

                            if (isFallbackMachine) {
                              _qrFallbackMachine = HseMachineInfo(
                                plant:
                                    _selectedPlant ??
                                    widget.selectedPlant ??
                                    '',
                                fac: v ?? '',
                                area: _selectedArea ?? '',
                                macId:
                                    _selectedMachine ??
                                    _qrFallbackMachine!.macId,
                              );
                            }

                            final areas = getAreaByFac(_selectedPlant!, v!);
                            if (!isFallbackMachine && areas.length == 1) {
                              _selectedArea = areas.first;

                              final machines = getMachineByArea(
                                _selectedPlant!,
                                v,
                                areas.first,
                              );

                              if (machines.length == 1) {
                                _selectedMachine = machines.first;
                              }
                            }
                          });
                        },
                        isRequired: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    if (widget.patrolGroup != PatrolGroup.AssetUpdate)
                      Expanded(
                        child: _buildSearchableDropdown(
                          label: "area".tr(context),
                          selectedValue: _selectedArea,
                          items:
                              (_selectedPlant == null || _selectedFac == null)
                              ? <String>[]
                              : areaList.cast<String>(),
                          onChanged: (v) {
                            String? autoMachine;

                            setState(() {
                              _selectedArea = v;

                              final isFallbackMachine =
                                  _qrFallbackMachine != null &&
                                  _norm(_qrFallbackMachine!.macId) ==
                                      _norm(_selectedMachine);

                              if (!isFallbackMachine) {
                                _selectedMachine = null;
                              }

                              if (isFallbackMachine) {
                                _qrFallbackMachine = HseMachineInfo(
                                  plant:
                                      _selectedPlant ??
                                      widget.selectedPlant ??
                                      '',
                                  fac: _selectedFac ?? '',
                                  area: v ?? '',
                                  macId:
                                      _selectedMachine ??
                                      _qrFallbackMachine!.macId,
                                );
                              }

                              final machines = getMachineByArea(
                                _selectedPlant!,
                                _selectedFac!,
                                v!,
                              );

                              if (!isFallbackMachine && machines.length == 1) {
                                autoMachine = machines.first;
                                _selectedMachine = autoMachine;
                              }
                            });

                            if (_aiEnabled && autoMachine != null) {
                              _loadMachineAiSummary(autoMachine);
                            }
                          },
                          isRequired: true,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSearchableDropdown(
                        label: "machine".tr(context),
                        selectedValue: _selectedMachine,
                        items:
                            (_selectedPlant == null ||
                                _selectedFac == null ||
                                _selectedArea == null)
                            ? <String>[]
                            : machineList.cast<String>(),
                        onChanged: _onMachineChanged,
                        isRequired: true,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),

              MachineAiRiskHistoryPanel(
                lang: widget.lang,
                enabled: _aiEnabled,
                loading: _isLoadingMachineAi,
                hasMachine: (_selectedMachine?.isNotEmpty ?? false),
                machine: _selectedMachine,
                error: _machineAiError,
                summary: _machineAiSummary,
                summaryJp: _summaryJp,
                translatingJp: _isTranslatingAi,
                onTranslateJp: _translateAiSummaryToJp,
                onRetry: () =>
                    _loadMachineAiSummary(_selectedMachine, force: true),
                onToggle: () {
                  final mac = _selectedMachine ?? '';

                  setState(() {
                    _aiEnabled = !_aiEnabled;
                  });

                  if (_aiEnabled) {
                    _loadMachineAiSummary(mac);
                  } else {
                    setState(() {
                      _machineAiSummary = null;
                      _machineAiError = null;
                      _lastAiMachine = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              // CÁC DROPDOWN RISK
              if (widget.patrolGroup != PatrolGroup.AssetUpdate)
                _buildRiskSection(),

              const SizedBox(height: 8),

              // ---------------------------------------------------------
              // PH?N AUTO COMPLETE ÐÃ T?I UU CHO MOBILE
              // ---------------------------------------------------------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ô 1: COMMENT
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return RawAutocomplete<AutoCmp>(
                          textEditingController: _commentController,
                          focusNode: _commentFocusNode,
                          optionsViewOpenDirection: OptionsViewOpenDirection.up,
                          displayStringForOption: (option) => option.inputText,

                          optionsBuilder: (TextEditingValue value) {
                            final keyword = value.text.trim().toLowerCase();

                            if (keyword.length < minLength || isLoading) {
                              return const Iterable<AutoCmp>.empty();
                            }

                            return allOptionsComment
                                .where(
                                  (option) => option.inputText
                                      .toLowerCase()
                                      .contains(keyword),
                                )
                                .take(5);
                          },

                          onSelected: (AutoCmp selection) {
                            final comment = selection.inputText.trim();

                            _commentController.value = TextEditingValue(
                              text: comment,
                              selection: TextSelection.collapsed(
                                offset: comment.length,
                              ),
                            );

                            final countermeasure = selection.countermeasure
                                .trim();

                            _counterController.value = TextEditingValue(
                              text: countermeasure,
                              selection: TextSelection.collapsed(
                                offset: countermeasure.length,
                              ),
                            );

                            setState(() {
                              _comment = comment;
                              _counterMeasure = countermeasure;
                              _commentFontSizeNotifier.value = _resolveFontSize(
                                comment,
                              );
                              _counterFontSizeNotifier.value = _resolveFontSize(
                                countermeasure,
                              );
                            });
                          },

                          fieldViewBuilder:
                              (
                                context,
                                controller,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                // Không gán lại _commentController = controller.
                                // RawAutocomplete đang dùng chính _commentController.
                                return ValueListenableBuilder<double>(
                                  valueListenable: _commentFontSizeNotifier,
                                  builder: (context, fontSize, _) {
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      enabled: !_isSubmitting,
                                      maxLines: 3,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: fontSize,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        hint: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'commentHint'.tr(context),
                                              style: TextStyle(
                                                color: Colors.red.withOpacity(
                                                  .6,
                                                ),
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.star_rounded,
                                              size: 14,
                                              color: Colors.red.withOpacity(.6),
                                            ),
                                          ],
                                        ),
                                        fillColor: Colors.green.withOpacity(
                                          .08,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.white.withOpacity(
                                              .35,
                                            ),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide(
                                            color: const Color(
                                              0xFF90E14D,
                                            ).withOpacity(.25),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide(
                                            color: const Color(
                                              0xFF90E14D,
                                            ).withOpacity(.45),
                                          ),
                                        ),
                                        contentPadding: const EdgeInsets.all(
                                          12,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        _commentFontSizeNotifier.value =
                                            _resolveFontSize(value);

                                        if (value.trim().isEmpty) {
                                          _counterController.clear();
                                          _counterFontSizeNotifier.value = 14;
                                        }

                                        _commentDebounce?.cancel();
                                        _commentDebounce = Timer(
                                          const Duration(milliseconds: 250),
                                          () {
                                            _comment = value;

                                            if (value.trim().isEmpty) {
                                              _counterMeasure = '';
                                            }
                                          },
                                        );
                                      },
                                    );
                                  },
                                );
                              },

                          optionsViewBuilder: (context, onSelected, options) {
                            final optionList = options.toList(growable: false);

                            return Align(
                              alignment: Alignment.topLeft,
                              child: Transform.translate(
                                offset: const Offset(0, 8),
                                child: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.black.withOpacity(.5),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth,
                                      maxHeight: 250,
                                    ),
                                    child: ListView.separated(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: optionList.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(
                                            height: 1,
                                            thickness: .5,
                                          ),
                                      itemBuilder: (context, index) {
                                        final option = optionList[index];

                                        return InkWell(
                                          onTap: () => onSelected(option),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            child: Text(
                                              option.inputText,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  if (widget.patrolGroup != PatrolGroup.AssetUpdate) ...[
                    const SizedBox(width: 8),
                    // Ô 2: COUNTERMEASURE (gi? nguyên, không c?n linking ngu?c)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return RawAutocomplete<AutoCmp>(
                            textEditingController: _counterController,
                            focusNode: _counterFocusNode,
                            optionsViewOpenDirection:
                                OptionsViewOpenDirection.up,
                            displayStringForOption: (option) =>
                                option.inputText,

                            optionsBuilder: (TextEditingValue value) {
                              final keyword = value.text.trim().toLowerCase();

                              if (keyword.length < minLength || isLoading) {
                                return const Iterable<AutoCmp>.empty();
                              }

                              return allOptionsCounter
                                  .where(
                                    (option) => option.inputText
                                        .toLowerCase()
                                        .contains(keyword),
                                  )
                                  .take(5);
                            },

                            onSelected: (AutoCmp selection) {
                              final countermeasure = selection.inputText.trim();

                              _counterController.value = TextEditingValue(
                                text: countermeasure,
                                selection: TextSelection.collapsed(
                                  offset: countermeasure.length,
                                ),
                              );

                              setState(() {
                                _counterMeasure = countermeasure;
                                _counterFontSizeNotifier.value =
                                    _resolveFontSize(countermeasure);
                              });
                            },

                            fieldViewBuilder:
                                (
                                  context,
                                  controller,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  // Không gán lại _counterController = controller.
                                  return ValueListenableBuilder<double>(
                                    valueListenable: _counterFontSizeNotifier,
                                    builder: (context, fontSize, _) {
                                      return TextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        enabled: !_isSubmitting,
                                        maxLines: 3,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: fontSize,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'counterMeasureHint'.tr(
                                            context,
                                          ),
                                          filled: true,
                                          fillColor: Colors.green.withOpacity(
                                            .08,
                                          ),
                                          hintStyle: TextStyle(
                                            color: Colors.white.withOpacity(.6),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.white.withOpacity(
                                                .35,
                                              ),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: const Color(
                                                0xFF90E14D,
                                              ).withOpacity(.25),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: const Color(
                                                0xFF90E14D,
                                              ).withOpacity(.45),
                                            ),
                                          ),
                                          contentPadding: const EdgeInsets.all(
                                            12,
                                          ),
                                        ),
                                        onChanged: (value) {
                                          _counterFontSizeNotifier.value =
                                              _resolveFontSize(value);

                                          _counterDebounce?.cancel();
                                          _counterDebounce = Timer(
                                            const Duration(milliseconds: 250),
                                            () {
                                              _counterMeasure = value;
                                            },
                                          );
                                        },
                                      );
                                    },
                                  );
                                },

                            optionsViewBuilder: (context, onSelected, options) {
                              final optionList = options.toList(
                                growable: false,
                              );

                              return Align(
                                alignment: Alignment.topLeft,
                                child: Transform.translate(
                                  offset: const Offset(0, 8),
                                  child: Material(
                                    elevation: 8,
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.black.withOpacity(.5),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: constraints.maxWidth,
                                        maxHeight: 250,
                                      ),
                                      child: ListView.separated(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: optionList.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(
                                              height: 1,
                                              thickness: .5,
                                            ),
                                        itemBuilder: (context, index) {
                                          final option = optionList[index];

                                          return InkWell(
                                            onTap: () => onSelected(option),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 14,
                                                  ),
                                              child: Text(
                                                option.inputText,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),

              // Checkbox và ph?n cu?i
              if (widget.patrolGroup != PatrolGroup.AssetUpdate)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Checkbox(
                          value: _needRecheck,
                          onChanged: _isSubmitting
                              ? null
                              : (v) =>
                                    setState(() => _needRecheck = v ?? false),
                          activeColor: Colors.orange.shade700,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "needRecheck".tr(context),
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ),
                      GlassActionButton(
                        icon: Icons.edit_calendar_sharp,
                        enabled: true,
                        onTap: () {
                          // if (_selectedGroup == null || _selectedGroup!.isEmpty) {
                          //   _showSelectGroupWarning(context);
                          //   return;
                          // }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditBeforeScreen(
                                machines: widget.machines,
                                accountCode: widget.accountCode,
                                selectedFac: _selectedFac,
                                selectedPlant: _selectedPlant,
                                selectedGrp: widget.autoTeam?.grp ?? '',
                                titleScreen: widget.titleScreen,
                                patrolGroup: widget.patrolGroup,
                              ),
                            ),
                          );
                        },
                        backgroundColor: const Color(
                          0xFF22C55E,
                        ).withOpacity(.4),
                        iconColor: Colors.white,
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
