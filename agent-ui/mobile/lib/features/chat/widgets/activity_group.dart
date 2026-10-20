import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../data/models/chat_item.dart';
import '../../../domain/activity.dart';

/// One collapsible block holding a turn's reasoning and tool calls, like the
/// web app's ActivityGroup. Collapsed by default; always open while a tool
/// waits for approval.
class ActivityGroup extends StatefulWidget {
  const ActivityGroup({super.key, required this.steps, this.liveStatus, required this.onDecide});

  final List<ActivityStep> steps;

  /// Status text while this group is the one running; null once it is done.
  final String? liveStatus;
  final void Function(String callId, {required bool approved}) onDecide;

  @override
  State<ActivityGroup> createState() => _ActivityGroupState();
}

class _ActivityGroupState extends State<ActivityGroup> with AutomaticKeepAliveClientMixin {
  bool _expanded = false;

  /// An opened group stays open when scrolled out of view and back.
  @override
  bool get wantKeepAlive => _expanded;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final palette = context.palette;
    final pendingApproval = widget.steps.any((s) => s is ToolItem && s.status == ToolStatus.approval);
    final running = widget.liveStatus != null;
    final open = _expanded || pendingApproval;
    final title = running && widget.liveStatus!.isNotEmpty ? widget.liveStatus! : activitySummary(widget.steps);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pendingApproval ? palette.warning : palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            liveRegion: running,
            child: InkWell(
              key: const Key('activity-header'),
              borderRadius: BorderRadius.circular(14),
              onTap: _toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 18,
                        child: running
                            ? CircularProgressIndicator(strokeWidth: 2, color: palette.primary)
                            : Icon(Icons.auto_awesome_rounded, size: 18, color: palette.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(title, style: TextStyle(color: palette.muted, fontWeight: FontWeight.w500)),
                      ),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more_rounded, color: palette.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final step in widget.steps)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: switch (step) {
                              ThinkingItem(:final content) => Text(
                                  content.trim(),
                                  style: TextStyle(color: palette.muted, fontStyle: FontStyle.italic),
                                ),
                              final ToolItem tool => _ToolStep(tool: tool, onDecide: widget.onDecide),
                            },
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ToolStep extends StatelessWidget {
  const _ToolStep({required this.tool, required this.onDecide});

  final ToolItem tool;
  final void Function(String callId, {required bool approved}) onDecide;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final args = argSummary(tool.args);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox.square(
                dimension: 16,
                child: tool.status == ToolStatus.running
                    ? CircularProgressIndicator(strokeWidth: 2, color: palette.primary, semanticsLabel: 'Running')
                    : Icon(Icons.build_rounded, size: 16, color: palette.muted),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: tool.name, style: TextStyle(color: palette.text, fontWeight: FontWeight.w600)),
                TextSpan(text: '($args)', style: TextStyle(color: palette.muted, fontFamily: 'monospace')),
              ])),
            ),
          ],
        ),
        if (tool.status == ToolStatus.approval)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: palette.warningBackground, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Approval needed. ', style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: tool.warning ?? ''),
                    ]),
                    style: TextStyle(color: palette.warning),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      key: Key('approve-${tool.id}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.tertiary,
                        foregroundColor: palette.onTertiary,
                      ),
                      onPressed: () => onDecide(tool.id, approved: true),
                      child: const Text('Approve'),
                    ),
                    FilledButton(
                      key: Key('deny-${tool.id}'),
                      style: FilledButton.styleFrom(backgroundColor: palette.error, foregroundColor: palette.onError),
                      onPressed: () => onDecide(tool.id, approved: false),
                      child: const Text('Deny'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (tool.result != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(color: palette.codeBackground, borderRadius: BorderRadius.circular(10)),
            child: SingleChildScrollView(
              child: SelectableText(
                prettyResult(tool.result),
                style: TextStyle(color: palette.codeText, fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }
}
