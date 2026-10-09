import 'package:chuphinh/core/api/api_config.dart';
import 'package:chuphinh/features/patrol/summary/widgets/theme/patrol_report_theme.dart';
import 'package:flutter/material.dart';

String patrolImageUrl(String name) => '${ApiConfig.baseUrl}/images/$name';

/// Thumbnail ảnh đầu tiên của dòng + badge "+N" (số ảnh còn lại).
///
/// Decode theo kích thước hiển thị (`cacheWidth`) để cuộn bảng không giật.
class PatrolReportImageThumb extends StatelessWidget {
  static const double _decodeOversample = 1.5;

  final List<String> names;
  final PatrolReportThumbSize size;
  final VoidCallback? onTap;

  const PatrolReportImageThumb({
    super.key,
    required this.names,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = size.width;
    final h = size.height;

    if (names.isEmpty) {
      return SizedBox(
        width: w,
        height: h,
        child: const Icon(
          Icons.image_not_supported,
          size: 18,
          color: Colors.grey,
        ),
      );
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final extra = names.length - 1;
    final radius = BorderRadius.circular(PatrolReportThumbSize.radius);

    return Tooltip(
      message: names.length == 1 ? '1 image' : '${names.length} images',
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: RepaintBoundary(
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    patrolImageUrl(names.first),
                    fit: BoxFit.cover,
                    // Chỉ cố định chiều rộng để giữ tỉ lệ gốc khi decode.
                    // Dư 1,5 lần: ảnh 16:9 bị cover cắt 2 bên vẫn đủ nét.
                    cacheWidth: (w * dpr * _decodeOversample).round(),
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    frameBuilder: (context, child, frame, sync) {
                      if (sync || frame != null) return child;
                      return const _ThumbPlaceholder();
                    },
                    errorBuilder: (_, _, _) => const _ThumbError(),
                  ),
                  if (extra > 0)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: _CountBadge(text: '+$extra'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.blueGrey.shade50,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 22,
          color: Colors.blueGrey.shade200,
        ),
      ),
    );
  }
}

class _ThumbError extends StatelessWidget {
  const _ThumbError();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.red.shade50,
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 22,
          color: Colors.redAccent,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String text;

  const _CountBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(PatrolReportTokens.rPill),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: PatrolReportTokens.fsXs,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}
