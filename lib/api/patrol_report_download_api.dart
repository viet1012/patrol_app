import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../model/patrol_export_query.dart';

class PatrolReportDownloadService {
  final Dio dio;
  final String baseUrl;

  PatrolReportDownloadService({required this.dio, required this.baseUrl});

  Future<void> downloadExportExcel({
    required PatrolExportQuery query,
    String? fileName,
    void Function(int received, int total)? onProgress,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/patrol-reports/export-excel',
    ).replace(queryParameters: query.toQueryParams());
    debugPrint('Export Excel URL: ${uri.toString()}');
    debugPrint('Export Excel params: ${uri.queryParameters}');
    late Uint8List bytes;

    if (kIsWeb) {
      // ✅ WEB: dùng XHR có progress thật
      bytes = await _downloadWithProgressWeb(uri, onProgress: onProgress);
    } else {
      // 📱 Mobile / Desktop: dùng Dio
      final res = await dio.getUri(
        uri,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 10),
        ),
        onReceiveProgress: onProgress,
      );
      bytes = Uint8List.fromList(res.data as List<int>);
    }

    final finalName = fileName ?? 'patrol_reports.xlsx';
    _downloadBytesWeb(bytes, finalName);
  }

  // ================= WEB SAVE =================
  void _downloadBytesWeb(Uint8List bytes, String fileName) {
    final blob = html.Blob([
      bytes,
    ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';

    html.document.body!.append(anchor);
    anchor.click();
    anchor.remove();

    html.Url.revokeObjectUrl(url);
  }

  // ===== XHR helper =====
  Future<Uint8List> _downloadWithProgressWeb(
    Uri uri, {
    void Function(int received, int total)? onProgress,
  }) {
    final completer = Completer<Uint8List>();
    final req = html.HttpRequest();

    req
      ..open('GET', uri.toString())
      ..responseType = 'arraybuffer';

    req.onProgress.listen((e) {
      final r = e.loaded?.toInt() ?? 0;
      final t = e.total?.toInt() ?? -1;
      onProgress?.call(r, t);
    });

    req.onLoad.listen((_) {
      if (req.status == 200) {
        completer.complete(Uint8List.view(req.response as ByteBuffer));
      } else {
        completer.completeError('HTTP ${req.status}');
      }
    });

    req.onError.listen((_) {
      completer.completeError('Network error');
    });

    req.send();
    return completer.future;
  }
}
