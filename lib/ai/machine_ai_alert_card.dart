import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MachineAiSummary {
  final String summaryVi;

  const MachineAiSummary({required this.summaryVi});

  factory MachineAiSummary.fromJson(Map<String, dynamic> json) {
    return MachineAiSummary(
      summaryVi: (json['summaryVi'] ?? '').toString().trim(),
    );
  }
}

class MachineAiAlertCard extends StatefulWidget {
  final String lang;
  final String? machine;
  final bool loading;
  final String? error;
  final MachineAiSummary? summary;
  final VoidCallback onRetry;
  final String? summaryJp;
  final bool translatingJp;
  final VoidCallback onTranslateJp;

  const MachineAiAlertCard({
    super.key,
    required this.lang,
    required this.machine,
    required this.loading,
    required this.error,
    required this.summary,
    required this.onRetry,
    this.summaryJp,
    this.translatingJp = false,
    required this.onTranslateJp,
  });

  @override
  State<MachineAiAlertCard> createState() => _MachineAiAlertCardState();
}

class _MachineAiAlertCardState extends State<MachineAiAlertCard> {
  bool _collapsed = false;

  bool get _isJp => widget.lang.toUpperCase() == 'JP';

  @override
  Widget build(BuildContext context) {
    final mac = widget.machine?.trim() ?? '';

    if (mac.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(.24)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() {
                _collapsed = !_collapsed;
              });
            },
            child: _AiHeader(
              isJp: _isJp,
              machine: mac,
              collapsed: _collapsed,
              text: _isJp ? widget.summaryJp : widget.summary?.summaryVi,
              onRetry: widget.onRetry,
              onToggleCollapse: () {
                setState(() {
                  _collapsed = !_collapsed;
                });
              },
            ),
          ),

          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _collapsed
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.all(8),
              child: _MachineAiBody(
                isJp: _isJp,
                machine: mac,
                loading: widget.loading,
                error: widget.error,
                summary: widget.summary,
                onRetry: widget.onRetry,
                summaryJp: widget.summaryJp,
                translatingJp: widget.translatingJp,
                onTranslateJp: widget.onTranslateJp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MachineAiBody extends StatelessWidget {
  final bool isJp;
  final String machine;
  final bool loading;
  final String? error;
  final MachineAiSummary? summary;
  final VoidCallback onRetry;
  final String? summaryJp;
  final bool translatingJp;
  final VoidCallback onTranslateJp;

  const _MachineAiBody({
    required this.isJp,
    required this.machine,
    required this.loading,
    required this.error,
    required this.summary,
    required this.onRetry,
    required this.summaryJp,
    required this.translatingJp,
    required this.onTranslateJp,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return _LoadingState(isJp: isJp, machine: machine);

    if (error != null) {
      return _ErrorState(isJp: isJp, message: error!, onRetry: onRetry);
    }

    if (summary == null) {
      return _EmptyState(isJp: isJp, onRetry: onRetry);
    }
    final viText = summary!.summaryVi.trim();

    if (!isJp) {
      if (viText.isEmpty) {
        return _EmptyState(isJp: isJp, onRetry: onRetry);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_AiReportBlock(text: viText)],
      );
    }

    final jpText = summaryJp?.trim() ?? '';

    if (jpText.isEmpty) {
      return _TranslateJpState(
        translating: translatingJp,
        onTranslateJp: onTranslateJp,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_AiReportBlock(text: jpText)],
    );
  }
}

class _AiHeader extends StatelessWidget {
  final bool isJp;
  final String machine;
  final bool collapsed;
  final String? text;
  final VoidCallback onRetry;
  final VoidCallback onToggleCollapse;

  const _AiHeader({
    required this.isJp,
    required this.machine,
    required this.collapsed,
    required this.onRetry,
    required this.onToggleCollapse,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF38BDF8).withOpacity(.12),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF67E8F9),
            size: 20,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isJp ? 'AIリスクレポート' : 'AI Risk Report',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              Text(
                machine,
                style: TextStyle(
                  color: Colors.white.withOpacity(.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((text ?? '').isNotEmpty)
              IconButton(
                tooltip: 'Refresh',
                splashRadius: 18,
                iconSize: 18,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFF67E8F9),
                ),
                onPressed: onRetry,
              ),

            if ((text ?? '').isNotEmpty)
              IconButton(
                tooltip: 'Copy',
                splashRadius: 18,
                iconSize: 18,
                icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text!));

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
          ],
        ),
        IconButton(
          tooltip: collapsed ? 'Expand' : 'Collapse',
          splashRadius: 18,
          iconSize: 22,
          onPressed: onToggleCollapse,
          icon: AnimatedRotation(
            turns: collapsed ? 0 : 0.5,
            duration: const Duration(milliseconds: 250),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withOpacity(.7),
            ),
          ),
        ),
      ],
    );
  }
}

class _AiReportBlock extends StatelessWidget {
  final String text;

  const _AiReportBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    final sections = _parseAiSections(text);

    if (sections.isEmpty) {
      return _PlainAiText(text: text);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: sections.map((section) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _AiSectionBlock(section: section),
          );
        }).toList(),
      ),
    );
  }

  List<_AiSectionData> _parseAiSections(String raw) {
    final lines = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final result = <_AiSectionData>[];
    _AiSectionData? current;

    void startSection({
      required IconData icon,
      required String title,
      required Color color,
      String? firstItem,
    }) {
      current = _AiSectionData(
        icon: icon,
        title: title,
        color: color,
        items: [],
      );

      final item = firstItem?.trim() ?? '';
      if (item.isNotEmpty) {
        current!.items.add(item);
      }

      result.add(current!);
    }

    String afterPrefix(String text, String prefix) {
      return text.substring(prefix.length).trim();
    }

    for (final line in lines) {
      final normalized = line.replaceAll('：', ':').trim();

      if (normalized == 'Tổng quan:') {
        startSection(
          icon: Icons.analytics_outlined,
          title: 'Tổng quan',
          color: const Color(0xFF67E8F9),
        );
        continue;
      }

      if (normalized.startsWith('Tổng quan:')) {
        startSection(
          icon: Icons.analytics_outlined,
          title: 'Tổng quan',
          color: const Color(0xFF67E8F9),
          firstItem: afterPrefix(normalized, 'Tổng quan:'),
        );
        continue;
      }

      if (normalized.startsWith('Khoảng') ||
          normalized.startsWith('Phần lớn') ||
          normalized.startsWith('Các lỗi') ||
          normalized.startsWith('Nhóm lỗi') ||
          normalized.startsWith('Che chắn') ||
          normalized.startsWith('Thiếu')) {
        if (current != null && current!.title == 'Tổng quan') {
          current!.items.add(normalized);
        } else {
          startSection(
            icon: Icons.analytics_outlined,
            title: 'Tổng quan',
            color: const Color(0xFF67E8F9),
            firstItem: normalized,
          );
        }

        continue;
      }

      if (normalized == '概要:') {
        startSection(
          icon: Icons.analytics_outlined,
          title: '概要',
          color: const Color(0xFF67E8F9),
        );
        continue;
      }

      if (normalized.startsWith('概要:')) {
        startSection(
          icon: Icons.analytics_outlined,
          title: '概要',
          color: const Color(0xFF67E8F9),
          firstItem: afterPrefix(normalized, '概要:'),
        );
        continue;
      }

      if (normalized == 'Top lỗi thường gặp:') {
        startSection(
          icon: Icons.warning_amber_rounded,
          title: 'Top lỗi thường gặp',
          color: const Color(0xFFFBBF24),
        );
        continue;
      }

      if (normalized.startsWith('Top lỗi thường gặp:')) {
        startSection(
          icon: Icons.warning_amber_rounded,
          title: 'Top lỗi thường gặp',
          color: const Color(0xFFFBBF24),
          firstItem: afterPrefix(normalized, 'Top lỗi thường gặp:'),
        );
        continue;
      }

      if (normalized == '上位頻発問題:') {
        startSection(
          icon: Icons.warning_amber_rounded,
          title: '上位頻発問題',
          color: const Color(0xFFFBBF24),
        );
        continue;
      }

      if (normalized.startsWith('上位頻発問題:')) {
        startSection(
          icon: Icons.warning_amber_rounded,
          title: '上位頻発問題',
          color: const Color(0xFFFBBF24),
          firstItem: afterPrefix(normalized, '上位頻発問題:'),
        );
        continue;
      }

      if (normalized == 'Khuyến nghị:') {
        startSection(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Khuyến nghị',
          color: const Color(0xFF86EFAC),
        );
        continue;
      }

      if (normalized.startsWith('Khuyến nghị:')) {
        startSection(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Khuyến nghị',
          color: const Color(0xFF86EFAC),
          firstItem: afterPrefix(normalized, 'Khuyến nghị:'),
        );
        continue;
      }

      if (normalized == '推奨対策:') {
        startSection(
          icon: Icons.lightbulb_outline_rounded,
          title: '推奨対策',
          color: const Color(0xFF86EFAC),
        );
        continue;
      }

      if (normalized.startsWith('推奨対策:')) {
        startSection(
          icon: Icons.lightbulb_outline_rounded,
          title: '推奨対策',
          color: const Color(0xFF86EFAC),
          firstItem: afterPrefix(normalized, '推奨対策:'),
        );
        continue;
      }

      current?.items.add(line);
    }

    result.removeWhere((e) => e.items.isEmpty);
    return result;
  }
}

class _AiSectionData {
  final IconData icon;
  final String title;
  final Color color;
  final List<String> items;

  const _AiSectionData({
    required this.icon,
    required this.title,
    required this.color,
    required this.items,
  });
}

class _AiSectionBlock extends StatelessWidget {
  final _AiSectionData section;

  const _AiSectionBlock({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: section.color.withOpacity(.055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: section.color.withOpacity(.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(section.icon, size: 15, color: section.color),
              const SizedBox(width: 6),
              Text(
                section.title,
                style: TextStyle(
                  color: section.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          ...section.items.map((item) {
            final clean = item.replaceFirst(RegExp(r'^-\s*'), '');

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText(
                clean,
                style: TextStyle(
                  color: Colors.white.withOpacity(.90),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PlainAiText extends StatelessWidget {
  final String text;

  const _PlainAiText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(.92),
          fontSize: 14,
          height: 1.55,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final bool isJp;
  final String machine;

  const _LoadingState({required this.isJp, required this.machine});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.cyanAccent.withOpacity(.9),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            isJp ? 'AIが $machine を分析中です...' : 'AI is analyzing $machine...',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final bool isJp;
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.isJp,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orangeAccent,
          size: 21,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(onPressed: onRetry, child: Text(isJp ? '再試行' : 'Retry')),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isJp;
  final VoidCallback onRetry;

  const _EmptyState({required this.isJp, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.analytics_outlined,
          color: Color(0xFF67E8F9),
          size: 21,
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            isJp
                ? 'この機械カテゴリには現在十分な履歴データがありません。今後データを追加して改善していきます。'
                : 'There is currently no historical data available for this machine category. We will continue expanding our database in future updates.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        const SizedBox(width: 8),

        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: Text(isJp ? '再分析' : 'Retry'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF67E8F9),
            side: BorderSide(color: const Color(0xFF67E8F9).withOpacity(.4)),
          ),
        ),
      ],
    );
  }
}

class _TranslateJpState extends StatelessWidget {
  final bool translating;
  final VoidCallback onTranslateJp;

  const _TranslateJpState({
    required this.translating,
    required this.onTranslateJp,
  });

  @override
  Widget build(BuildContext context) {
    if (translating) {
      return Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.cyanAccent.withOpacity(.9),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '日本語に翻訳中です...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.translate_rounded, color: Color(0xFF67E8F9), size: 21),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            '日本語版はまだ作成されていません。',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onTranslateJp,
          icon: const Icon(Icons.translate_rounded, size: 16),
          label: const Text('翻訳'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF67E8F9),
            side: BorderSide(color: const Color(0xFF67E8F9).withOpacity(.4)),
          ),
        ),
      ],
    );
  }
}
