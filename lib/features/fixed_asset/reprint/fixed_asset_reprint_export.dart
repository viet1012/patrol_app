import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:chuphinh/features/fixed_asset/reprint/fixed_asset_reprint_controller.dart';

/// Dữ liệu một tem QR (PNG / PDF). Chỉ tạo từ item [FixedAssetReprintItem
/// .isReady], nên [qrContent] luôn parse lại đúng vị trí mới.
class FixedAssetQrLabel {
  final String machineCode;
  final String faName;
  final String location;
  final String qrContent;

  /// Xưởng (rỗng = chưa rõ): tem PDF in thêm một dòng nhỏ.
  final String fac;

  const FixedAssetQrLabel({
    required this.machineCode,
    required this.faName,
    required this.location,
    required this.qrContent,
    this.fac = '',
  });

  factory FixedAssetQrLabel.of(FixedAssetReprintItem item) {
    return FixedAssetQrLabel(
      machineCode: item.machineCode,
      faName: item.row.faName,
      location: item.newLocationLabel,
      qrContent: item.qrContent,
      fac: item.fac,
    );
  }

  String get pngFileName => 'QR_${_safeFileName(machineCode)}.png';
}

String _safeFileName(String value) =>
    value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

// ============================================================
// PNG (tem: QR + mã máy + vị trí, nền trắng)
// ============================================================

/// QR 640 px (>= 600 px để in), viền trắng an toàn 64 px.
Future<Uint8List> renderFixedAssetQrPng(FixedAssetQrLabel label) async {
  const qrSize = 640.0;
  const pad = 64.0;
  const width = qrSize + pad * 2;

  // Đúng chuỗi đã mã hóa trong QR; dài thì xuống dòng (không cắt "…").
  final content = TextPainter(
    text: TextSpan(
      text: label.qrContent,
      style: const TextStyle(
        color: Color(0xFF000000),
        fontSize: 36,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: width - pad);
  final height = pad + qrSize + 24 + content.height + pad;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height),
    Paint()..color = const Color(0xFFFFFFFF),
  );

  canvas.save();
  canvas.translate(pad, pad);
  QrPainter(
    data: label.qrContent,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
    gapless: true,
  ).paint(canvas, const Size.square(qrSize));
  canvas.restore();

  content.paint(
    canvas,
    Offset((width - content.width) / 2, pad + qrSize + 24),
  );

  final image = await recorder.endRecording().toImage(
    width.ceil(),
    height.ceil(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) throw StateError('PNG encode failed');
  return data.buffer.asUint8List();
}

/// Tải từng file PNG (chưa có package zip): mỗi file cách nhau một nhịp để
/// trình duyệt không chặn tải nhiều file.
Future<void> downloadFixedAssetQrPngs(List<FixedAssetQrLabel> labels) async {
  for (var i = 0; i < labels.length; i++) {
    final bytes = await renderFixedAssetQrPng(labels[i]);
    _downloadBytes(bytes, labels[i].pngFileName, 'image/png');
    if (i < labels.length - 1) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
  }
}

void _downloadBytes(Uint8List bytes, String fileName, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  // Revoke sau một nhịp: một số trình duyệt cần URL còn sống khi bắt đầu tải.
  Timer(const Duration(seconds: 2), () => html.Url.revokeObjectUrl(url));
}

// ============================================================
// PDF A4 (lưới tem 3 x 6, đường cắt mờ) + hộp thoại in
// ============================================================

const int _pdfColumns = 3;
const int _pdfRows = 6;

Future<Uint8List> buildFixedAssetQrPdf(List<FixedAssetQrLabel> labels) async {
  final font = await _loadPdfFont();
  final doc = pw.Document(
    theme: font == null ? null : pw.ThemeData.withFont(base: font, bold: font),
  );

  const perPage = _pdfColumns * _pdfRows;
  const margin = 10 * PdfPageFormat.mm;
  final cellHeight = (PdfPageFormat.a4.height - margin * 2) / _pdfRows;

  for (var start = 0; start < labels.length; start += perPage) {
    final page = labels.sublist(
      start,
      (start + perPage).clamp(0, labels.length),
    );
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(margin),
        build: (_) => pw.Column(
          children: [
            for (var r = 0; r * _pdfColumns < page.length; r++)
              pw.Row(
                children: [
                  for (var c = 0; c < _pdfColumns; c++)
                    pw.Expanded(
                      child: r * _pdfColumns + c < page.length
                          ? _pdfLabel(page[r * _pdfColumns + c], cellHeight)
                          : pw.SizedBox(height: cellHeight),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
  return doc.save();
}

pw.Widget _pdfLabel(FixedAssetQrLabel label, double height) {
  const mm = PdfPageFormat.mm;
  return pw.Container(
    height: height,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(
        color: PdfColors.grey400,
        width: .4,
        style: pw.BorderStyle.dashed,
      ),
    ),
    child: pw.Row(
      children: [
        // Viền trắng an toàn quanh QR (>= 4 module).
        pw.Padding(
          padding: const pw.EdgeInsets.all(4 * mm),
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(
              errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium,
            ),
            data: label.qrContent,
            width: 30 * mm,
            height: 30 * mm,
          ),
        ),
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(right: 2 * mm),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Đúng chuỗi đã mã hóa trong QR; cột chữ ~25 mm nên tự
                // xuống dòng (không cắt).
                pw.Text(
                  label.qrContent,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (label.faName.isNotEmpty) ...[
                  pw.SizedBox(height: 1 * mm),
                  pw.Text(
                    _truncate(label.faName, 24),
                    maxLines: 1,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
                if (label.fac.isNotEmpty) ...[
                  pw.SizedBox(height: 1 * mm),
                  pw.Text(
                    label.fac,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

String _truncate(String value, int max) =>
    value.length <= max ? value : '${value.substring(0, max - 1)}…';

/// Roboto của app (có dấu tiếng Việt); lỗi thì dùng font mặc định của pdf.
Future<pw.Font?> _loadPdfFont() async {
  try {
    final data = await rootBundle.load(
      'assets/fonts/Roboto/Roboto-VariableFont_wdth.ttf',
    );
    return pw.Font.ttf(data);
  } catch (_) {
    return null;
  }
}

/// Mở hộp thoại in của trình duyệt.
Future<void> printFixedAssetQrLabels(List<FixedAssetQrLabel> labels) async {
  final bytes = await buildFixedAssetQrPdf(labels);
  await Printing.layoutPdf(
    name: labels.length == 1
        ? 'QR_${_safeFileName(labels.single.machineCode)}'
        : 'QR_reprint_${labels.length}',
    onLayout: (_) async => bytes,
  );
}
