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
    'Total',
    'I',
    'II',
    'III',
    'IV',
    'V',
  ];

  static const List<String> afterColumns = [
    'PIC',

    // Finished
    'Total', 'I', 'II', 'III', 'IV', 'V',

    // Remain
    'Total', 'I', 'II', 'III', 'IV', 'V',

    // Deadline
    'Still',
    '3 Days',
    'Late',
  ];

  static const List<String> recheckColumns = [
    'PIC',
    'All',
    'Total',
    'I',
    'II',
    'III',
    'IV',
    'V',
    'Total',
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
      case 'Total':
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
