import '../../core/log.dart';
import '../../core/utils/json.dart';

enum ToolStatus { running, approval, done }

/// One entry in a chat, as the web app's `ChatItem` type. Live stream events
/// and loaded history both turn into these, so both render the same way.
sealed class ChatItem {
  const ChatItem();

  /// Parses one item of `GET /api/conversations/{id}`. Returns null (and logs)
  /// for an unknown `kind` or a malformed item, so new kinds never crash the app.
  static ChatItem? tryFromJson(Json? json) {
    if (json == null) {
      logWarning('Skipped a chat item that is not an object.');
      return null;
    }
    final kind = json['kind'];
    try {
      return switch (kind) {
        'user' => UserItem(_content(json)),
        'assistant' => AssistantItem(_content(json)),
        'error' => ErrorItem(_content(json)),
        'thinking' => ThinkingItem(_content(json)),
        'tool' => ToolItem.fromJson(json),
        _ => null,
      } ?? (throw FormatException('unknown kind "$kind"'));
    } on FormatException catch (error) {
      logWarning('Skipped chat item: ${error.message}');
      return null;
    }
  }

  static String _content(Json json) => optionalString(json, 'content') ?? '';

  String get kind;

  Json toJson();
}

/// User, assistant and error items: shown as messages.
sealed class MessageItem extends ChatItem {
  const MessageItem(this.content);

  final String content;

  @override
  Json toJson() => {'kind': kind, 'content': content};
}

/// Thinking and tool items: grouped into collapsible activity blocks.
sealed class ActivityStep extends ChatItem {
  const ActivityStep();
}

final class UserItem extends MessageItem {
  const UserItem(super.content);

  @override
  String get kind => 'user';
}

final class AssistantItem extends MessageItem {
  const AssistantItem(super.content);

  @override
  String get kind => 'assistant';
}

final class ErrorItem extends MessageItem {
  const ErrorItem(super.content);

  @override
  String get kind => 'error';
}

final class ThinkingItem extends ActivityStep {
  const ThinkingItem(this.content);

  final String content;

  @override
  String get kind => 'thinking';

  @override
  Json toJson() => {'kind': kind, 'content': content};
}

final class ToolItem extends ActivityStep {
  const ToolItem({
    required this.id,
    required this.name,
    this.args = const {},
    this.result,
    this.status = ToolStatus.running,
    this.warning,
  });

  factory ToolItem.fromJson(Json json) => ToolItem(
        id: requireString(json, 'id'),
        // History cards can have a null name when the model sent a broken call.
        name: optionalString(json, 'name') ?? 'tool',
        args: parseArgs(json['args']),
        result: optionalString(json, 'result'),
        status: ToolStatus.values.asNameMap()[json['status']] ?? ToolStatus.done,
        warning: optionalString(json, 'warning'),
      );

  final String id;
  final String name;
  final Json args;

  /// The tool's output as text (often JSON), or null while it runs.
  final String? result;
  final ToolStatus status;

  /// Set while waiting for approval: why this tool needs it.
  final String? warning;

  @override
  String get kind => 'tool';

  ToolItem copyWith({ToolStatus? status, String? result, String? warning}) => ToolItem(
        id: id,
        name: name,
        args: args,
        result: result ?? this.result,
        status: status ?? this.status,
        warning: warning ?? this.warning,
      );

  @override
  Json toJson() => {
        'kind': kind,
        'id': id,
        'name': name,
        'args': args,
        'result': result,
        'status': status.name,
        if (warning != null) 'warning': warning,
      };

  /// Tool arguments are normally an object. Anything else is kept under
  /// `value` so it is still shown.
  static Json parseArgs(Object? raw) {
    if (raw == null) return const {};
    return asJson(raw) ?? {'value': raw};
  }
}
