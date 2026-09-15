part of '../test.dart';

extension _CameraScreenQr on _CameraScreenState {
  String _cacheKey2(String first, String second) {
    return '${_norm(first)}|${_norm(second)}';
  }

  String _cacheKey3(String first, String second, String third) {
    return '${_norm(first)}|${_norm(second)}|${_norm(third)}';
  }

  void _addUnique(Map<String, List<String>> target, String key, String value) {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) return;

    final values = target.putIfAbsent(key, () => <String>[]);

    final exists = values.any((item) => _norm(item) == _norm(normalizedValue));

    if (!exists) {
      values.add(normalizedValue);
    }
  }

  void _buildMasterIndexes() {
    _facByPlantCache.clear();
    _areaByPlantFacCache.clear();
    _machineByPlantFacAreaCache.clear();
    _groupsByPlantCache.clear();
    _localMachineKeys.clear();

    for (final team in widget.patrolTeams) {
      final plant = team.plant?.toString().trim() ?? '';
      final group = team.grp?.toString().trim() ?? '';

      if (plant.isEmpty || group.isEmpty) continue;

      _addUnique(_groupsByPlantCache, _norm(plant), group);
    }

    for (final item in widget.machines) {
      final plant = item.plant.toString().trim();
      final fac = item.fac.toString().trim();
      final area = item.area.toString().trim();
      final machine = item.macId.toString().trim();

      if (plant.isEmpty) continue;

      if (fac.isNotEmpty) {
        _addUnique(_facByPlantCache, _norm(plant), fac);
      }

      if (fac.isNotEmpty && area.isNotEmpty) {
        _addUnique(_areaByPlantFacCache, _cacheKey2(plant, fac), area);
      }

      if (fac.isNotEmpty && area.isNotEmpty && machine.isNotEmpty) {
        _addUnique(
          _machineByPlantFacAreaCache,
          _cacheKey3(plant, fac, area),
          machine,
        );

        _localMachineKeys.add(
          '${_cacheKey3(plant, fac, area)}|${_norm(machine)}',
        );
      }
    }

    for (final values in _facByPlantCache.values) {
      values.sort();
    }

    for (final values in _areaByPlantFacCache.values) {
      values.sort();
    }

    for (final values in _machineByPlantFacAreaCache.values) {
      values.sort();
    }

    for (final values in _groupsByPlantCache.values) {
      values.sort();
    }
  }

  List<String> getPlants() {
    final plants = _facByPlantCache.keys.toList(growable: false);
    plants.sort();
    return plants;
  }

  List<String> getGroupsByPlant() {
    final plant = _selectedPlant;
    if (plant == null || plant.trim().isEmpty) {
      return const <String>[];
    }

    return _groupsByPlantCache[_norm(plant)] ?? const <String>[];
  }

  List<String> getFacByPlant(String plant) {
    return _facByPlantCache[_norm(plant)] ?? const <String>[];
  }

  List<String> getAreaByFac(String plant, String fac) {
    return _areaByPlantFacCache[_cacheKey2(plant, fac)] ?? const <String>[];
  }

  List<String> getMachineByArea(String plant, String fac, String area) {
    return _machineByPlantFacAreaCache[_cacheKey3(plant, fac, area)] ??
        const <String>[];
  }

  String normalizeGroup(String? group) {
    return group == null ? '' : group.replaceAll(' ', '').trim();
  }

  String _extractMacIdFromQr(String qr) {
    final text = qr.trim();

    // KVH_A-2681_1F_A32-1_Retainer
    final match = RegExp(r'[A-Z]-\d+').firstMatch(text);

    if (match != null) {
      return match.group(0)!;
    }

    // A-769
    return text;
  }

  String? _extractAreaFromQr(String qr) {
    final parts = qr.trim().split('_');

    // KVH_A-2003_1F_A35-2_Ejector Pin
    if (parts.length >= 5) {
      final area = parts.sublist(4).join('_').trim();
      return area.isEmpty ? null : area;
    }

    return null;
  }

  HseMachineInfo _buildFallbackMachineInfoFromQr({
    required String rawQr,
    required String macId,
  }) {
    return HseMachineInfo(
      plant: _selectedPlant ?? widget.selectedPlant ?? '',
      fac: _selectedFac ?? '',
      area: _extractAreaFromQr(rawQr) ?? _selectedArea ?? '',
      macId: macId,
    );
  }

  Future<HseMachineInfo?> _fetchMachineInfoByMacId(String macId) async {
    try {
      final response = await DioClient.get(
        '/api/hse_master/by-macid',
        queryParameters: {'macId': macId},
      );

      final data = response.data;

      if (data == null) return null;

      if (data is List && data.isNotEmpty) {
        final first = data.first;

        if (first is Map) {
          return HseMachineInfo.fromJson(Map<String, dynamic>.from(first));
        }
      }

      if (data is Map) {
        return HseMachineInfo.fromJson(Map<String, dynamic>.from(data));
      }

      return null;
    } catch (e) {
      debugPrint('FETCH MACHINE INFO ERROR: $e');
      return null;
    }
  }

  bool _isBlank(String? value) {
    return value == null || value.trim().isEmpty;
  }

  String _norm(String? v) {
    return (v ?? '')
        .replaceAll(String.fromCharCode(160), ' ')
        .trim()
        .toLowerCase();
  }

  bool _existsInLocalMaster(HseMachineInfo info) {
    final key =
        '${_cacheKey3(info.plant, info.fac, info.area)}|${_norm(info.macId)}';

    return _localMachineKeys.contains(key);
  }

  Future<void> _handlePatrolQr(String rawQr) async {
    final qr = rawQr.trim();

    if (!RegExp(r'^\d{1,5}$').hasMatch(qr)) {
      if (!mounted) return;

      CommonUI.showWarning(
        context: context,
        title: 'Invalid QR Code',
        message:
            'QR code must contain only numbers and have a maximum of 5 digits.',
      );

      return;
    }

    // Ðã check thành công QR này r?i thì không g?i API l?i.
    if (_lastValidQrKey == qr && _qrKey == qr) {
      return;
    }

    // Scanner dang gi? camera trên cùng QR.
    // Không cho t?o thêm request trùng.
    if (_isCheckingQr && _checkingQrKey == qr) {
      return;
    }

    // Có request QR khác dang ch?y thì b? qua lu?t scan này.
    if (_isCheckingQr) {
      return;
    }

    setState(() {
      _isCheckingQr = true;
      _checkingQrKey = qr;
    });

    try {
      final result = await _checkQrDuplicate(qr);

      if (!mounted) return;

      if (!result.valid) {
        /*
       * Không gi? QR không h?p l? trên state cha.
       * Reset ph?n hi?n th? QR trong CameraPreviewBox.
       */
        _cameraKey.currentState?.resetQr();

        CommonUI.showWarning(
          context: context,
          title: 'Invalid QR Code',
          message: result.message.isNotEmpty
              ? result.message
              : 'Invalid QR code.',
        );

        return;
      }

      if (result.duplicate || !result.available) {
        /*
       * QR b? trùng thì không gán vào _qrKey.
       * UI camera cung xóa QR v?a quét d? ngu?i dùng quét mã khác.
       */
        _cameraKey.currentState?.resetQr();

        CommonUI.showWarning(
          context: context,
          title: 'Duplicate QR Code',
          message: result.message.isNotEmpty
              ? result.message
              : 'QR code $qr already exists and has not been closed.',
        );

        return;
      }

      final acceptedQr = result.qrKey == null || result.qrKey!.isEmpty
          ? qr
          : result.qrKey!;

      setState(() {
        _qrKey = acceptedQr;
        _lastValidQrKey = acceptedQr;
      });

      CommonUI.showSnackBar(
        context: context,
        message: 'QR code $acceptedQr is available.',
        color: Colors.green,
      );
    } on DioException catch (error) {
      if (!mounted) return;

      /*
     * API check l?i thì không nên ch?p nh?n QR,
     * vì chua xác d?nh du?c QR có trùng hay không.
     */
      _cameraKey.currentState?.resetQr();

      CommonUI.showWarning(
        context: context,
        title: 'QR Check Failed',
        message: error.type == DioExceptionType.connectionTimeout
            ? 'Connection timeout while checking QR code.'
            : error.type == DioExceptionType.receiveTimeout
            ? 'The server took too long to check the QR code.'
            : ApiErrorMessage.fromDio(error),
      );
    } catch (error) {
      if (!mounted) return;

      _cameraKey.currentState?.resetQr();

      CommonUI.showWarning(
        context: context,
        title: 'QR Check Failed',
        message: 'Unable to verify QR code. Please scan again.',
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isCheckingQr = false;
        _checkingQrKey = null;
      });
    }
  }

  Future<void> _handleQrDetected(String qr) async {
    final rawQr = qr.trim();

    if (rawQr.isEmpty) {
      return;
    }

    // ============================================================
    // ASSET UPDATE
    // QR bất kỳ đều chính là qr_key của report.
    // Không check duplicate.
    // Không parse thành machine QR.
    // ============================================================

    if (widget.patrolGroup == PatrolGroup.AssetUpdate) {
      if (!mounted) {
        return;
      }

      setState(() {
        _qrKey = rawQr;
      });

      return;
    }

    final isQrNumber = RegExp(r'^\d+$').hasMatch(rawQr);

    // ============================================================
    // QR NUMBER
    // ============================================================

    if (isQrNumber) {
      // Chỉ Patrol mới check QR trùng.
      if (widget.patrolGroup == PatrolGroup.Patrol) {
        await _handlePatrolQr(rawQr);

        return;
      }

      // Audit / Quality Patrol / các loại khác:
      // chỉ lưu QR, không check duplicate.
      if (!mounted) {
        return;
      }

      setState(() {
        _qrKey = rawQr;
      });

      return;
    }

    // ============================================================
    // QR MACHINE
    //
    // AssetUpdate đã return phía trên,
    // nên phần này chỉ còn áp dụng cho Patrol /
    // Quality Patrol / Audit... theo flow hiện tại.
    // ============================================================

    if (_isLoadingMachineInfo) {
      return;
    }

    final macId = _extractMacIdFromQr(rawQr);

    if (macId.trim().isEmpty) {
      return;
    }

    setState(() {
      _isLoadingMachineInfo = true;
      _loadingMacId = macId;
    });

    try {
      final apiInfo = await _fetchMachineInfoByMacId(macId);

      if (!mounted) {
        return;
      }

      final fallbackInfo = _buildFallbackMachineInfoFromQr(
        rawQr: rawQr,
        macId: macId,
      );

      final info = apiInfo ?? fallbackInfo;

      final validInMaster = _existsInLocalMaster(info);

      final samePlant = _norm(info.plant) == _norm(widget.selectedPlant);

      final shouldUseFallback = apiInfo == null || !validInMaster || !samePlant;

      final selectedInfo = shouldUseFallback ? fallbackInfo : info;

      setState(() {
        _qrFallbackMachine = shouldUseFallback ? fallbackInfo : null;

        _selectedPlant = selectedInfo.plant;

        _selectedFac = selectedInfo.fac;

        _selectedArea = selectedInfo.area;

        _selectedMachine = selectedInfo.macId;

        // Không thay đổi _qrKey.
        // QR machine không được làm mất QR Patrol.
      });

      if (_aiEnabled) {
        _loadMachineAiSummary(selectedInfo.macId);
      }

      CommonUI.showSnackBar(
        context: context,
        message: shouldUseFallback
            ? 'Machine added from QR: ${selectedInfo.macId}'
            : 'Machine detected: ${selectedInfo.macId}',
        color: shouldUseFallback ? Colors.orange : Colors.green,
      );
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingMachineInfo = false;
        _loadingMacId = null;
      });
    }
  }

  Future<QrCheckResult> _checkQrDuplicate(String qrKey) async {
    final normalizedQr = qrKey.trim();

    final response = await DioClient.get(
      '/api/report/check-qr',
      queryParameters: {'qrKey': normalizedQr},
    );

    final data = response.data;

    if (data is! Map) {
      throw const FormatException('Invalid QR check response.');
    }

    return QrCheckResult.fromJson(Map<String, dynamic>.from(data));
  }

}
