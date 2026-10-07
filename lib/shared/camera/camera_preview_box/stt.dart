part of '../camera_preview_box.dart';

/// Số thứ tự STT (API + WebSocket).
mixin _SttMixin on State<CameraPreviewBox> {
  // =========================
  // STT / Socket
  // =========================
  late String _fac;
  late String _group;
  late String _wsUrl;

  int stt = 0;
  bool _sttLoading = true;
  SttWebSocket? sttSocket;

  /// Badge "No. x": chỉ badge rebuild khi STT đổi.
  final ValueNotifier<_SttUi> _sttNotifier = ValueNotifier<_SttUi>(
    (value: 0, loading: true),
  );

  void _publishStt() {
    if (!mounted) return;
    _sttNotifier.value = (value: stt, loading: _sttLoading);
  }

  // =========================
  // STT / socket
  // =========================
  Future<void> _loadStt() async {
    if (_fac.isEmpty) return;
    try {
      _sttLoading = true;
      _publishStt();

      final value = await SttApi.getCurrentStt(
        fac: _fac,
        type: widget.patrolGroup.name,
      );

      if (!mounted) return;
      stt = value;
      _sttLoading = false;
      _publishStt();
    } catch (e) {
      if (mounted) {
        _sttLoading = false;
        _publishStt();
      }
    }
  }

  void _connectSocket() {
    sttSocket?.dispose();
    sttSocket = SttWebSocket(
      serverUrl: _wsUrl,
      fac: _fac,
      type: widget.patrolGroup.name,
      onSttUpdate: (value) {
        if (!mounted) return;
        stt = value;
        _sttLoading = false;
        _publishStt();
      },
    );
    sttSocket!.connect();
  }
}
