import '../../core/utils/json.dart';
import 'chat_item.dart';

/// A saved chat from `GET /api/conversations`. Timestamps are Unix seconds
/// with a fraction, as the backend stores them.
class Conversation {
  const Conversation({
    required this.id,
    required this.agentId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Json json) => Conversation(
        id: requireString(json, 'id'),
        agentId: requireString(json, 'agent_id'),
        title: optionalString(json, 'title') ?? 'New chat',
        createdAt: asDouble(json['created_at']),
        updatedAt: asDouble(json['updated_at']),
      );

  final String id;
  final String agentId;
  final String title;
  final double createdAt;
  final double updatedAt;

  DateTime get updated => DateTime.fromMillisecondsSinceEpoch((updatedAt * 1000).round());

  Conversation copyWith({String? title}) => Conversation(
        id: id,
        agentId: agentId,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Json toJson() => {
        'id': id,
        'agent_id': agentId,
        'title': title,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

/// `GET /api/conversations/{id}`: the conversation plus its display items.
class ConversationDetail {
  const ConversationDetail({required this.conversation, required this.items});

  factory ConversationDetail.fromJson(Json json) {
    final raw = json['items'];
    return ConversationDetail(
      conversation: Conversation.fromJson(json),
      items: [
        if (raw is List)
          for (final item in raw)
            if (ChatItem.tryFromJson(asJson(item)) case final ChatItem parsed) parsed,
      ],
    );
  }

  final Conversation conversation;
  final List<ChatItem> items;
}
