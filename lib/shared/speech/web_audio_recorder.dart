import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Kết quả một lần ghi âm.
class RecordedAudio {
  final Uint8List bytes;
  final String mimeType;

  const RecordedAudio({required this.bytes, required this.mimeType});
}

class AudioRecorderException implements Exception {
  final String message;

  const AudioRecorderException(this.message);

  @override
  String toString() => message;
}

/// Ghi âm micro bằng MediaRecorder của trình duyệt (audio/webm, opus).
/// Mỗi instance chỉ ghi một phiên tại một thời điểm.
class WebAudioRecorder {
  static const _preferredMime = 'audio/webm;codecs=opus';
  static const _fallbackMime = 'audio/webm';

  static final String? _supportedMime = _detectMime();

  /// Trình duyệt có MediaRecorder + getUserMedia và hỗ trợ audio/webm.
  static bool get isSupported => _supportedMime != null;

  static String? _detectMime() {
    try {
      if (!globalContext.has('MediaRecorder')) return null;
      if (!web.window.navigator.has('mediaDevices')) return null;
      if (web.MediaRecorder.isTypeSupported(_preferredMime)) {
        return _preferredMime;
      }
      if (web.MediaRecorder.isTypeSupported(_fallbackMime)) {
        return _fallbackMime;
      }
    } catch (_) {}
    return null;
  }

  web.MediaStream? _stream;
  web.MediaRecorder? _recorder;
  final List<web.Blob> _chunks = <web.Blob>[];

  /// Tăng mỗi lần start/cancel để bỏ kết quả getUserMedia đã lỗi thời
  /// (vd rời màn trong lúc trình duyệt đang hỏi quyền micro).
  int _session = 0;

  bool get isRecording => _recorder != null;

  /// Xin quyền micro và bắt đầu ghi.
  /// Trả về false nếu phiên bị [cancel] trong lúc chờ quyền.
  Future<bool> start() async {
    if (_recorder != null) return true;

    final mime = _supportedMime;
    if (mime == null) {
      throw const AudioRecorderException(
        'Trình duyệt không hỗ trợ ghi âm.',
      );
    }

    final session = ++_session;

    final web.MediaStream stream;
    try {
      stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;
    } catch (e) {
      throw AudioRecorderException(_permissionMessage(e));
    }

    if (session != _session) {
      _stopTracks(stream);
      return false;
    }

    _chunks.clear();
    final recorder = web.MediaRecorder(
      stream,
      web.MediaRecorderOptions(mimeType: mime),
    );
    recorder.ondataavailable = ((web.BlobEvent e) {
      if (e.data.size > 0) _chunks.add(e.data);
    }).toJS;

    try {
      recorder.start();
    } catch (e) {
      _stopTracks(stream);
      throw const AudioRecorderException('Không thể bắt đầu ghi âm.');
    }

    _stream = stream;
    _recorder = recorder;
    return true;
  }

  /// Dừng ghi và trả về audio. Null nếu không thu được dữ liệu.
  Future<RecordedAudio?> stop() async {
    final recorder = _recorder;
    if (recorder == null) return null;

    final done = Completer<void>();
    recorder.onstop = ((web.Event _) {
      if (!done.isCompleted) done.complete();
    }).toJS;

    if (recorder.state != 'inactive') {
      recorder.stop();
    } else {
      done.complete();
    }

    await done.future;
    _release();

    if (_chunks.isEmpty) return null;

    final mime = _supportedMime ?? _fallbackMime;
    final blob = web.Blob(
      <JSAny>[..._chunks].toJS,
      web.BlobPropertyBag(type: mime),
    );
    _chunks.clear();

    final buffer = await blob.arrayBuffer().toDart;
    final bytes = buffer.toDart.asUint8List();
    if (bytes.isEmpty) return null;

    return RecordedAudio(bytes: bytes, mimeType: mime);
  }

  /// Dừng ghi và bỏ dữ liệu (dùng khi rời màn).
  void cancel() {
    _session++;

    final recorder = _recorder;
    if (recorder != null) {
      recorder.ondataavailable = null;
      recorder.onstop = null;
      try {
        if (recorder.state != 'inactive') recorder.stop();
      } catch (_) {}
    }

    _release();
    _chunks.clear();
  }

  void _release() {
    final stream = _stream;
    if (stream != null) _stopTracks(stream);
    _stream = null;
    _recorder = null;
  }

  static void _stopTracks(web.MediaStream stream) {
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
  }

  static String _permissionMessage(Object e) {
    final raw = e.toString();
    if (raw.contains('NotAllowed') || raw.contains('Permission')) {
      return 'Chưa được cấp quyền micro. Vui lòng cho phép micro trong trình duyệt.';
    }
    if (raw.contains('NotFound')) {
      return 'Không tìm thấy micro trên thiết bị.';
    }
    if (raw.contains('NotReadable')) {
      return 'Micro đang được ứng dụng khác sử dụng.';
    }
    return 'Không thể truy cập micro.';
  }
}
