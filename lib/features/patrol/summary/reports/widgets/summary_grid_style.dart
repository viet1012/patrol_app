import 'package:flutter/material.dart';

/// Kích thước, màu và cột của các bảng summary theo PIC.
class SummaryGridStyle {
  SummaryGridStyle._();

  static const double gapBetweenTables = 8;

  static const double titleHeight = 36;
  static const double groupHeaderHeight = 30;
  static const double headerRowHeight = 34;
  static const double cellHeight = 34;

  static const double borderRadius = 12;

  static const Color borderColor = Color(0xFFD7DCE5);
  static const Color groupedHeaderBg = Color(0xFFF3F6FA);
  static const Color headerBg = Color(0xFFF8FAFC);
  static const Color totalRowBg = Color(0xFFFFF7CC);
  static const Color tableBg = Colors.white;
  static const Color firstColumnBg = Color(0xFFF7F8FA);

  // ---- Nhãn dùng chung: bảng SUMMARY + bảng PIC ----
  static const String groupBefore = 'BEFORE';
  static const String groupAfter = 'AFTER';
  static const String groupHseRecheck = 'HSE RECHECK';
  static const String subtitleBefore = 'NG points';
  static const String subtitleAfter = 'Pro Action';
  static const String subtitleHseRecheck = 'HSE re-check';
  static const String colTotal = 'TTL';

  // ---- Typography dùng chung ----
  /// Nhóm lớn: "BEFORE" / "AFTER" / "HSE RECHECK".
  static const Color titleText = Colors.redAccent;

  /// Tiêu đề phụ: "NG points" / "Pro action" / "HSE re-check".
  static const Color subtitleText = Colors.blueAccent;

  /// Chữ "SUMMARY" và chip tên fac.
  static const Color summaryTitleText = Color(0xFFF59E0B);

  /// Padding ngang của mọi ô (header + dữ liệu).
  static const double cellPaddingH = 6;

  /// Tiêu đề bảng (SUMMARY, BEFORE, AFTER, HSE RECHECK); màu đỏ mặc định.
  static const TextStyle titleStyle = TextStyle(
    color: titleText,
    fontSize: 15,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle subtitleStyle = TextStyle(
    color: subtitleText,
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );

  /// Header nhóm + header cột.
  static const TextStyle headerStyle = TextStyle(
    color: Colors.black87,
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );

  /// Ô số và tên (Area, PIC, Fac).
  static const TextStyle cellStyle = TextStyle(
    color: Colors.black87,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  /// Dòng SUM / TOTAL / %.
  static const TextStyle totalCellStyle = TextStyle(
    color: Colors.black87,
    fontSize: 14,
    fontWeight: FontWeight.w900,
  );

  /// Tỉ lệ trên title bar ("Finished x% • Remain x%", "OK x% • NG x%").
  static const TextStyle rateLabelStyle = TextStyle(
    color: Colors.black87,
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );
  static const TextStyle rateValueStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w900,
  );

  /// Chiều cao vừa khít bảng [rowCount] dòng: title + group + header + dòng
  /// + viền ngoài.
  static double fittedTableHeight(int rowCount) =>
      titleHeight +
      groupHeaderHeight +
      headerRowHeight +
      rowCount * cellHeight +
      2;

  static const Color finishedHeaderBg = Color(0xFF8FEFA0);
  static const Color okHeaderBg = Color(0xFF8FEFA0);
  static const Color remainHeaderBg = Color(0xFFF89292);
  static const Color ngHeaderBg = Color(0xFFF89292);
  static const Color deadlineHeaderBg = Color(0xFFFFE6B5);

  static const Color finishedBg = Color(0xFFBFF2C8);
  static const Color remainBg = Color(0xFFFFC2C2);
  static const Color okBg = Color(0xFFBFF2C8);
  static const Color ngBg = Color(0xFFFFC2C2);
  static const Color deadlineBg = Color(0xFFFFF3CD);

  static const Color finishedBorder = Color(0xFF7BCB8D);
  static const Color remainBorder = Color(0xFFF89292);
  static const Color okBorder = Color(0xFF7BCB8D);
  static const Color ngBorder = Color(0xFFF89292);
  static const Color deadlineBorder = Color(0xFFFFA726);

  static const List<String> beforeColumns = [
    'PIC',
    colTotal,
    'I',
    'II',
    'III',
    'IV',
    'V',
  ];

  static const List<String> afterColumns = [
    'PIC',

    // Finished
    colTotal, 'I', 'II', 'III', 'IV', 'V',

    // Remain
    colTotal, 'I', 'II', 'III', 'IV', 'V',

    // Deadline
    'Still',
    '3 Days',
    'Late',
  ];

  static const List<String> recheckColumns = [
    'PIC',
    'All',
    colTotal,
    'I',
    'II',
    'III',
    'IV',
    'V',
    colTotal,
    'I',
    'II',
    'III',
    'IV',
    'V',
  ];

  static const List<String> deadlineColumns = [
    'PIC',
    'Still',
    '3 Days',
    'Late',
  ];

  static double columnWidth(String column) {
    switch (column) {
      case 'PIC':
        return 150;
      case colTotal:
      case 'All':
        return 54;
      case 'I':
      case 'II':
      case 'III':
      case 'IV':
      case 'V':
        return 42;
      case 'Still':
      case '3 Days':
      case 'Late':
        return 85;
      default:
        return 58;
    }
  }

  static double tableWidth(List<String> columns) {
    return columns.fold(0.0, (sum, item) => sum + columnWidth(item));
  }
}
