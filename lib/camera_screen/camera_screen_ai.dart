part of '../test.dart';

extension _CameraScreenAi on _CameraScreenState {
  Future<void> _translateAiSummaryToJp() async {
    final vi = _machineAiSummary?.summaryVi?.trim();

    if (vi == null || vi.isEmpty) return;
    if (_summaryJp != null && _summaryJp!.isNotEmpty) return;

    setState(() {
      _isTranslatingAi = true;
    });

    try {
      final response = await DioClient.post(
        '/api/patrol_report/translate-ai-summary',
        data: {'text': vi},
      );

      final data = response.data;

      if (!mounted) return;

      setState(() {
        _summaryJp = data['text']?.toString();
      });
    } catch (e) {
      debugPrint('Translate AI summary error: $e');
    } finally {
      if (!mounted) return;

      setState(() {
        _isTranslatingAi = false;
      });
    }
  }

  Future<void> _loadMachineAiSummary(
    String? machine, {
    bool force = false,
  }) async {
    final mac = machine?.trim();

    if (mac == null || mac.isEmpty) return;

    if (!force && _lastAiMachine == mac && _machineAiSummary != null) {
      return;
    }

    setState(() {
      _isLoadingMachineAi = true;
      _machineAiError = null;
      _machineAiSummary = null;
      _summaryJp = null;
      _lastAiMachine = mac;
    });
    try {
      final response = await DioClient.get(
        '/api/patrol_report/analyze-machine',
        queryParameters: {'machine': mac},
      );

      final data = response.data;

      if (!mounted) return;

      if (data is Map) {
        ;
        final summary = MachineAiSummary.fromJson(
          Map<String, dynamic>.from(data),
        );

        setState(() {
          _machineAiSummary = summary;
          _summaryJp = null;
        });

        if (widget.lang.toUpperCase() == 'JP') {
          await _translateAiSummaryToJp();
        }
      } else {
        setState(() {
          _machineAiError = 'Invalid AI response';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _machineAiError = 'Unable to load AI summary';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoadingMachineAi = false;
      });
    }
  }

}
