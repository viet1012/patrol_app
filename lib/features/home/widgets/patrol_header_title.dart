import 'package:flutter/material.dart';

import 'package:chuphinh/shared/animations/glow_title.dart';
import 'package:chuphinh/shared/widgets/app_version_text.dart';

/// Header "logo + S-PATROL + version" của màn home.
///
/// Chỉ chữ "S-PATROL" có vệt sáng, dùng chung controller 12s của màn home.
/// Logo và badge version tĩnh.
class PatrolHeaderTitle extends StatelessWidget {
  final Animation<double> animation;

  const PatrolHeaderTitle({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    final shine = MediaQuery.disableAnimationsOf(context) ? null : animation;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/flags/favicon.png',
          width: 40,
          height: 40,
          filterQuality: FilterQuality.medium,
          fit: BoxFit.contain,
          cacheWidth: 80,
          cacheHeight: 80,
        ),
        const SizedBox(width: 8),
        _TitleShine(
          animation: shine,
          child: const EmbossGlowTitle(text: 'S-PATROL', animate: false),
        ),
        const SizedBox(width: 8),
        const AppVersionText(animate: false),
      ],
    );
  }
}

/// Vệt sáng chạy ngang chữ 1s mỗi chu kỳ 12s. Ngoài lúc chạy trả thẳng [child].
class _TitleShine extends StatelessWidget {
  static const _cycleSeconds = 12.0;
  static const _durationSeconds = 1.0;

  // Dải sáng ~20% chiều rộng.
  static const _band = .2;

  final Animation<double>? animation;
  final Widget child;

  const _TitleShine({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    final anim = animation;
    if (anim == null) return child;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: anim,
        child: child,
        builder: (_, child) {
          final p = anim.value * _cycleSeconds / _durationSeconds;
          if (p >= 1) return child!;

          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              // Tâm dải chạy từ -band/2 đến 1 + band/2 theo chiều rộng.
              final center = -_band / 2 + (1 + _band) * p;
              final dx = (center - .5) * bounds.width;
              return LinearGradient(
                colors: [
                  Colors.white.withOpacity(0),
                  Colors.white.withOpacity(.6),
                  Colors.white.withOpacity(0),
                ],
                stops: const [.5 - _band / 2, .5, .5 + _band / 2],
              ).createShader(bounds.shift(Offset(dx, 0)));
            },
            child: child,
          );
        },
      ),
    );
  }
}
