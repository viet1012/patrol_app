library qr_web;

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as djs;

import 'package:js/js.dart' as pjs;

@pjs.JS('startDecodeQrFromCanvas')
external void _startDecodeQrFromCanvas(html.CanvasElement canvas, String token);

@pjs.JS('jsQR')
external dynamic _jsQR(dynamic data, int width, int height, [dynamic options]);

Future<String?> pickImageAndDecodeQr({
  int maxSide = 2600,
  bool cropCenter = false,
}) async {
  void log(Object msg) => print('[QR] $msg');

  html.CanvasElement _drawRegion(
    html.ImageElement img, {
    required int sx,
    required int sy,
    required int sw,
    required int sh,
    required int outW,
    required int outH,
  }) {
    final canvas = html.CanvasElement(width: outW, height: outH);
    final ctx = canvas.context2D;
    ctx.imageSmoothingEnabled = false;
    ctx.drawImageScaledFromSource(img, sx, sy, sw, sh, 0, 0, outW, outH);
    return canvas;
  }

  Future<String?> _decodeByZxingViaEvent(html.CanvasElement canvas) async {
    // nếu JS wrapper chưa có thì thôi
    if (djs.context['startDecodeQrFromCanvas'] == null) return null;

    final token = DateTime.now().microsecondsSinceEpoch.toString();

    final completer = Completer<String?>();
    late StreamSubscription sub;

    sub = html.window.on['qr-decoded'].listen((event) {
      final e = event as html.CustomEvent;
      final detail = e.detail; // JS object {token,text}
      if (detail == null) return;

      // đọc token/text an toàn
      final tok = (detail['token'])?.toString();
      if (tok != token) return;

      final text = (detail['text'])?.toString().trim();
      sub.cancel();
      completer.complete((text == null || text.isEmpty) ? null : text);
    });

    _startDecodeQrFromCanvas(canvas, token);

    try {
      return await completer.future.timeout(const Duration(seconds: 2));
    } catch (_) {
      await sub.cancel();
      return null;
    }
  }

  String? _decodeByJsQr(html.CanvasElement canvas) {
    if (djs.context['jsQR'] == null) return null;

    final ctx = canvas.context2D;
    final w = canvas.width ?? 0;
    final h = canvas.height ?? 0;
    if (w <= 0 || h <= 0) return null;

    // preprocess: adaptive-ish threshold đơn giản
    final imgData = ctx.getImageData(0, 0, w, h);
    final p = imgData.data;
    for (int i = 0; i < p.length; i += 4) {
      final r = p[i], g = p[i + 1], b = p[i + 2];
      final lum = (0.299 * r + 0.587 * g + 0.114 * b).round();
      final v = lum < 170 ? 0 : 255; // tăng threshold cho giấy trắng
      p[i] = v;
      p[i + 1] = v;
      p[i + 2] = v;
    }
    ctx.putImageData(imgData, 0, 0);

    final pixels = ctx.getImageData(0, 0, w, h).data;
    final jsPixels = djs.JsObject(djs.context['Uint8ClampedArray'], [pixels]);
    final options = djs.JsObject.jsify({'inversionAttempts': 'attemptBoth'});
    final result = djs.context.callMethod('jsQR', [jsPixels, w, h, options]);
    if (result == null) return null;

    final qrObj = result as djs.JsObject;
    final text = qrObj['data']?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  // ---- main pick image ----
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;
  input.click();

  await input.onChange.first.timeout(
    const Duration(seconds: 30),
    onTimeout: () => throw StateError('User cancelled or picker timeout'),
  );

  final file = input.files?.first;
  if (file == null) return null;

  final reader = html.FileReader()..readAsDataUrl(file);
  await reader.onLoadEnd.first.timeout(const Duration(seconds: 30));
  final dataUrl = reader.result;
  if (dataUrl is! String) throw StateError('FileReader result is not String');

  final imgEl = html.ImageElement(src: dataUrl);
  await imgEl.onLoad.first.timeout(const Duration(seconds: 30));

  final iw = imgEl.naturalWidth ?? imgEl.width ?? 0;
  final ih = imgEl.naturalHeight ?? imgEl.height ?? 0;
  log('image size = $iw x $ih');
  if (iw <= 0 || ih <= 0) return null;

  // crops
  final crops = <Map<String, int>>[];
  void addCrop(int sx, int sy, int sw, int sh) {
    sx = sx.clamp(0, iw - 1);
    sy = sy.clamp(0, ih - 1);
    sw = sw.clamp(1, iw - sx);
    sh = sh.clamp(1, ih - sy);
    crops.add({'sx': sx, 'sy': sy, 'sw': sw, 'sh': sh});
  }

  addCrop(0, 0, iw, ih);
  if (cropCenter) {
    final side = iw < ih ? iw : ih;
    addCrop(((iw - side) / 2).round(), ((ih - side) / 2).round(), side, side);
  } else {
    final w70 = (iw * 0.7).round();
    final h70 = (ih * 0.7).round();
    addCrop(((iw - w70) / 2).round(), ((ih - h70) / 2).round(), w70, h70);
    addCrop(0, 0, w70, h70);
    addCrop(iw - w70, 0, w70, h70);
    addCrop(0, ih - h70, w70, h70);
    addCrop(iw - w70, ih - h70, w70, h70);
  }

  final scaleTargets = <int>[maxSide, 2200, 2000, 1600];

  for (final c in crops) {
    final sx = c['sx']!, sy = c['sy']!, sw = c['sw']!, sh = c['sh']!;
    for (final target in scaleTargets) {
      final maxCropSide = sw > sh ? sw : sh;
      final scale = maxCropSide > target ? (target / maxCropSide) : 1.0;
      final outW = (sw * scale).round().clamp(1, 10000);
      final outH = (sh * scale).round().clamp(1, 10000);

      final canvas = _drawRegion(
        imgEl,
        sx: sx,
        sy: sy,
        sw: sw,
        sh: sh,
        outW: outW,
        outH: outH,
      );

      final z = await _decodeByZxingViaEvent(canvas);
      if (z != null) {
        log('decoded (ZXing)="$z"');
        return z;
      }

      final j = _decodeByJsQr(canvas);
      if (j != null) {
        log('decoded (jsQR)="$j"');
        return j;
      }
    }
  }

  log('decode: null');
  return null;
}
