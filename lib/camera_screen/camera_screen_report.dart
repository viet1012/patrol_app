part of '../test.dart';

extension _CameraScreenReport on _CameraScreenState {
  Future<void> _sendReport() async {
    if (_isSubmitting) return;

    final isPatrol = widget.patrolGroup == PatrolGroup.Patrol;

    final isQA = widget.patrolGroup == PatrolGroup.QualityPatrol;
    final isAssetUpdate = widget.patrolGroup == PatrolGroup.AssetUpdate;
    final qrKey = _qrKey.trim();

    final images = List<Uint8List>.from(
      _cameraKey.currentState?.images ?? const <Uint8List>[],
    );

    // ============================================================
    // IMAGE REQUIRED
    // ============================================================

    if (images.isEmpty) {
      CommonUI.showWarning(
        context: context,
        title: 'Image Required',
        message: 'Please take at least one photo.',
      );

      return;
    }

    // ============================================================
    // PATROL QR REQUIRED
    // ============================================================
    // AssetUpdate: chỉ cần không rỗng
    if (isAssetUpdate && qrKey.isEmpty) {
      CommonUI.showWarning(
        context: context,
        title: 'QR Required',
        message: 'Please scan QR code before sending.',
      );

      return;
    }

    if (isPatrol && !RegExp(r'^\d{1,5}$').hasMatch(qrKey)) {
      CommonUI.showWarning(
        context: context,
        title: 'QR Required',
        message: 'Please scan a valid Patrol QR containing 1 to 5 digits.',
      );

      return;
    }

    // ============================================================
    // PATROL MASTER DATA REQUIRED
    // ============================================================

    if (isPatrol &&
        (_isBlank(_selectedPlant) ||
            _isBlank(_selectedFac) ||
            _isBlank(_selectedArea) ||
            _isBlank(_selectedMachine))) {
      CommonUI.showWarning(
        context: context,
        title: 'Information Required',
        message: 'Please select Plant, Fac, Area and Machine.',
      );

      return;
    }

    // ============================================================
    // PATROL RISK REQUIRED
    // ============================================================

    String riskTotal = '';

    if (isPatrol) {
      riskTotal = getScoreSymbol();

      final hasValidRisk =
          !_isBlank(_freq) &&
          !_isBlank(_prob) &&
          !_isBlank(_sev) &&
          const {'I', 'II', 'III', 'IV', 'V'}.contains(riskTotal);

      if (!hasValidRisk) {
        CommonUI.showWarning(
          context: context,
          title: 'Risk Assessment Required',
          message:
              'Please select Frequency, Probability and Severity '
              'before sending the Patrol report.',
        );

        return;
      }
    }

    // ============================================================
    // COMMENT REQUIRED
    // ============================================================

    final latestComment = _commentController.text.trim();

    final latestCounterMeasure = _counterController.text.trim();

    if (latestComment.isEmpty) {
      CommonUI.showWarning(
        context: context,
        title: 'Comment Required',
        message: 'Please enter a comment.',
      );

      return;
    }

    // ============================================================
    // BASIC DATA
    // ============================================================

    final plant = _selectedPlant?.trim() ?? '';

    final division = _selectedFac?.trim() ?? '';

    final area = _selectedArea?.trim() ?? '';

    final machine = _selectedMachine?.trim() ?? '';

    final cameraState = _cameraKey.currentState;

    final cameraWasSleeping = cameraState?.isCameraSleeping ?? true;

    final totalWatch = Stopwatch()..start();

    var loadingVisible = false;

    void hideLoading() {
      if (!loadingVisible) return;

      loadingVisible = false;

      LoadingDialog.hide();
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isSubmitting = true;
    });

    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) return;

    unawaited(LoadingDialog.show(context, message: 'Sending report...'));

    loadingVisible = true;

    try {
      // ==========================================================
      // CAMERA SLEEP
      // ==========================================================

      if (!cameraWasSleeping) {
        final cameraSleepWatch = Stopwatch()..start();

        await cameraState?.sleepCamera();

        cameraSleepWatch.stop();

        debugPrint(
          'REPORT CAMERA SLEEP TIME: '
          '${cameraSleepWatch.elapsedMilliseconds} ms',
        );
      }

      // ==========================================================
      // PREPARE
      // ==========================================================

      final prepareWatch = Stopwatch()..start();

      final imageFiles = List<MultipartFile>.generate(
        images.length,
        (index) => MultipartFile.fromBytes(
          images[index],
          filename: 'photo_${index + 1}.jpg',
          contentType: http.MediaType('image', 'jpeg'),
        ),
        growable: false,
      );

      final employeeName = _employeeName?.trim() ?? '';

      final accountCode = widget.accountCode.trim();

      final userCreate = employeeName.isEmpty
          ? accountCode
          : '${accountCode}_$employeeName';

      final bool isJapaneseUser = widget.lang.trim().toUpperCase() == 'JP';

      // ==========================================================
      // REPORT MAP
      // ==========================================================

      final reportMap = <String, dynamic>{
        'userCreate': userCreate,

        'qr_key': qrKey,

        'qr_scan_sts': qrKey.isNotEmpty ? 'SUCCESS_1st' : '',

        'type': widget.patrolGroup.name,

        'group': _selectedGroup?.trim() ?? '',

        'plant': plant,

        'division': division,

        'area': area,

        'machine': machine,

        'check': _needRecheck
            ? (area.isNotEmpty
                  ? ''.combinedViJa(context, 'needRecheck')
                  : ''.combinedViJa(context, 'needSelectArea'))
            : '',
      };

      // ==========================================================
      // COMMENT LANGUAGE
      // ==========================================================

      if (isJapaneseUser) {
        reportMap.addAll({
          'comment': '',

          'countermeasure': '',

          'comment_jp': latestComment,

          'countermeasure_jp': latestCounterMeasure,
        });
      } else {
        reportMap.addAll({
          'comment': latestComment,

          'countermeasure': latestCounterMeasure,

          'comment_jp': '',

          'countermeasure_jp': '',
        });
      }

      // ==========================================================
      // RISK DATA
      // ==========================================================

      if (isQA) {
        reportMap.addAll({
          'riskFreq': ''.combinedViJa(context, _qaFreq ?? ''),

          'riskProb': ''.combinedViJa(context, _qa5m ?? ''),

          'riskSev': ''.combinedViJa(context, _qaImpact ?? ''),

          'riskTotal': '',
        });
      } else if (isPatrol) {
        reportMap.addAll({
          'riskFreq': ''.combinedViJa(context, _freq!),

          'riskProb': ''.combinedViJa(context, _prob!),

          'riskSev': ''.combinedViJa(context, _sev!),

          'riskTotal': riskTotal,
        });
      } else {
        reportMap.addAll({
          'riskFreq': ''.combinedViJa(context, _freq ?? ''),

          'riskProb': ''.combinedViJa(context, _prob ?? ''),

          'riskSev': ''.combinedViJa(context, _sev ?? ''),

          'riskTotal': getScoreSymbol(),
        });
      }

      // ==========================================================
      // FORM DATA
      // ==========================================================

      final formData = FormData.fromMap({
        'report': jsonEncode(reportMap),

        'images': imageFiles,
      });

      prepareWatch.stop();

      final totalImageBytes = images.fold<int>(
        0,
        (sum, image) => sum + image.lengthInBytes,
      );

      debugPrint(
        'REPORT PREPARE TIME: '
        '${prepareWatch.elapsedMilliseconds} ms',
      );

      debugPrint(
        'REPORT IMAGE COUNT: '
        '${images.length}',
      );

      debugPrint(
        'REPORT IMAGE BYTES: '
        '$totalImageBytes',
      );

      debugPrint(
        'REPORT IMAGE SIZE MB: '
        '${(totalImageBytes / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      // ==========================================================
      // UPLOAD
      // ==========================================================

      final uploadWatch = Stopwatch()..start();

      final response = await DioClient.postUpload(
        '/api/report',
        data: formData,
      );

      uploadWatch.stop();

      debugPrint(
        'REPORT UPLOAD TIME: '
        '${uploadWatch.elapsedMilliseconds} ms',
      );

      hideLoading();

      if (!mounted) return;

      final statusCode = response.statusCode ?? 0;

      final serverResult = _parseServerResponse(response.data);

      debugPrint(
        'REPORT RESPONSE STATUS: '
        '$statusCode',
      );

      debugPrint(
        'REPORT RESPONSE CODE: '
        '${serverResult.code}',
      );

      debugPrint(
        'REPORT RESPONSE MESSAGE: '
        '${serverResult.message}',
      );

      // ==========================================================
      // SUCCESS
      // ==========================================================

      if (statusCode >= 200 && statusCode < 300) {
        CommonUI.showSnackBar(
          context: context,
          message: 'Successfully sent ${images.length} images!',
          color: Colors.green,
        );

        _resetForm();

        return;
      }

      // ==========================================================
      // SERVER ERROR
      // ==========================================================

      _showReportServerError(
        statusCode: statusCode,

        serverCode: serverResult.code,

        serverMessage: serverResult.message,

        qrKey: qrKey,
      );
    } on DioException catch (error, stackTrace) {
      hideLoading();

      if (!mounted) return;

      _handleReportDioError(error: error, qrKey: qrKey);
    } catch (error, stackTrace) {
      hideLoading();

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      CommonUI.showSnackBar(
        context: context,
        message: ApiErrorMessage.fromFlutter(error),
        color: Colors.red,
      );
    } finally {
      hideLoading();

      totalWatch.stop();

      // ==========================================================
      // CAMERA WAKE
      // ==========================================================

      if (!cameraWasSleeping && mounted) {
        final cameraWakeWatch = Stopwatch()..start();

        cameraWakeWatch.stop();
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  _ReportServerMessage _parseServerResponse(dynamic responseData) {
    if (responseData is Map) {
      return _ReportServerMessage(
        code: responseData['code']?.toString().trim(),
        message: responseData['message']?.toString().trim(),
      );
    }

    if (responseData is String && responseData.trim().isNotEmpty) {
      final raw = responseData.trim();

      try {
        final decoded = jsonDecode(raw);

        if (decoded is Map) {
          return _ReportServerMessage(
            code: decoded['code']?.toString().trim(),
            message: decoded['message']?.toString().trim(),
          );
        }
      } catch (_) {
        return _ReportServerMessage(message: raw);
      }

      return _ReportServerMessage(message: raw);
    }

    return const _ReportServerMessage();
  }

  void _showReportServerError({
    required int statusCode,
    required String? serverCode,
    required String? serverMessage,
    required String qrKey,
  }) {
    if (!mounted) return;

    final message = serverMessage?.trim() ?? '';

    if (statusCode == 409 || serverCode == 'DUPLICATE_QR') {
      CommonUI.showWarning(
        context: context,
        title: 'Duplicate QR Code',
        message: message.isNotEmpty
            ? message
            : 'QR code $qrKey already exists and has not been closed.',
      );
      return;
    }

    if (statusCode == 400 && serverCode == 'INVALID_QR') {
      CommonUI.showWarning(
        context: context,
        title: 'Invalid QR Code',
        message: message.isNotEmpty
            ? message
            : 'QR code must contain only numbers and have a maximum of 5 digits.',
      );
      return;
    }

    CommonUI.showSnackBar(
      context: context,
      message: message.isNotEmpty ? message : 'Unable to submit the report.',
      color: Colors.red,
    );
  }

  void _handleReportDioError({
    required DioException error,
    required String qrKey,
  }) {
    if (!mounted) return;

    final statusCode = error.response?.statusCode ?? 0;
    final serverResult = _parseServerResponse(error.response?.data);
    final serverCode = serverResult.code;
    final serverMessage = serverResult.message?.trim() ?? '';

    if (statusCode == 409 || serverCode == 'DUPLICATE_QR') {
      CommonUI.showWarning(
        context: context,
        title: 'Duplicate QR Code',
        message: serverMessage.isNotEmpty
            ? serverMessage
            : 'QR code $qrKey already exists and has not been closed.',
      );
      return;
    }

    if (statusCode == 400 && serverCode == 'INVALID_QR') {
      CommonUI.showWarning(
        context: context,
        title: 'Invalid QR Code',
        message: serverMessage.isNotEmpty
            ? serverMessage
            : 'QR code must contain only numbers and have a maximum of 5 digits.',
      );
      return;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        CommonUI.showWarning(
          context: context,
          title: 'Connection Timeout',
          message: 'The server took too long to connect. Please try again.',
        );
        return;

      case DioExceptionType.sendTimeout:
        CommonUI.showWarning(
          context: context,
          title: 'Upload Timeout',
          message:
              'The images took too long to upload. Please check the network and try again.',
        );
        return;

      case DioExceptionType.receiveTimeout:
        CommonUI.showWarning(
          context: context,
          title: 'Server Timeout',
          message:
              'The server is still processing the report. Please check the report before sending again.',
        );
        return;

      case DioExceptionType.connectionError:
        CommonUI.showWarning(
          context: context,
          title: 'Connection Error',
          message:
              'Unable to connect to the server. Please check the network connection.',
        );
        return;

      default:
        CommonUI.showSnackBar(
          context: context,
          message: serverMessage.isNotEmpty
              ? serverMessage
              : ApiErrorMessage.fromDio(error),
          color: Colors.red,
        );
    }
  }

}
