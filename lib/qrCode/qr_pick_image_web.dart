@JS()
library qr_web;

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

import 'package:js/js.dart';

Future<String?> pickImageAndDecodeQr({
  int maxSide = 2200, // tăng mặc định để giữ chi tiết ảnh chụp
  bool cropCenter = false, // vẫn giữ option cũ
  bool binarize = true, // ảnh chụp nên bật mặc định
}) async {
  void log(Object msg) => print('[QR] $msg');

  // helper: decode từ canvas hiện tại
  String? _decodeFromCanvas(html.CanvasElement canvas) {
    final ctx = canvas.context2D;
    final w = canvas.width ?? 0;
    final h = canvas.height ?? 0;
    if (w <= 0 || h <= 0) return null;

    final imageData = ctx.getImageData(0, 0, w, h);
    final pixels = imageData.data;

    // convert sang JS Uint8ClampedArray thật
    final jsPixels = js.JsObject(js.context['Uint8ClampedArray'], [pixels]);

    // jsQR options: thử cả normal + inverted
    final options = js.JsObject.jsify({'inversionAttempts': 'attemptBoth'});

    final result = js.context.callMethod('jsQR', [jsPixels, w, h, options]);
    if (result == null) return null;

    final qrObj = result as js.JsObject;
    final raw = qrObj['data'];
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  // helper: vẽ 1 vùng (sx,sy,sw,sh) lên canvas và thử decode
  String? _tryRegion({
    required html.ImageElement img,
    required int sx,
    required int sy,
    required int sw,
    required int sh,
    required int outW,
    required int outH,
    required bool doBinarize,
  }) {
    final canvas = html.CanvasElement(width: outW, height: outH);
    final ctx = canvas.context2D;

    // quan trọng: tắt smoothing để không blur ô QR
    ctx.imageSmoothingEnabled = false;

    ctx.drawImageScaledFromSource(img, sx, sy, sw, sh, 0, 0, outW, outH);

    if (doBinarize) {
      final imgData = ctx.getImageData(0, 0, outW, outH);
      final p = imgData.data;

      // binarize: tăng tương phản cho ảnh chụp
      for (int i = 0; i < p.length; i += 4) {
        final r = p[i];
        final g = p[i + 1];
        final b = p[i + 2];
        final lum = (0.299 * r + 0.587 * g + 0.114 * b).round();
        final v = lum < 160 ? 0 : 255; // threshold hơi cao chút cho giấy trắng
        p[i] = v;
        p[i + 1] = v;
        p[i + 2] = v;
      }
      ctx.putImageData(imgData, 0, 0);
    }

    return _decodeFromCanvas(canvas);
  }

  try {
    // 0) check jsQR đã load chưa
    if (js.context['jsQR'] == null) {
      throw StateError(
        'window.jsQR = null. Kiểm tra index.html load jsQR trước flutter_bootstrap.js.',
      );
    }

    // 1) pick image
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

    log('picked file: ${file.name}, size=${file.size}');

    // 2) read dataUrl
    final reader = html.FileReader()..readAsDataUrl(file);
    await reader.onLoadEnd.first.timeout(const Duration(seconds: 30));
    final dataUrl = reader.result;
    if (dataUrl is! String) throw StateError('FileReader result is not String');

    // 3) load image
    final imgEl = html.ImageElement(src: dataUrl);
    final loaded = Completer<void>();
    imgEl.onLoad.first.then((_) => loaded.complete());
    imgEl.onError.first.then(
      (_) => loaded.completeError(StateError('ImageElement load error')),
    );
    await loaded.future.timeout(const Duration(seconds: 30));

    final iw = imgEl.naturalWidth ?? imgEl.width ?? 0;
    final ih = imgEl.naturalHeight ?? imgEl.height ?? 0;
    log('image size = $iw x $ih');
    if (iw <= 0 || ih <= 0) return null;

    // 4) chuẩn bị các vùng crop để thử
    // - nếu cropCenter=true -> ưu tiên center square
    // - nếu không -> thử full + 4 góc + center (thường QR nằm đâu đó)
    final crops = <Map<String, int>>[];

    void addCrop(int sx, int sy, int sw, int sh) {
      // clamp để không out-of-range
      sx = sx.clamp(0, iw - 1);
      sy = sy.clamp(0, ih - 1);
      sw = sw.clamp(1, iw - sx);
      sh = sh.clamp(1, ih - sy);
      crops.add({'sx': sx, 'sy': sy, 'sw': sw, 'sh': sh});
    }

    // always try full
    addCrop(0, 0, iw, ih);

    // center square (nếu user muốn)
    if (cropCenter) {
      final side = iw < ih ? iw : ih;
      addCrop(((iw - side) / 2).round(), ((ih - side) / 2).round(), side, side);
    } else {
      // thử 5 vùng: center + 4 góc (mỗi vùng ~70% ảnh)
      final w70 = (iw * 0.70).round();
      final h70 = (ih * 0.70).round();
      addCrop(
        ((iw - w70) / 2).round(),
        ((ih - h70) / 2).round(),
        w70,
        h70,
      ); // center
      addCrop(0, 0, w70, h70); // TL
      addCrop(iw - w70, 0, w70, h70); // TR
      addCrop(0, ih - h70, w70, h70); // BL
      addCrop(iw - w70, ih - h70, w70, h70); // BR
    }

    // 5) thử decode theo nhiều scale + binarize/raw
    // scale set: giữ chi tiết hơn cho ảnh chụp
    final scaleTargets = <int>[maxSide, 1600, 1200];

    for (final c in crops) {
      final sx = c['sx']!;
      final sy = c['sy']!;
      final sw = c['sw']!;
      final sh = c['sh']!;

      for (final target in scaleTargets) {
        final maxCropSide = sw > sh ? sw : sh;
        double scale = 1.0;
        if (maxCropSide > target) scale = target / maxCropSide;

        final outW = (sw * scale).round().clamp(1, 10000);
        final outH = (sh * scale).round().clamp(1, 10000);

        // thử raw trước
        final rawText = _tryRegion(
          img: imgEl,
          sx: sx,
          sy: sy,
          sw: sw,
          sh: sh,
          outW: outW,
          outH: outH,
          doBinarize: false,
        );
        if (rawText != null) {
          log('decoded (raw)="$rawText"');
          return rawText;
        }

        // rồi thử binarize (ảnh chụp thường cần)
        if (binarize) {
          final binText = _tryRegion(
            img: imgEl,
            sx: sx,
            sy: sy,
            sw: sw,
            sh: sh,
            outW: outW,
            outH: outH,
            doBinarize: true,
          );
          if (binText != null) {
            log('decoded (binarize)="$binText"');
            return binText;
          }
        }
      }
    }

    log('decode: null');
    return null;
  } catch (e, st) {
    print('[QR][ERROR] $e');
    print(st);
    rethrow;
  }
}
