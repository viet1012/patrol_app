import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:chuphinh/features/fixed_asset/reprint/fixed_asset_reprint_controller.dart';

/// Dữ liệu một tem QR (PNG / PDF). Chỉ tạo từ item [FixedAssetReprintItem
/// .isReady], nên [qrContent] luôn parse lại đúng vị trí mới.
class FixedAssetQrLabel {
  final String machineCode;
  final String faName;
  final String location;
  final String qrContent;
  final String fac;

  /// Ngày tài sản (góc phải dưới, "Jan-2019"); null = để trống.
  final DateTime? assetDate;

  const FixedAssetQrLabel({
    required this.machineCode,
    required this.faName,
    required this.location,
    required this.qrContent,
    this.fac = '',
    this.assetDate,
  });

  factory FixedAssetQrLabel.of(FixedAssetReprintItem item) {
    return FixedAssetQrLabel(
      machineCode: item.machineCode,
      faName: item.row.faName,
      location: item.newLocationLabel,
      qrContent: item.qrContent,
      fac: item.fac,
      assetDate: item.row.assetDate,
    );
  }

  String get dateLabel {
    final date = assetDate;
    return date == null ? '' : DateFormat('MMM-yyyy', 'en_US').format(date);
  }

  String get pngFileName => 'QR_${_safeFileName(machineCode)}.png';
}

String _safeFileName(String value) =>
    value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

// ============================================================
// LAYOUT TEM (theo mẫu "Check Master Fixed Asset QR Code")
// ============================================================

const double _mm = PdfPageFormat.mm;
const double _labelW = 82 * _mm;
const double _labelH = 35 * _mm;
const double _gapX = 8 * _mm;
const double _gapY = 11 * _mm;
const double _qrColW = 28 * _mm;
const double _footerH = 5.5 * _mm;
const int _cols = 2;
const int _rows = 5;

const PdfColor _navy = PdfColor.fromInt(0xFF0B2A5B);
const PdfColor _peach = PdfColor.fromInt(0xFFFCE8DA);

class _LabelFonts {
  const _LabelFonts(this.bold, this.boldItalic, this.italic);
  final pw.Font bold;
  final pw.Font boldItalic;
  final pw.Font italic;
}

Future<_LabelFonts>? _fontsFuture;
Future<_LabelFonts> _labelFonts() => _fontsFuture ??= _loadLabelFonts();

/// Tinos (giống Times, có tiếng Việt); thiếu thì Roboto; cuối cùng Times
/// có sẵn của pdf (không dấu).
Future<_LabelFonts> _loadLabelFonts() async {
  Future<pw.Font?> load(String path) async {
    try {
      return pw.Font.ttf(await rootBundle.load(path));
    } catch (_) {
      return null;
    }
  }

  const dir = 'assets/fonts/Tinos';
  final bold = await load('$dir/Tinos-Bold.ttf');
  final boldItalic = await load('$dir/Tinos-BoldItalic.ttf');
  final italic = await load('$dir/Tinos-Italic.ttf');
  final roboto = await load('assets/fonts/Roboto/Roboto-VariableFont_wdth.ttf');
  return _LabelFonts(
    bold ?? roboto ?? pw.Font.timesBold(),
    boldItalic ?? roboto ?? pw.Font.timesBoldItalic(),
    italic ?? roboto ?? pw.Font.timesItalic(),
  );
}

pw.Widget _label(FixedAssetQrLabel label, _LabelFonts f) {
  const border = 1.2;
  return pw.Container(
    width: _labelW,
    height: _labelH,
    // Chừa đúng độ dày viền: nội dung (khối QR) không vẽ đè lên viền.
    padding: const pw.EdgeInsets.all(border),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.black, width: border),
    ),
    child: pw.Column(
      children: [
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Mã máy (to) + tên máy (đậm nghiêng, <= 3 dòng).
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(
                    1.5 * _mm,
                    0.5 * _mm,
                    1.5 * _mm,
                    0,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.FittedBox(
                        fit: pw.BoxFit.scaleDown,
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          label.machineCode,
                          style: pw.TextStyle(
                            font: f.bold,
                            fontSize: 28,
                            color: _navy,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Align(
                          alignment: pw.Alignment.centerLeft,
                          child: pw.Text(
                            label.faName,
                            maxLines: 3,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              font: f.boldItalic,
                              fontSize: 9.5,
                              color: _navy,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Khối peach + QR (nền trắng quanh QR để dễ quét).
              pw.Container(
                width: _qrColW,
                color: _peach,
                alignment: pw.Alignment.topCenter,
                padding: const pw.EdgeInsets.only(top: 1 * _mm),
                child: pw.Container(
                  color: PdfColors.white,
                  padding: const pw.EdgeInsets.all(1.2 * _mm),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(
                      errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium,
                    ),
                    data: label.qrContent,
                    width: 20 * _mm,
                    height: 20 * _mm,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Chuỗi QR · ngày.
        pw.SizedBox(
          height: _footerH,
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 1.5 * _mm),
                  child: pw.Center(
                    child: pw.FittedBox(
                      fit: pw.BoxFit.scaleDown,
                      child: pw.Text(
                        label.qrContent,
                        maxLines: 1,
                        style: pw.TextStyle(
                          font: f.boldItalic,
                          fontSize: 7,
                          color: _navy,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              pw.SizedBox(
                width: _qrColW,
                child: pw.Center(
                  child: pw.Text(
                    label.dateLabel,
                    style: pw.TextStyle(
                      font: f.italic,
                      fontSize: 7.5,
                      color: _navy,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ============================================================
// PNG: raster đúng tem PDF (600 dpi, QR ~470 px)
// ============================================================

Future<Uint8List> renderFixedAssetQrPng(FixedAssetQrLabel label) async {
  final fonts = await _labelFonts();
  final doc = pw.Document()
    ..addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(_labelW, _labelH),
        margin: pw.EdgeInsets.zero,
        build: (_) => _label(label, fonts),
      ),
    );
  final bytes = await doc.save();
  await for (final page in Printing.raster(bytes, pages: const [0], dpi: 600)) {
    return page.toPng();
  }
  throw StateError('PNG render failed');
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
// PDF A4: 2 x 5 tem, căn giữa trang
// ============================================================

Future<Uint8List> buildFixedAssetQrPdf(List<FixedAssetQrLabel> labels) async {
  final fonts = await _labelFonts();
  final doc = pw.Document();
  const perPage = _cols * _rows;

  pw.Widget cell(List<FixedAssetQrLabel> page, int i) => i < page.length
      ? _label(page[i], fonts)
      : pw.SizedBox(width: _labelW, height: _labelH);

  for (var start = 0; start < labels.length; start += perPage) {
    final page = labels.sublist(
      start,
      (start + perPage).clamp(0, labels.length),
    );
    final rows = (page.length / _cols).ceil();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(top: 18 * _mm),
        build: (_) => pw.Column(
          children: [
            for (var r = 0; r < rows; r++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: _gapY),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    cell(page, r * _cols),
                    pw.SizedBox(width: _gapX),
                    cell(page, r * _cols + 1),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  return doc.save();
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
