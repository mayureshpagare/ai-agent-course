import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/agent.dart';
import '../../domain/logo_loader.dart';
import '../../domain/session_controller.dart';

/// An agent's logo, or its initial while the logo loads or when it has none.
/// Rounded square, like the web app (about 22% corner radius).
class AgentAvatar extends ConsumerWidget {
  const AgentAvatar({super.key, required this.agent, this.size = 28, this.fallback = '?'});

  final Agent? agent;
  final double size;

  /// Shown when [agent] is unknown, e.g. the first letter of a deleted agent's id.
  final String fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agent = this.agent;
    final url = agent == null ? null : ref.watch(backendProvider).logoUrl(agent);
    final bytes = url == null ? null : ref.watch(logoBytesProvider(url)).value;
    final radius = BorderRadius.circular(size * 0.22);

    final Widget child;
    if (bytes != null) {
      child = isSvg(bytes)
          ? SvgPicture.memory(bytes, width: size, height: size, fit: BoxFit.contain)
          : Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (context, _, _) => _Initial(text: agent!.initial, size: size),
            );
    } else {
      child = _Initial(text: agent?.initial ?? fallback, size: size);
    }
    // Decorative: the agent's name is always shown next to it.
    return ExcludeSemantics(
      child: ClipRRect(borderRadius: radius, child: SizedBox.square(dimension: size, child: child)),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ColoredBox(
      color: palette.userBubble,
      child: Center(
        child: Text(
          text,
          // The avatar has a fixed size, so its letter must not grow with text scaling.
          textScaler: TextScaler.noScaling,
          style: TextStyle(color: palette.primary, fontWeight: FontWeight.w600, fontSize: size * 0.45),
        ),
      ),
    );
  }
}
