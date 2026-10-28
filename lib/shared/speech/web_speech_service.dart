import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Nhận dạng giọng nói bằng Web Speech API của trình duyệt
/// (window.SpeechRecognition || window.webkitSpeechRecognition).
///
/// Dùng truy cập JS động thay vì binding của package:web vì Chrome
/// chỉ có constructor tiền tố `webkit`.
///
/// Phiên nghe chỉ kết thúc khi gọi [stop] / [cancel] hoặc gặp lỗi thật;
/// trình duyệt tự ngắt (im lặng, hết phiên) thì service tự start lại.
class WebSpeechService {
  static final String? _ctorName = _detectCtor();

  static const _restartDelay = Duration(milliseconds: 250);

  /// Chờ onend tối đa sau khi gọi stop().
  static const _stopTimeout = Duration(seconds: 3);

  /// Trình duyệt có SpeechRecognition (hoặc bản webkit).
  static bool get isSupported => _ctorName != null;

  static String? _detectCtor() {
    try {
      if (globalContext.has('SpeechRecognition')) return 'SpeechRecognition';
      if (globalContext.has('webkitSpeechRecognition')) {
        return 'webkitSpeechRecognition';
      }
    } catch (_) {}
    return null;
  }

  /// currentLang của app (VI / EN / JA) → BCP-47 cho SpeechRecognition.
  static String localeOf(String lang) {
    switch (lang.trim().toUpperCase()) {
      case 'EN':
        return 'en-US';
      case 'JA':
      case 'JP':
        return 'ja-JP';
      default:
        return 'vi-VN';
    }
  }

  /// Đoạn đã chốt (final) trong lúc đang nghe.
  /// Đoạn chốt sau khi bấm Dừng được trả qua Future của [stop].
  void Function(String text)? onFinal;

  /// Đoạn tạm (interim) hiện tại; chuỗi rỗng = không còn interim.
  void Function(String text)? onInterim;

  /// Lỗi thật khiến phiên nghe dừng hẳn (đã map sang tiếng Việt).
  void Function(String message)? onError;

  /// Phiên nghe dừng hẳn do lỗi (không gọi khi [stop] / [cancel]).
  void Function()? onStopped;

  JSObject? _recognition;

  /// User vẫn đang nghe (chưa bấm Dừng).
  bool _wantListening = false;

  /// Recognition đang chạy (giữa start() và onend).
  bool _active = false;

  Timer? _restartTimer;
  Timer? _stopTimer;

  /// Interim mới nhất chưa được chốt.
  String _interim = '';

  /// Khác null trong lúc chờ onend sau khi gọi [stop].
  Completer<String>? _stopCompleter;
  final List<String> _tail = <String>[];

  bool get isListening => _wantListening;

  void start(String lang) {
    final ctorName = _ctorName;
    if (ctorName == null) {
      onError?.call('Trình duyệt không hỗ trợ nhận dạng giọng nói.');
      onStopped?.call();
      return;
    }
    if (_wantListening || _stopCompleter != null) return;

    _detach(abort: true);

    final ctor = globalContext[ctorName] as JSFunction;
    final rec = ctor.callAsConstructor<JSObject>();
    rec['lang'] = localeOf(lang).toJS;
    rec['continuous'] = true.toJS;
    rec['interimResults'] = true.toJS;
    rec['onresult'] = ((JSObject e) => _handleResult(e)).toJS;
    rec['onerror'] = ((JSObject e) => _handleError(e)).toJS;
    rec['onend'] = ((JSObject _) => _handleEnd()).toJS;

    _recognition = rec;
    _wantListening = true;
    _interim = '';

    if (!_startRecognition()) {
      _fail('Không thể bắt đầu nhận dạng giọng nói.');
    }
  }

  /// User bấm Dừng: chờ onend để nhận nốt kết quả final cuối.
  /// Future trả về phần text còn lại cần chèn (final sau khi dừng,
  /// hoặc interim chưa kịp final).
  Future<String> stop() {
    final pending = _stopCompleter;
    if (pending != null) return pending.future;
    if (!_wantListening) return Future<String>.value('');

    _wantListening = false;
    _restartTimer?.cancel();
    onInterim?.call('');

    final completer = _stopCompleter = Completer<String>();
    _tail.clear();

    final rec = _recognition;
    if (!_active || rec == null) {
      // Đang nằm giữa onend và lần start lại.
      _finishStop();
    } else {
      try {
        rec.callMethod<JSAny?>('stop'.toJS);
        _stopTimer = Timer(_stopTimeout, _finishStop);
      } catch (_) {
        _finishStop();
      }
    }

    return completer.future;
  }

  /// Dừng ngay, bỏ mọi kết quả còn lại (rời màn / ô bị khóa).
  void cancel() {
    _wantListening = false;
    _restartTimer?.cancel();
    _stopTimer?.cancel();
    _interim = '';
    _tail.clear();
    _detach(abort: true);

    final completer = _stopCompleter;
    _stopCompleter = null;
    completer?.complete('');
  }

  void dispose() {
    onFinal = null;
    onInterim = null;
    onError = null;
    onStopped = null;
    cancel();
  }

  /// true nếu đã start hoặc recognition vốn đang chạy (InvalidStateError).
  bool _startRecognition() {
    final rec = _recognition;
    if (rec == null) return false;
    try {
      rec.callMethod<JSAny?>('start'.toJS);
      _active = true;
      return true;
    } catch (e) {
      if (e.toString().contains('InvalidStateError')) {
        _active = true;
        return true;
      }
      return false;
    }
  }

  void _finishStop() {
    final completer = _stopCompleter;
    if (completer == null) return;
    _stopCompleter = null;
    _stopTimer?.cancel();

    final leftover = _interim.trim();
    if (leftover.isNotEmpty) _tail.add(leftover);
    _interim = '';

    final text = _tail.join(' ').trim();
    _tail.clear();

    _detach(abort: true);
    completer.complete(text);
  }

  /// Lỗi thật: dừng hẳn, bỏ interim.
  void _fail(String message) {
    _wantListening = false;
    _restartTimer?.cancel();
    _interim = '';
    _detach(abort: true);
    onInterim?.call('');
    onError?.call(message);
    onStopped?.call();
  }

  void _detach({required bool abort}) {
    final rec = _recognition;
    _active = false;
    if (rec == null) return;
    rec['onresult'] = null;
    rec['onerror'] = null;
    rec['onend'] = null;
    if (abort) {
      try {
        rec.callMethod<JSAny?>('abort'.toJS);
      } catch (_) {}
    }
    _recognition = null;
  }

  void _handleResult(JSObject event) {
    final resultIndex = (event['resultIndex'] as JSNumber).toDartInt;
    final results = event['results'] as JSObject;
    final length = (results['length'] as JSNumber).toDartInt;

    final finalText = StringBuffer();
    final interimText = StringBuffer();

    for (var i = resultIndex; i < length; i++) {
      final result = results.callMethod<JSObject>('item'.toJS, i.toJS);
      final alternative = result.callMethod<JSObject>('item'.toJS, 0.toJS);
      final transcript = (alternative['transcript'] as JSString).toDart;
      final isFinal = (result['isFinal'] as JSBoolean).toDart;

      (isFinal ? finalText : interimText).write(transcript);
    }

    final committed = finalText.toString().trim();
    _interim = interimText.toString().trim();

    if (_stopCompleter != null) {
      if (committed.isNotEmpty) _tail.add(committed);
      return;
    }
    if (!_wantListening) return;

    if (committed.isNotEmpty) onFinal?.call(committed);
    onInterim?.call(_interim);
  }

  void _handleError(JSObject event) {
    final code = (event['error'] as JSString?)?.toDart ?? '';

    switch (code) {
      case 'no-speech':
      case 'aborted':
        // Không phải lỗi thật: onend sẽ start lại nếu user chưa bấm Dừng.
        return;
    }

    if (_stopCompleter != null) {
      _finishStop();
      return;
    }

    final String message;
    switch (code) {
      case 'not-allowed':
        message =
            'Chưa được cấp quyền micro. Vui lòng cho phép micro trong trình duyệt.';
      case 'service-not-allowed':
        message = 'Trình duyệt không cho phép dùng dịch vụ nhận dạng giọng nói.';
      case 'audio-capture':
        message = 'Không tìm thấy micro hoặc micro đang bị ứng dụng khác dùng.';
      case 'network':
        message = 'Lỗi mạng: nhận dạng giọng nói cần kết nối Internet.';
      default:
        message = 'Lỗi nhận dạng giọng nói ($code).';
    }
    _fail(message);
  }

  void _handleEnd() {
    _active = false;

    if (_stopCompleter != null) {
      _finishStop();
      return;
    }

    if (!_wantListening) {
      _detach(abort: false);
      return;
    }

    // Trình duyệt tự ngắt khi user chưa bấm Dừng: giữ interim dở dang
    // (sẽ mất khi phiên mới bắt đầu) rồi start lại.
    final leftover = _interim.trim();
    _interim = '';
    if (leftover.isNotEmpty) {
      onFinal?.call(leftover);
      onInterim?.call('');
    }

    _restartTimer?.cancel();
    _restartTimer = Timer(_restartDelay, () {
      if (!_wantListening || _active) return;
      if (!_startRecognition()) {
        _fail('Không thể tiếp tục nhận dạng giọng nói.');
      }
    });
  }
}
