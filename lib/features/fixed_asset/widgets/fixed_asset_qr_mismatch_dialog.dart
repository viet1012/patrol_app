import 'package:flutter/material.dart';

import 'package:chuphinh/features/fixed_asset/fixed_asset_audit_flow.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_location.dart';

/// Dialog "QR không khớp vị trí đang chọn" (MANUAL): bảng so sánh
/// VỊ TRÍ ĐANG CHỌN vs VỊ TRÍ TRÊN QR theo từng mục, mục sai tô đỏ.
/// Màu tím + icon QR để không nhầm với "Sai vị trí máy" (MASTER).
/// Pop true = "Vẫn lưu (đánh dấu in lại QR)", false = "Bỏ qua".
class FixedAssetQrMismatchDialog extends StatelessWidget {
  final String machineCode;
  final String faName;
  final FixedAssetAuditLocation selected;
  final FixedAssetQrLocationCheck qr;

  const FixedAssetQrMismatchDialog({
    super.key,
    required this.machineCode,
    required this.faName,
    required this.selected,
    required this.qr,
  });

  static const Color _violet = Color(0xFFA78BFA);
  static const Color _red = Color(0xFFEF4444);
  static const Color _green = Color(0xFF22C55E);
  static const double _labelW = 64;
  static const double _iconW = 22;

  /// So sánh bỏ qua hoa/thường và khoảng trắng.
  static String _norm(String? s) =>
      (s ?? '').trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  @override
  Widget build(BuildContext context) {
    // QR không chứa nhà máy; Khu chỉ so khi QR có.
    final rows = <_QrRow>[
      _QrRow('Nhà máy', selected.fac, null, comparable: false),
      _QrRow('Tầng', selected.floor, qr.floor),
      _QrRow(
        'Khu',
        selected.positionA,
        qr.positionA,
        comparable: qr.positionA != null,
      ),
      _QrRow('Vị trí', selected.positionAA, qr.positionAA),
    ];
    final wrong = rows
        .where((r) => r.comparable && !r.matches)
        .map((r) => r.label)
        .toList();

    return Dialog(
      backgroundColor: const Color(0xFF1F2937),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _violet.withOpacity(.6)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.qr_code_2_rounded, color: _violet, size: 22),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'QR không khớp vị trí đang chọn',
                      style: TextStyle(
                        color: _violet,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                machineCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (faName.isNotEmpty)
                Text(
                  faName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.65),
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 12),
              _summary(wrong),
              const SizedBox(height: 8),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(.15)),
                ),
                child: Column(
                  children: [
                    _headerRow(),
                    for (final r in rows) ...[
                      Divider(height: 1, color: Colors.white.withOpacity(.08)),
                      _rowWidget(r),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Các mục tô đỏ trên QR khác vị trí đang chọn. Kết quả vẫn được '
                'lưu và máy này sẽ được đánh dấu cần in lại QR.',
                style: TextStyle(
                  color: Colors.white.withOpacity(.8),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              _buttons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(List<String> wrong) {
    final bad = wrong.isNotEmpty;
    final color = bad ? _red : _violet;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(.5)),
      ),
      child: Row(
        children: [
          Icon(
            bad ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bad
                  ? 'Sai ở: ${wrong.join(', ')}'
                  : 'Không thấy mục nào khác vị trí đang chọn',
              style: TextStyle(
                color: color,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow() {
    TextStyle s(Color c) => TextStyle(
      color: c,
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: .6,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 7, 10, 7),
      child: Row(
        children: [
          const SizedBox(width: _labelW),
          Expanded(
            child: Text('ĐANG CHỌN', style: s(Colors.white.withOpacity(.55))),
          ),
          Expanded(child: Text('TRÊN QR', style: s(_violet))),
          const SizedBox(width: _iconW),
        ],
      ),
    );
  }

  Widget _rowWidget(_QrRow r) {
    final wrong = r.comparable && !r.matches;
    final ok = r.comparable && r.matches;

    return Container(
      decoration: BoxDecoration(
        color: wrong ? _red.withOpacity(.14) : Colors.transparent,
        border: Border(
          left: BorderSide(color: wrong ? _red : Colors.transparent, width: 3),
        ),
      ),
      padding: EdgeInsets.fromLTRB(10, wrong ? 9 : 7, 10, wrong ? 9 : 7),
      child: Row(
        children: [
          SizedBox(
            width: _labelW,
            child: Text(
              r.label,
              style: TextStyle(
                color: wrong ? _red : Colors.white.withOpacity(.55),
                fontSize: 12,
                fontWeight: wrong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: _value(
              fixedAssetDash(r.selected ?? ''),
              color: r.comparable ? Colors.white : Colors.white.withOpacity(.6),
              bold: wrong,
            ),
          ),
          Expanded(
            child: _value(
              r.comparable ? fixedAssetDash(r.qr ?? '') : '—',
              color: wrong
                  ? _red
                  : (r.comparable
                        ? Colors.white
                        : Colors.white.withOpacity(.4)),
              bold: wrong,
              big: wrong,
            ),
          ),
          SizedBox(
            width: _iconW,
            child: wrong
                ? const Icon(Icons.close_rounded, color: _red, size: 18)
                : ok
                ? Icon(
                    Icons.check_rounded,
                    color: _green.withOpacity(.8),
                    size: 16,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _value(
    String text, {
    required Color color,
    bool bold = false,
    bool big = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: big ? 15 : 14,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buttons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(.3)),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Bỏ qua',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _violet,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Vẫn lưu (đánh dấu in lại QR)',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _QrRow {
  final String label;
  final String? selected;
  final String? qr;
  final bool comparable;

  const _QrRow(this.label, this.selected, this.qr, {this.comparable = true});

  bool get matches =>
      FixedAssetQrMismatchDialog._norm(selected) ==
      FixedAssetQrMismatchDialog._norm(qr);
}
