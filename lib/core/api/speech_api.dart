import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:chuphinh/core/network/dio_client.dart';

class SpeechTranscribeException implements Exception {
  final String message;

  const SpeechTranscribeException(this.message);

  @override
  String toString() => message;
}

class SpeechApi {
  static const _defaultError = 'Không thể chuyển giọng nói thành văn bản.';

  /// currentLang của app (VI / EN / JA) → mã ngôn ngữ của API.
  static String langCode(String lang) {
    switch (lang.trim().toUpperCase()) {
      case 'EN':
        return 'en';
      case 'JA':
      case 'JP':
        return 'ja';
      default:
        return 'vi';
    }
  }

  /// POST /api/speech/transcribe (multipart: audio, lang, plant).
  static Future<String> transcribe({
    required Uint8List audio,
    required String mimeType,
    required String lang,
    String? plant,
    CancelToken? cancelToken,
  }) async {
    final baseMime = mimeType.split(';').first.trim();

    final form = FormData.fromMap({
      'audio': MultipartFile.fromBytes(
        audio,
        filename: 'voice.webm',
        contentType: DioMediaType.parse(baseMime),
      ),
      'lang': langCode(lang),
      if (plant != null && plant.trim().isNotEmpty) 'plant': plant.trim(),
    });

    try {
      // Gọi thẳng dio (không qua _retry): FormData không gửi lại được.
      final res = await DioClient.dio.post(
        '/api/speech/transcribe',
        data: form,
        cancelToken: cancelToken,
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 90),
        ),
      );

      final data = _decode(res.data);

      if (res.statusCode != 200) {
        throw SpeechTranscribeException(_messageOf(data) ?? _defaultError);
      }

      final text = _textOf(data);
      if (text == null || text.trim().isEmpty) {
        throw const SpeechTranscribeException(
          'Không nhận diện được nội dung giọng nói.',
        );
      }
      return text.trim();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;

      final message = _messageOf(_decode(e.response?.data));
      if (message != null) throw SpeechTranscribeException(message);

      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.unknown:
          throw const SpeechTranscribeException(
            'Lỗi mạng. Vui lòng kiểm tra kết nối và thử lại.',
          );
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw const SpeechTranscribeException(
            'Máy chủ phản hồi quá lâu. Vui lòng thử lại.',
          );
        default:
          if (e.response?.statusCode == 503) {
            throw const SpeechTranscribeException(
              'Dịch vụ nhận dạng giọng nói tạm thời không khả dụng.',
            );
          }
          throw const SpeechTranscribeException(_defaultError);
      }
    }
  }

  static dynamic _decode(dynamic data) {
    if (data is String && data.trim().startsWith('{')) {
      try {
        return jsonDecode(data);
      } catch (_) {}
    }
    return data;
  }

  static String? _messageOf(dynamic data) {
    if (data is Map && data['message'] != null) {
      final msg = data['message'].toString().trim();
      if (msg.isNotEmpty) return msg;
    }
    return null;
  }

  static String? _textOf(dynamic data) {
    if (data is String) return data;
    if (data is Map) {
      final direct = data['text'] ?? data['transcript'];
      if (direct != null) return direct.toString();

      final inner = data['data'];
      if (inner is String) return inner;
      if (inner is Map && inner['text'] != null) {
        return inner['text'].toString();
      }
    }
    return null;
  }
}
