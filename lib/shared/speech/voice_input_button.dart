import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:chuphinh/core/api/speech_api.dart';
import 'package:chuphinh/shared/speech/web_audio_recorder.dart';
import 'package:chuphinh/shared/speech/web_speech_service.dart';
import 'package:chuphinh/shared/widgets/common_ui_helper.dart';

/// true  = Web Speech API của trình duyệt (nhận dạng trực tiếp, có interim).
/// false = ghi âm MediaRecorder rồi gửi /api/speech/transcribe.
const bool kUseWebSpeech = true;

/// Nút mic nhập giọng nói cho một TextField; text được chèn tại vị trí
/// con trỏ của [controller].
///
/// Gắn vào ô bất kỳ:
/// `suffixIcon: VoiceInputButton.suffixIcon(controller: c, lang: lang, plant: plant)`
class VoiceInputButton extends StatefulWidget {
  final TextEditingController controller;

  /// currentLang của app (VI / EN / JA).
  final String lang;

  /// Chỉ dùng cho engine ghi âm + API.
  final String? plant;
  final bool enabled;

  /// Giới hạn thời gian của engine ghi âm + API.
  final Duration maxDuration;

  /// Gọi sau khi chèn text (controller đổi bằng code không kích hoạt onChanged).
  final ValueChanged<String>? onTextInserted;

  const VoiceInputButton({
    super.key,
    required this.controller,
    required this.lang,
    this.plant,
    this.enabled = true,
    this.maxDuration = const Duration(seconds: 60),
    this.onTextInserted,
  });

  static bool get isSupported => kUseWebSpeech
      ? WebSpeechService.isSupported
      : WebAudioRecorder.isSupported;

  /// Trả về null khi trình duyệt không hỗ trợ (ẩn hẳn suffixIcon).
  static Widget? suffixIcon({
    required TextEditingController controller,
    required String lang,
    String? plant,
    bool enabled = true,
    ValueChanged<String>? onTextInserted,
  }) {
    if (!isSupported) return null;
    return VoiceInputButton(
      controller: controller,
      lang: lang,
      plant: plant,
      enabled: enabled,
      onTextInserted: onTextInserted,
    );
  }

  @override
  // ignore: no_logic_in_create_state
  State<VoiceInputButton> createState() =>
      kUseWebSpeech ? _WebSpeechVoiceState() : _RecorderVoiceState();
}

/// Chèn [transcript] tại vị trí con trỏ, tự thêm khoảng trắng hai bên khi cần.
String _insertAtCursor(TextEditingController controller, String transcript) {
  final value = controller.value;
  final text = value.text;

  var start = value.selection.start;
  var end = value.selection.end;
  if (start < 0 || end < 0 || start > text.length || end > text.length) {
    start = end = text.length;
  }

  final before = text.substring(0, start);
  final after = text.substring(end);

  var insert = transcript.trim();
  if (before.isNotEmpty && !RegExp(r'\s$').hasMatch(before)) {
    insert = ' $insert';
  }
  if (after.isNotEmpty && !RegExp(r'^\s').hasMatch(after)) {
    insert = '$insert ';
  }

  final newText = '$before$insert$after';
  controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: before.length + insert.length),
  );
  return newText;
}

void _showVoiceError(BuildContext context, String message) {
  CommonUI.showSnackBar(
    context: context,
    message: message,
    color: Colors.redAccent,
  );
}

// ===========================================================================
// Engine 1: Web Speech API
// ===========================================================================

enum _SpeechState { idle, listening, stopping }

class _WebSpeechVoiceState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  /// Giới hạn an toàn: tự dừng sau 5 phút.
  static const _maxListenSeconds = 5 * 60;

  final WebSpeechService _speech = WebSpeechService();
  final OverlayPortalController _interimOverlay = OverlayPortalController();
  final LayerLink _link = LayerLink();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  _SpeechState _state = _SpeechState.idle;
  String _interim = '';
  int _elapsed = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _speech
      ..onFinal = _onFinal
      ..onInterim = _onInterim
      ..onError = (message) {
        if (mounted) _showVoiceError(context, message);
      }
      ..onStopped = () {
        if (mounted) setState(_resetToIdle);
      };
  }

  @override
  void didUpdateWidget(covariant VoiceInputButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ô bị khóa → dừng, không chèn thêm.
    // didUpdateWidget chạy ngay trước build nên gán state trực tiếp.
    if (!widget.enabled && _state != _SpeechState.idle) {
      _speech.cancel();
      _resetToIdle();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _speech.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _toggle() {
    switch (_state) {
      case _SpeechState.idle:
        _start();
      case _SpeechState.listening:
        _stop();
      case _SpeechState.stopping:
        return;
    }
  }

  void _start() {
    setState(() {
      _state = _SpeechState.listening;
      _interim = '';
      _elapsed = 0;
    });
    _pulse.repeat(reverse: true);

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _state != _SpeechState.listening) return;
      setState(() => _elapsed++);
      if (_elapsed >= _maxListenSeconds) _stop();
    });

    // Có thể gọi onStopped đồng bộ nếu start lỗi ngay.
    _speech.start(widget.lang);
  }

  Future<void> _stop() async {
    if (_state != _SpeechState.listening) return;

    _ticker?.cancel();
    _pulse
      ..stop()
      ..reset();
    _interimOverlay.hide();
    setState(() {
      _state = _SpeechState.stopping;
      _interim = '';
    });

    final rest = await _speech.stop();

    // Bị cancel (rời màn / ô bị khóa) trong lúc chờ → không chèn.
    if (!mounted || _state != _SpeechState.stopping) return;

    if (rest.isNotEmpty) _onFinal(rest);
    setState(_resetToIdle);
  }

  void _resetToIdle() {
    _ticker?.cancel();
    _pulse
      ..stop()
      ..reset();
    _interimOverlay.hide();
    _state = _SpeechState.idle;
    _interim = '';
    _elapsed = 0;
  }

  static String _formatElapsed(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _onFinal(String text) {
    if (!mounted) return;
    final newText = _insertAtCursor(widget.controller, text);
    widget.onTextInserted?.call(newText);
  }

  void _onInterim(String text) {
    if (!mounted || _state != _SpeechState.listening) return;
    setState(() => _interim = text);
    if (text.isEmpty) {
      _interimOverlay.hide();
    } else {
      _interimOverlay.show();
    }
  }

  /// RenderBox của TextField chứa nút này (để đặt interim ngay dưới ô).
  RenderBox? _fieldBox() {
    RenderBox? box;
    context.visitAncestorElements((element) {
      if (element.widget is TextField) {
        final ro = element.renderObject;
        if (ro is RenderBox && ro.hasSize) box = ro;
        return false;
      }
      return true;
    });
    return box;
  }

  Widget _buildInterim(BuildContext overlayContext) {
    final buttonBox = context.findRenderObject();
    final fieldBox = _fieldBox();
    if (_interim.isEmpty ||
        buttonBox is! RenderBox ||
        !buttonBox.hasSize ||
        fieldBox == null) {
      return const SizedBox.shrink();
    }

    // Offset tương đối giữa nút và ô → không lệch khi cuộn màn.
    final offset =
        fieldBox.localToGlobal(Offset.zero) -
        buttonBox.localToGlobal(Offset.zero) +
        Offset(4, fieldBox.size.height + 2);

    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          width: fieldBox.size.width - 8,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            offset: offset,
            child: IgnorePointer(
              child: Material(
                type: MaterialType.transparency,
                child: Text(
                  _interim,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget button;
    switch (_state) {
      case _SpeechState.listening:
        button = Tooltip(
          message: 'Dừng',
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      final t = _pulse.value;
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(
                                .45 * (1 - t),
                              ),
                              blurRadius: 4 + 8 * t,
                              spreadRadius: 1 + 4 * t,
                            ),
                          ],
                        ),
                        child: Transform.scale(
                          scale: 1 + .12 * t,
                          child: child,
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.stop_rounded,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatElapsed(_elapsed),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case _SpeechState.stopping:
        button = const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white70,
            ),
          ),
        );

      case _SpeechState.idle:
        button = IconButton(
          tooltip: 'Nhập bằng giọng nói',
          icon: const Icon(Icons.mic_rounded),
          color: Colors.white70,
          disabledColor: Colors.white24,
          onPressed: widget.enabled ? _toggle : null,
        );
    }

    return OverlayPortal(
      controller: _interimOverlay,
      overlayChildBuilder: _buildInterim,
      child: CompositedTransformTarget(link: _link, child: button),
    );
  }
}

// ===========================================================================
// Engine 2: MediaRecorder + /api/speech/transcribe
// ===========================================================================

enum _RecorderState { idle, starting, recording, transcribing }

class _RecorderVoiceState extends State<VoiceInputButton> {
  final WebAudioRecorder _recorder = WebAudioRecorder();

  _RecorderState _state = _RecorderState.idle;
  int _elapsed = 0;
  Timer? _ticker;
  CancelToken? _cancelToken;

  @override
  void didUpdateWidget(covariant VoiceInputButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ô bị khóa (vd đang gửi report) → hủy phiên ghi đang chạy.
    // didUpdateWidget chạy ngay trước build nên gán state trực tiếp.
    if (!widget.enabled && _state == _RecorderState.recording) {
      _ticker?.cancel();
      _recorder.cancel();
      _state = _RecorderState.idle;
      _elapsed = 0;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    switch (_state) {
      case _RecorderState.idle:
        await _start();
      case _RecorderState.recording:
        await _stopAndTranscribe();
      case _RecorderState.starting:
      case _RecorderState.transcribing:
        return;
    }
  }

  Future<void> _start() async {
    setState(() => _state = _RecorderState.starting);

    try {
      final started = await _recorder.start();
      if (!mounted) return;
      if (!started) {
        setState(() => _state = _RecorderState.idle);
        return;
      }
    } on AudioRecorderException catch (e) {
      if (!mounted) return;
      setState(() => _state = _RecorderState.idle);
      _showVoiceError(context, e.message);
      return;
    }

    setState(() {
      _state = _RecorderState.recording;
      _elapsed = 0;
    });

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= widget.maxDuration.inSeconds) {
        _stopAndTranscribe();
      }
    });
  }

  Future<void> _stopAndTranscribe() async {
    if (_state != _RecorderState.recording) return;

    _ticker?.cancel();
    setState(() => _state = _RecorderState.transcribing);

    try {
      final audio = await _recorder.stop();
      if (!mounted) return;

      if (audio == null) {
        _showVoiceError(context, 'Không thu được âm thanh. Vui lòng thử lại.');
        return;
      }

      final token = _cancelToken = CancelToken();
      final text = await SpeechApi.transcribe(
        audio: audio.bytes,
        mimeType: audio.mimeType,
        lang: widget.lang,
        plant: widget.plant,
        cancelToken: token,
      );
      if (!mounted) return;

      final newText = _insertAtCursor(widget.controller, text);
      widget.onTextInserted?.call(newText);
    } on SpeechTranscribeException catch (e) {
      if (mounted) _showVoiceError(context, e.message);
    } on DioException catch (e) {
      if (mounted && !CancelToken.isCancel(e)) {
        _showVoiceError(context, 'Không thể chuyển giọng nói thành văn bản.');
      }
    } catch (_) {
      if (mounted) {
        _showVoiceError(context, 'Không thể chuyển giọng nói thành văn bản.');
      }
    } finally {
      _cancelToken = null;
      if (mounted) {
        setState(() {
          _state = _RecorderState.idle;
          _elapsed = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _RecorderState.transcribing:
        return const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white70,
            ),
          ),
        );

      case _RecorderState.recording:
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stop_circle_rounded, color: Colors.redAccent),
                const SizedBox(width: 4),
                Text(
                  '${_elapsed}s',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );

      case _RecorderState.idle:
      case _RecorderState.starting:
        final canTap = widget.enabled && _state == _RecorderState.idle;
        return IconButton(
          tooltip: 'Nhập bằng giọng nói',
          icon: const Icon(Icons.mic_rounded),
          color: Colors.white70,
          disabledColor: Colors.white24,
          onPressed: canTap ? _toggle : null,
        );
    }
  }
}
