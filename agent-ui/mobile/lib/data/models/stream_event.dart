import 'dart:convert';

import '../../core/log.dart';
import '../../core/utils/json.dart';
import 'chat_item.dart';

/// One server-sent event from `POST /api/conversations/{id}/messages`.
sealed class StreamEvent {
  const StreamEvent();

  /// Parses one SSE `data` payload. Returns null (and logs) for unknown event
  /// types or malformed JSON, so a newer backend never crashes the app.
  static StreamEvent? tryParse(String data) {
    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      logWarning('Ignored a stream event that is not JSON: $data');
      return null;
    }
    return tryFromJson(asJson(decoded));
  }

  static StreamEvent? tryFromJson(Json? json) {
    if (json == null) {
      logWarning('Ignored a stream event that is not an object.');
      return null;
    }
    final type = json['type'];
    try {
      final event = switch (type) {
        'status' => StatusEvent(optionalString(json, 'message') ?? ''),
        'title' => TitleEvent(requireString(json, 'title')),
        'thinking' => ThinkingEvent(optionalString(json, 'content') ?? ''),
        'tool_call' => ToolCallEvent(
            callId: requireString(json, 'call_id'),
            name: optionalString(json, 'name') ?? 'tool',
            args: ToolItem.parseArgs(json['args']),
          ),
        'approval_required' => ApprovalRequiredEvent(
            callId: requireString(json, 'call_id'),
            name: optionalString(json, 'name') ?? 'tool',
            args: ToolItem.parseArgs(json['args']),
            warning: optionalString(json, 'warning') ?? '',
          ),
        'tool_result' => ToolResultEvent(
            callId: requireString(json, 'call_id'),
            name: optionalString(json, 'name') ?? 'tool',
            content: optionalString(json, 'content') ?? '',
          ),
        'final' => FinalEvent(optionalString(json, 'content') ?? ''),
        'error' => ErrorEvent(optionalString(json, 'message') ?? 'Agent error.'),
        _ => null,
      };
      if (event == null) logWarning('Ignored unknown stream event type "$type".');
      return event;
    } on FormatException catch (error) {
      logWarning('Ignored malformed "$type" event: ${error.message}');
      return null;
    }
  }
}

final class StatusEvent extends StreamEvent {
  const StatusEvent(this.message);
  final String message;
}

final class TitleEvent extends StreamEvent {
  const TitleEvent(this.title);
  final String title;
}

final class ThinkingEvent extends StreamEvent {
  const ThinkingEvent(this.content);
  final String content;
}

final class ToolCallEvent extends StreamEvent {
  const ToolCallEvent({required this.callId, required this.name, this.args = const {}});
  final String callId;
  final String name;
  final Json args;
}

final class ApprovalRequiredEvent extends StreamEvent {
  const ApprovalRequiredEvent({
    required this.callId,
    required this.name,
    required this.warning,
    this.args = const {},
  });
  final String callId;
  final String name;
  final Json args;
  final String warning;
}

final class ToolResultEvent extends StreamEvent {
  const ToolResultEvent({required this.callId, required this.name, required this.content});
  final String callId;
  final String name;
  final String content;
}

final class FinalEvent extends StreamEvent {
  const FinalEvent(this.content);
  final String content;
}

final class ErrorEvent extends StreamEvent {
  const ErrorEvent(this.message);
  final String message;
}
