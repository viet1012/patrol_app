import 'package:flutter/material.dart';

/// Design tokens cho màn hình Data Table (PatrolReportTable).
abstract final class PatrolReportTokens {
  // ----------------------------------------------------------- breakpoints
  /// Dưới mức này dùng layout mobile.
  static const double mobileBreakpoint = 700;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  // ---------------------------------------------------------------- colors
  static const Color pageBg = Color(0xFF0F2027);
  static const Color surface = Color(0xFF172A33);
  static const Color surfaceRaised = Color(0xFF1E293B);

  /// Glass: nền trắng 8%, viền trắng 12%.
  static const Color glass = Color(0x14FFFFFF);
  static const Color glassBorder = Color(0x1FFFFFFF);
  static const Color border = Color(0x3DFFFFFF);

  static const Color accent = Color(0xFF38BDF8);
  static const Color accentStrong = Color(0xFF0284C7);
  static const Color action = Colors.greenAccent;

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textMuted = Color(0x61FFFFFF);
  static const Color iconMuted = Color(0xFFCBD5E1);

  static const Color danger = Color(0xFFE53935);
  static const Color success = Color(0xFF43A047);

  // ----------------------------------------------------------------- table
  static const Color tableHeaderBg = Color(0xFFEEEEEE);
  static const Color tableDivider = Color(0xFFE0E0E0);
  static const Color rowEven = Colors.white;
  static const Color rowOdd = Color(0xFFF3F6F8);
  static const Color rowHover = Color(0xFFE6F2FA);
  static const Color rowSelected = Color(0xFFCDEBFB);
  static const Color rowLateMarker = Color(0xFFEF9A9A);
  static const double rowLateMarkerWidth = 3;

  static const Color skeletonBase = Color(0x1FFFFFFF);

  // --------------------------------------------------------------- spacing
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;

  // ---------------------------------------------------------------- radius
  static const double r10 = 10;
  static const double r14 = 14;
  static const double rPill = 999;

  // ------------------------------------------------------------------ size
  static const double tapTarget = 40;
  static const double tapTargetCompact = 36;

  // ------------------------------------------------------------ typography
  static const double fsXs = 12;
  static const double fsSm = 14;
  static const double fsMd = 14;
  static const double fsLg = 14;
  static const double fsXl = 16;
}

/// Dải lọc Fac → Group ở trên cùng.
abstract final class PatrolReportFilterBarTokens {
  /// Dưới bề rộng này: gộp Fac + Group thành 1 nút dropdown.
  static const double collapseBreakpoint = 900;

  static const String allLabel = 'Tất cả';
  static const String noDataLabel = 'Không có dữ liệu';

  // Ô From/To
  /// Viền accent khi khoảng ngày khác mặc định.
  static const double dateActiveBorderWidth = 1.5;

  /// Nút icon "Reset date range" cạnh ô To.
  static const double resetButtonSize = 32;

  // Khoảng trống dọc phía trên
  /// Chiều cao hàng Group (desktop): vừa chip 36 / nút 38–40, căn giữa.
  static const double rowHeight = 44;
  static const double rowTopPadding = 4;

  /// Khoảng cách hàng Group -> khung Patrol Summary (hoặc toolbar khi ẩn
  /// summary). Là padding dưới của hàng Group; Summary không có lề trên.
  static const double rowBottomGap = 8;

  /// Khoảng cách giữa các hàng con khi xếp dọc (mobile).
  static const double stackedRowGap = 6;

  /// Lề ngang/dưới của khung Patrol Summary (lề trên = 0).
  static const double summaryPadding = 12;
  static const double summaryPaddingCompact = 6;
  static const double summaryCardMargin = 4;

  // Segment Fac
  static const double segmentHeight = 36;
  static const double segmentPaddingH = 10;

  /// Fac segment tối đa bao nhiêu phần bề rộng còn lại (phần dư cuộn ngang).
  static const double segmentMaxShare = 0.45;

  // Chip Group
  static const double chipHeight = 32;
  static const double chipPaddingH = 10;
  static const double chipGap = 6;
  static const double chipBorderWidth = 1;

  /// Khoảng cách + vạch ngăn giữa các nhóm Fac (chế độ "Tất cả").
  static const double facGroupGap = 12;
  static const double facDividerHeight = 20;

  // Badge
  static const double badgeMinWidth = 20;
  static const double zeroCountOpacity = 0.45;

  // Cuộn ngang
  static const double fadeWidth = 28;
  static const double navButtonSize = 28;
  static const double scrollStepFraction = 0.7;
  static const Duration scrollDuration = Duration(milliseconds: 280);

  // Dropdown gộp (màn hình hẹp)
  static const double pickerMaxWidth = 420;
  static const double pickerMaxHeight = 560;
  static const double pickerButtonMaxWidth = 320;
  static const double pickerRowHeight = 40;
  static const double pickerIndent = 28;
}

/// Kích thước thumbnail ảnh trong bảng. Chỉnh tại đây; độ rộng cột ảnh và
/// chiều cao dòng (PatrolReportRow) cần đủ chứa `width/height + padding`.
class PatrolReportThumbSize {
  const PatrolReportThumbSize._(this.width, this.height);

  final double width;
  final double height;

  /// Img(B) desktop: ~1,5 lần trước (80 -> 120×90).
  static const large = PatrolReportThumbSize._(largeWidth, largeHeight);

  /// Img(A), Img(H) desktop.
  static const regular = PatrolReportThumbSize._(regularWidth, 60);

  /// Img(B) mobile (dòng cao 60).
  static const compactLarge = PatrolReportThumbSize._(72, 54);

  /// Img(A), Img(H) mobile.
  static const compact = PatrolReportThumbSize._(64, 48);

  // Giá trị thô cho biểu thức const (độ rộng cột, chiều cao dòng).
  static const double largeWidth = 120;
  static const double largeHeight = 90;
  static const double regularWidth = 80;

  static const double radius = 8;

  /// Lề ngang trong ô ảnh (mỗi bên).
  static const double cellPadding = 8;
}
