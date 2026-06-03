import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MachineAiSummary {
  final String summaryVi;
  final String summaryJp;

  const MachineAiSummary({required this.summaryVi, required this.summaryJp});

  factory MachineAiSummary.fromJson(Map<String, dynamic> json) {
    return MachineAiSummary(
      summaryVi: (json['summaryVi'] ?? '').toString().trim(),
      summaryJp: (json['summaryJp'] ?? '').toString().trim(),
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

  const MachineAiAlertCard({
    super.key,
    required this.lang,
    required this.machine,
    required this.loading,
    required this.error,
    required this.summary,
    required this.onRetry,
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
              text: _isJp
                  ? widget.summary?.summaryJp
                  : widget.summary?.summaryVi,
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

  const _MachineAiBody({
    required this.isJp,
    required this.machine,
    required this.loading,
    required this.error,
    required this.summary,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return _LoadingState(isJp: isJp, machine: machine);

    if (error != null) {
      return _ErrorState(isJp: isJp, message: error!, onRetry: onRetry);
    }

    if (summary == null) {
      return _EmptyState(isJp: isJp);
    }

    final text = isJp ? summary!.summaryJp : summary!.summaryVi;

    if (text.trim().isEmpty) {
      return _EmptyState(isJp: isJp);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_AiReportBlock(text: text)],
    );
  }
}

class _AiHeader extends StatelessWidget {
  final bool isJp;
  final String machine;
  final bool collapsed;
  final String? text;

  const _AiHeader({
    required this.isJp,
    required this.machine,
    required this.collapsed,
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

        AnimatedRotation(
          turns: collapsed ? 0 : 0.5,
          duration: const Duration(milliseconds: 250),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withOpacity(.7),
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

  const _EmptyState({required this.isJp});

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
                ? 'AI分析に十分な履歴データがありません。継続的な巡回記録が必要です。'
                : 'AI analysis unavailable. More patrol records are required to identify risk patterns.',
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
