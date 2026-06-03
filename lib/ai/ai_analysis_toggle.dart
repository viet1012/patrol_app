import 'package:flutter/material.dart';

class AiAnalysisToggle extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final bool hasMachine;
  final VoidCallback? onTap;

  const AiAnalysisToggle({
    super.key,
    required this.enabled,
    required this.loading,
    required this.hasMachine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && hasMachine;
    final canTap = hasMachine && !loading;

    return Align(
      alignment: Alignment.centerRight,
      child: Opacity(
        opacity: hasMachine ? 1 : .45,
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: canTap ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: 106,
            height: 34,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: active
                  ? LinearGradient(
                      colors: [
                        const Color(0xFF38BDF8).withOpacity(.85),
                        const Color(0xFF22C55E).withOpacity(.75),
                      ],
                    )
                  : null,
              color: active ? null : Colors.white.withOpacity(.08),
              border: Border.all(
                color: active
                    ? const Color(0xFF67E8F9).withOpacity(.65)
                    : Colors.white.withOpacity(.10),
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withOpacity(.28),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  alignment: active
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(active ? .95 : .35),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.22),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: active
                          ? const Color(0xFF0EA5E9)
                          : Colors.white.withOpacity(.7),
                    ),
                  ),
                ),

                Center(
                  child: Text(
                    active ? 'AI ON' : 'AI OFF',
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : Colors.white.withOpacity(.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
