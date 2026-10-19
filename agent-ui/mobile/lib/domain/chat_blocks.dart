import '../data/models/chat_item.dart';

/// What the chat list renders: a message, or a run of activity steps.
sealed class ChatBlock {
  const ChatBlock(this.key);

  /// Stable while items are only appended, so live updates keep widget state
  /// (such as whether a group is expanded).
  final String key;
}

final class MessageBlock extends ChatBlock {
  const MessageBlock(this.item, String key) : super(key);
  final MessageItem item;
}

final class ActivityBlock extends ChatBlock {
  const ActivityBlock(this.steps, String key) : super(key);
  final List<ActivityStep> steps;
}

/// Merges each run of consecutive thinking/tool items into one activity
/// block, like `toBlocks()` in the web app's ChatView.tsx.
List<ChatBlock> toBlocks(List<ChatItem> items) {
  final blocks = <ChatBlock>[];
  for (var index = 0; index < items.length; index++) {
    switch (items[index]) {
      case final ActivityStep step:
        if (blocks.isNotEmpty && blocks.last is ActivityBlock) {
          (blocks.last as ActivityBlock).steps.add(step);
        } else {
          blocks.add(ActivityBlock([step], 'a$index'));
        }
      case final MessageItem message:
        blocks.add(MessageBlock(message, 'm$index'));
    }
  }
  return blocks;
}
